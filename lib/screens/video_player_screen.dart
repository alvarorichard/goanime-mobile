import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../main.dart';
import '../google_video_proxy.dart';
import '../services/allanime_service.dart';
import '../services/aniskip_service.dart';
import '../models/aniskip_models.dart';
import '../widgets/skip_button.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

// Function to extract only episode number from full text
String _extractEpisodeNumber(String episodeText) {
  // Try to extract number from text (e.g.: "Dandadan - Episódio 5" -> "5")
  final patterns = [
    RegExp(r'Episódio\s*(\d+)', caseSensitive: false),
    RegExp(r'Episode\s*(\d+)', caseSensitive: false),
    RegExp(r'Ep\.?\s*(\d+)', caseSensitive: false),
    RegExp(r'-\s*(\d+)$'),
    RegExp(r'\d+'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(episodeText);
    if (match != null) {
      return match.group(1) ?? match.group(0) ?? episodeText;
    }
  }

  return episodeText;
}

class ModernVideoPlayerScreen extends StatefulWidget {
  final Episode episode;
  final String animeTitle;
  final Anime? anime;

  const ModernVideoPlayerScreen({
    super.key,
    required this.episode,
    required this.animeTitle,
    this.anime,
  });

  @override
  State<ModernVideoPlayerScreen> createState() =>
      _ModernVideoPlayerScreenState();
}

class _ModernVideoPlayerScreenState extends State<ModernVideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentVideoUrl;
  Map<String, String>? _currentVideoHeaders;
  bool _showWebViewOption = false;
  String? _bloggerVideoUrl;
  GoogleVideoProxy? _googleVideoProxy;
  bool _isGoogleStream = false;

  // AniSkip related variables
  SkipTimes? _skipTimes;
  bool _showSkipButton = false;
  String _skipButtonLabel = '';
  Timer? _positionTimer;
  Timer? _skipButtonAutoHideTimer;
  int _skipTimesRetryCount = 0;
  static const int _maxSkipTimesRetries = 3;
  static const double _skipLeadSeconds = 3.0;
  static const double _skipHoldSeconds = 2.0;
  static const Duration _skipAutoHideDuration = Duration(seconds: 4);
  String? _skipButtonActiveSegment;
  bool _skipButtonDismissed = false;
  String? _activeEpisodeKey;

  String _buildEpisodeKey(ModernVideoPlayerScreen target) {
    final anime = target.anime;
    final buffer = StringBuffer()
      ..write(target.animeTitle)
      ..write('::')
      ..write(target.episode.number)
      ..write('::')
      ..write(target.episode.url);

    if (anime != null) {
      final identifiers = <String?>[
        anime.anilistId?.toString(),
        anime.malId?.toString(),
        anime.allAnimeId,
        anime.url,
      ];

      final extraIdentifier = identifiers.firstWhere(
        (value) => value != null && value.isNotEmpty,
        orElse: () => null,
      );

      if (extraIdentifier != null) {
        buffer
          ..write('::')
          ..write(extraIdentifier);
      }
    }

    return buffer.toString();
  }

  bool _isActiveEpisode(String? key) {
    if (key == null) {
      return false;
    }
    return mounted && _activeEpisodeKey == key;
  }

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  @override
  void didUpdateWidget(covariant ModernVideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousKey = _buildEpisodeKey(oldWidget);
    final nextKey = _buildEpisodeKey(widget);

    if (previousKey != nextKey) {
      debugPrint(
        '[VideoPlayer] Episode context changed. Reinitializing player…',
      );
      _initializeVideoPlayer();
    }
  }

  /// Load skip times from AniSkip API using multiple strategies
  Future<void> _loadSkipTimes({int? episodeLengthSeconds}) async {
    final requestKey = _activeEpisodeKey;
    if (!_isActiveEpisode(requestKey)) {
      debugPrint('[AniSkip] ⏭️  Skipping load - episode changed.');
      return;
    }

    final malId = widget.anime?.malId;
    final anilistId = widget.anime?.anilistId;

    // Debug: Show anime info
    debugPrint('[AniSkip] 🔍 Checking anime data...');
    debugPrint('[AniSkip] Anime: ${widget.animeTitle}');
    debugPrint('[AniSkip] Source: ${widget.anime?.sourceName}');
    debugPrint(
      '[AniSkip] Has aniListData: ${widget.anime?.aniListData != null}',
    );
    debugPrint('[AniSkip] AniList ID: $anilistId');
    debugPrint('[AniSkip] MAL ID: $malId');

    if (malId == null && anilistId == null) {
      debugPrint(
        '[AniSkip] ⚠️  No MAL ID or AniList ID available - skipping AniSkip',
      );
      debugPrint(
        '[AniSkip] 💡 Tip: This anime needs to have at least one ID in AniList database',
      );
      return;
    }

    final episodeNumberStr = _extractEpisodeNumber(widget.episode.number);
    final episodeNumber = int.tryParse(episodeNumberStr);

    if (episodeNumber == null) {
      debugPrint(
        '[AniSkip] ⚠️  Could not parse episode number: $episodeNumberStr',
      );
      return;
    }

    final resolvedEpisodeLength =
        episodeLengthSeconds ??
        _videoPlayerController?.value.duration.inSeconds;

    if (resolvedEpisodeLength == null || resolvedEpisodeLength <= 0) {
      debugPrint(
        '[AniSkip] ⚠️  Episode length unavailable (got: $resolvedEpisodeLength).',
      );
      if (_skipTimesRetryCount < _maxSkipTimesRetries) {
        _skipTimesRetryCount++;
        debugPrint(
          '[AniSkip] 🔁 Retrying to load skip times (#$_skipTimesRetryCount)…',
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (!_isActiveEpisode(requestKey)) {
            return;
          }
          if (mounted) {
            _loadSkipTimes(
              episodeLengthSeconds:
                  _videoPlayerController?.value.duration.inSeconds,
            );
          }
        });
      } else {
        debugPrint(
          '[AniSkip] ❌ Gave up retrying skip times due to missing duration.',
        );
      }
      return;
    }

    _skipTimesRetryCount = 0;

    debugPrint('[AniSkip] 🔍 Fetching skip times for Episode: $episodeNumber');
    debugPrint('[AniSkip] Episode length (s): $resolvedEpisodeLength');
    if (malId != null) {
      debugPrint('[AniSkip] Will try MAL ID: $malId');
    }
    if (anilistId != null) {
      debugPrint('[AniSkip] Will try AniList ID: $anilistId');
    }

    try {
      final skipTimes = await AniSkipService.getSkipTimesMultiStrategy(
        malId: malId,
        anilistId: anilistId,
        episodeNumber: episodeNumber,
        episodeLengthSeconds: resolvedEpisodeLength,
      );

      if (mounted && _isActiveEpisode(requestKey)) {
        _skipButtonAutoHideTimer?.cancel();
        setState(() {
          _skipTimes = skipTimes;
          _skipButtonActiveSegment = null;
          _skipButtonDismissed = false;
          _showSkipButton = false;
          _skipButtonLabel = '';
        });

        if (_videoPlayerController?.value.isInitialized == true) {
          _checkSkipButtonVisibility();
        }

        if (_isActiveEpisode(requestKey) && skipTimes.hasSkipTimes) {
          debugPrint('[AniSkip] ✅ Skip times loaded successfully!');
          if (skipTimes.op != null) {
            debugPrint(
              '[AniSkip] 📺 Opening: ${skipTimes.op!.start.toStringAsFixed(1)}s - ${skipTimes.op!.end.toStringAsFixed(1)}s (${(skipTimes.op!.end - skipTimes.op!.start).toStringAsFixed(1)}s duration)',
            );
          }
          if (skipTimes.ed != null) {
            debugPrint(
              '[AniSkip] 🎬 Ending: ${skipTimes.ed!.start.toStringAsFixed(1)}s - ${skipTimes.ed!.end.toStringAsFixed(1)}s (${(skipTimes.ed!.end - skipTimes.ed!.start).toStringAsFixed(1)}s duration)',
            );
          }
          _startPositionTimer();
        } else {
          debugPrint('[AniSkip] ℹ️  No skip times found for this episode');
        }
      }
    } catch (e) {
      debugPrint('[AniSkip] ❌ Error loading skip times: $e');
    }
  }

  /// Start timer to check video position and show skip button
  void _startPositionTimer() {
    _positionTimer?.cancel();
    final timerKey = _activeEpisodeKey;
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isActiveEpisode(timerKey)) {
        timer.cancel();
        return;
      }

      final controller = _videoPlayerController;
      if (controller == null) {
        return;
      }

      final value = controller.value;
      if (!value.isInitialized) {
        return;
      }

      if (_skipTimes == null || _skipTimes?.hasSkipTimes != true) {
        return;
      }

      _checkSkipButtonVisibility();
    });
  }

  /// Check if skip button should be visible based on current position
  void _checkSkipButtonVisibility() {
    final position = _videoPlayerController?.value.position;
    if (position == null) return;

    final currentSeconds = position.inMilliseconds / 1000.0;

    if (_skipButtonDismissed &&
        (_skipTimes?.op?.isInRange(currentSeconds) == false ||
            _skipButtonActiveSegment == 'ed') &&
        (_skipTimes?.ed?.isInRange(currentSeconds) == false ||
            _skipButtonActiveSegment == 'op')) {
      _skipButtonDismissed = false;
      _skipButtonActiveSegment = null;
    }
    String? activeSegment;
    String label = '';

    if (_skipTimes?.op != null &&
        _isWithinSkipWindow(_skipTimes?.op, currentSeconds)) {
      activeSegment = 'op';
      label = AppLocalizations.of(context).skipIntro;
      debugPrint(
        '[AniSkip] In opening range at ${currentSeconds.toStringAsFixed(1)}s',
      );
    } else if (_skipTimes?.ed != null &&
        _isWithinSkipWindow(_skipTimes?.ed, currentSeconds)) {
      activeSegment = 'ed';
      label = AppLocalizations.of(context).skipOutro;
      debugPrint(
        '[AniSkip] In ending range at ${currentSeconds.toStringAsFixed(1)}s',
      );
    }

    if (_skipButtonActiveSegment != activeSegment) {
      _skipButtonAutoHideTimer?.cancel();
      _skipButtonActiveSegment = activeSegment;
      _skipButtonDismissed = false;
    }

    if (activeSegment == null) {
      if (_showSkipButton || _skipButtonLabel.isNotEmpty) {
        setState(() {
          _showSkipButton = false;
          _skipButtonLabel = '';
        });
      }
      return;
    }

    if (_skipButtonDismissed) {
      if (_showSkipButton) {
        setState(() {
          _showSkipButton = false;
          _skipButtonLabel = '';
        });
      }
      return;
    }

    if (!_showSkipButton || label != _skipButtonLabel) {
      debugPrint(
        '[AniSkip] Button visibility changed: show=true, label=$label',
      );
      setState(() {
        _showSkipButton = true;
        _skipButtonLabel = label;
      });
      _scheduleSkipButtonAutoHide(activeSegment);
    }
  }

  /// Skip to the end of the current intro/outro
  void _skipIntroOutro() {
    final position = _videoPlayerController?.value.position;
    if (position == null) {
      debugPrint('[AniSkip] ❌ Cannot skip: video position unavailable');
      return;
    }

    if (_skipTimes == null) {
      debugPrint('[AniSkip] ❌ Cannot skip: no skip times loaded');
      return;
    }

    final currentSeconds = position.inMilliseconds / 1000.0;
    Duration? skipToPosition;
    String skipType = '';

    // If in opening, skip to end of opening
    if (_isWithinSkipWindow(_skipTimes!.op, currentSeconds)) {
      final targetSeconds = _skipTimes!.op!.end;
      skipToPosition = Duration(milliseconds: (targetSeconds * 1000).round());
      skipType = 'intro';
      debugPrint(
        '[AniSkip] ⏭️  Skipping intro: ${currentSeconds.toStringAsFixed(1)}s -> ${targetSeconds.toStringAsFixed(1)}s',
      );
    }
    // If in ending, skip to end of ending
    else if (_isWithinSkipWindow(_skipTimes!.ed, currentSeconds)) {
      final targetSeconds = _skipTimes!.ed!.end;
      skipToPosition = Duration(milliseconds: (targetSeconds * 1000).round());
      skipType = 'outro';
      debugPrint(
        '[AniSkip] ⏭️  Skipping outro: ${currentSeconds.toStringAsFixed(1)}s -> ${targetSeconds.toStringAsFixed(1)}s',
      );
    } else {
      debugPrint(
        '[AniSkip] ⚠️  Not in skip range (current: ${currentSeconds.toStringAsFixed(1)}s)',
      );
      return;
    }

    // Perform the skip
    _videoPlayerController?.seekTo(skipToPosition);

    // Hide button after skip
    _skipButtonAutoHideTimer?.cancel();
    _skipButtonDismissed = true;
    setState(() {
      _showSkipButton = false;
    });

    debugPrint('[AniSkip] ✅ Successfully skipped $skipType!');

    // Show a brief feedback to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skipType == 'intro' ? 'Intro pulada!' : 'Encerramento pulado!',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        ),
      );
    }
  }

  bool _isWithinSkipWindow(Skip? skip, double currentSeconds) {
    if (skip == null) return false;
    final startBoundary = (skip.start - _skipLeadSeconds).clamp(
      0,
      double.infinity,
    );
    final endBoundary = skip.end + _skipHoldSeconds;
    return currentSeconds >= startBoundary && currentSeconds <= endBoundary;
  }

  void _scheduleSkipButtonAutoHide(String segmentKey) {
    _skipButtonAutoHideTimer?.cancel();
    final episodeKey = _activeEpisodeKey;
    _skipButtonAutoHideTimer = Timer(_skipAutoHideDuration, () {
      if (!_isActiveEpisode(episodeKey) ||
          _skipButtonActiveSegment != segmentKey ||
          !mounted) {
        return;
      }
      setState(() {
        _showSkipButton = false;
        _skipButtonLabel = '';
      });
      _skipButtonDismissed = true;
    });
  }

  Future<void> _initializeVideoPlayer() async {
    if (!mounted) return;

    final episodeKey = _buildEpisodeKey(widget);
    _activeEpisodeKey = episodeKey;
    _positionTimer?.cancel();
    _skipButtonAutoHideTimer?.cancel();
    _skipButtonActiveSegment = null;
    _skipButtonDismissed = false;
    _skipTimesRetryCount = 0;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showWebViewOption = false;
      _bloggerVideoUrl = null;
      _skipTimes = null;
      _showSkipButton = false;
      _skipButtonLabel = '';
    });

    try {
      await _cleanupControllers();
      if (!_isActiveEpisode(episodeKey)) {
        debugPrint('[VideoPlayer] Initialization aborted (episode changed).');
        return;
      }

      String videoSrc;

      if (widget.anime?.source == AnimeSource.allAnime) {
        debugPrint('[VideoPlayer] Getting AllAnime episode URL');

        final animeId = widget.anime!.allAnimeId ?? widget.anime!.url;
        final episodeNo = widget.episode.url;

        final allAnimeUrl = await AllAnimeService.getEpisodeURL(
          animeId,
          episodeNo,
        );

        if (!_isActiveEpisode(episodeKey)) {
          debugPrint('[VideoPlayer] AllAnime fetch ignored (episode changed).');
          return;
        }

        if (allAnimeUrl == null || allAnimeUrl.isEmpty) {
          throw Exception('Video URL not found on AllAnime');
        }

        videoSrc = allAnimeUrl;
        debugPrint('[VideoPlayer] AllAnime video URL: $videoSrc');
      } else {
        debugPrint('[VideoPlayer] Getting AnimeFire episode URL');
        videoSrc = await AnimeService.extractVideoURL(widget.episode.url);

        if (!_isActiveEpisode(episodeKey)) {
          debugPrint(
            '[VideoPlayer] AnimeFire fetch ignored (episode changed).',
          );
          return;
        }

        if (videoSrc.isEmpty) {
          throw Exception('Video URL not found on page');
        }
      }

      _bloggerVideoUrl = videoSrc;

      String resolvedVideoUrl;
      Map<String, String> controllerHeaders;

      if (widget.anime?.source == AnimeSource.allAnime) {
        debugPrint('[VideoPlayer] Using AllAnime URL directly for streaming');
        resolvedVideoUrl = videoSrc;
        controllerHeaders = {
          HttpHeaders.userAgentHeader:
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36',
        };
        _isGoogleStream = false;
      } else {
        final actualVideo = await AnimeService.extractActualVideoURL(videoSrc);
        if (actualVideo.url.isEmpty) {
          throw Exception('Video URL could not be extracted from API');
        }

        if (!_isActiveEpisode(episodeKey)) {
          debugPrint(
            '[VideoPlayer] Actual video extraction ignored (episode changed).',
          );
          return;
        }

        resolvedVideoUrl = actualVideo.url;
        final playbackHeaders = <String, String>{
          HttpHeaders.userAgentHeader:
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36',
          HttpHeaders.refererHeader: 'https://animefire.plus/',
        };

        if (actualVideo.hasHeaders) {
          playbackHeaders.addAll(actualVideo.headers);
        }

        final forwardedHeaders = Map<String, String>.from(playbackHeaders);
        controllerHeaders = Map<String, String>.from(playbackHeaders);
        _isGoogleStream = actualVideo.isGoogleVideo;

        if (actualVideo.isGoogleVideo) {
          _googleVideoProxy = GoogleVideoProxy(
            targetUri: Uri.parse(actualVideo.url),
            forwardHeaders: forwardedHeaders,
          );
          final proxyUri = await _googleVideoProxy!.start();

          if (!_isActiveEpisode(episodeKey)) {
            debugPrint('[VideoPlayer] Proxy start ignored (episode changed).');
            return;
          }

          resolvedVideoUrl = proxyUri.toString();
          controllerHeaders = {};
          debugPrint('Using local proxy for Google Video: $resolvedVideoUrl');
          debugPrint('Forwarding remote headers: $forwardedHeaders');
        }
      }

      _currentVideoUrl = resolvedVideoUrl;
      _currentVideoHeaders = controllerHeaders;
      debugPrint('Using playback headers: $_currentVideoHeaders');

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(resolvedVideoUrl),
        httpHeaders: controllerHeaders,
      );

      _videoPlayerController!.addListener(_videoPlayerListener);
      await _videoPlayerController!.initialize();

      if (!_isActiveEpisode(episodeKey)) {
        debugPrint('[VideoPlayer] Controller init ignored (episode changed).');
        return;
      }

      if (!mounted) return;

      if (_videoPlayerController!.value.hasError) {
        throw Exception(
          'Initialization error: ${_videoPlayerController!.value.errorDescription}',
        );
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        aspectRatio: _calculateAspectRatio(),
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget('Player error: $errorMessage');
        },
      );

      if (mounted) {
        if (!_isActiveEpisode(episodeKey)) {
          debugPrint(
            '[VideoPlayer] Skipped final state update (episode changed).',
          );
          return;
        }
        setState(() {
          _isLoading = false;
        });
      }

      final videoDurationSeconds =
          _videoPlayerController?.value.duration.inSeconds ?? 0;
      debugPrint('[VideoPlayer] Duration (s): $videoDurationSeconds');
      await _loadSkipTimes(episodeLengthSeconds: videoDurationSeconds);
    } catch (e) {
      debugPrint('Error initializing video: $e');
      await _googleVideoProxy?.stop();
      _googleVideoProxy = null;
      _isGoogleStream = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _videoPlayerListener() {
    if (_videoPlayerController?.value.hasError == true) {
      final error = _videoPlayerController!.value.errorDescription;
      debugPrint('Video player error: $error');
      if (mounted) {
        final isBloggerError =
            error?.contains('OSStatus error -12847') == true ||
            error?.contains('media format is not supported') == true ||
            error?.contains('CoreMediaErrorDomain error -12939') == true;

        setState(() {
          if (isBloggerError) {
            _errorMessage =
                'Compatibility error detected. Try using the alternative web player.';
            _showWebViewOption = _isIOS && _bloggerVideoUrl != null;
          } else {
            _errorMessage = 'Player error: $error';
          }
          _isLoading = false;
        });
      }
    }
  }

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void _openWebViewFallback() {
    final fallbackUrl = _bloggerVideoUrl ?? _currentVideoUrl;
    if (fallbackUrl == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BloggerWebViewScreen(
          initialUrl: fallbackUrl,
          title: '${widget.animeTitle} - Ep ${widget.episode.number}',
        ),
      ),
    );
  }

  double _calculateAspectRatio() {
    if (_videoPlayerController?.value.isInitialized == true) {
      final size = _videoPlayerController!.value.size;
      if (size.width > 0 && size.height > 0) {
        return size.width / size.height;
      }
    }
    return 16 / 9;
  }

  Future<void> _cleanupControllers() async {
    _positionTimer?.cancel();
    _skipButtonAutoHideTimer?.cancel();
    _videoPlayerController?.removeListener(_videoPlayerListener);
    await _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
    _currentVideoHeaders = null;
    _currentVideoUrl = null;
    _isGoogleStream = false;

    if (_googleVideoProxy != null) {
      await _googleVideoProxy!.stop();
      _googleVideoProxy = null;
    }
  }

  void _copyStreamLink() {
    if (_currentVideoUrl == null) return;
    Clipboard.setData(ClipboardData(text: _currentVideoUrl!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).linkCopied),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withValues(alpha: 0.2),
                  Colors.red.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).playerError,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          if (_showWebViewOption && _bloggerVideoUrl != null) ...[
            ElevatedButton.icon(
              onPressed: _openWebViewFallback,
              icon: const Icon(Icons.open_in_browser),
              label: Text(AppLocalizations.of(context).alternativePlayer),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: _initializeVideoPlayer,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _cleanupControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar moderno
          SliverAppBar(
            expandedHeight: 80,
            pinned: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.animeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Episode ${_extractEpisodeNumber(widget.episode.number)}',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Conteúdo
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                ? _buildErrorState()
                : _buildLoadedContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: MediaQuery.of(context).size.height - 200,
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.getPrimaryGradient(),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryShadow,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).loadingStream,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).preparingServer,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: MediaQuery.of(context).size.height - 200,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: _buildErrorWidget(
          _errorMessage ?? AppLocalizations.of(context).error,
        ),
      ),
    );
  }

  Widget _buildLoadedContent() {
    return Column(
      children: [
        // Video Player with Skip Button
        Container(
          margin: const EdgeInsets.all(16),
          child: Stack(
            children: [
              // Video Player Container
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: _calculateAspectRatio(),
                    child: _chewieController != null
                        ? Chewie(controller: _chewieController!)
                        : Container(color: Colors.black),
                  ),
                ),
              ),
              // Skip Button Overlay (outside ClipRRect)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showSkipButton,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24, right: 16),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: SkipButton(
                          onSkip: _skipIntroOutro,
                          label: _skipButtonLabel,
                          show: _showSkipButton,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Info Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface.withValues(alpha: 0.8),
                AppColors.surfaceLight.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.animeTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Episode ${_extractEpisodeNumber(widget.episode.number)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Quality Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag(
                    AppLocalizations.of(context).dynamicQuality,
                    const Color(0xFF9C27B0),
                    Icons.high_quality_rounded,
                  ),
                  _buildTag(
                    AppLocalizations.of(context).optimizedPlayer,
                    const Color(0xFF2196F3),
                    Icons.offline_bolt_rounded,
                  ),
                  if (_isGoogleStream)
                    _buildTag(
                      AppLocalizations.of(context).googleVideo,
                      const Color(0xFF4CAF50),
                      Icons.cloud_done_rounded,
                    ),
                ],
              ),

              // Server Info
              if (_currentVideoUrl != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppColors.getPrimaryGradient(),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.sensors,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context).serverInUse,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Uri.parse(_currentVideoUrl!).host,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _copyStreamLink,
                        icon: const Icon(Icons.copy, color: AppColors.primary),
                        tooltip: AppLocalizations.of(context).copyLink,
                      ),
                    ],
                  ),
                ),
              ],

              // Buttons
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _initializeVideoPlayer,
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context).syncStream),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _currentVideoUrl == null
                          ? null
                          : _copyStreamLink,
                      icon: const Icon(Icons.link),
                      label: Text(AppLocalizations.of(context).copyLink),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_showWebViewOption && _bloggerVideoUrl != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openWebViewFallback,
                    icon: const Icon(Icons.open_in_browser),
                    label: Text(AppLocalizations.of(context).alternativePlayer),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.9), size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
