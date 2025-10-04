import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../main.dart';
import '../google_video_proxy.dart';
import '../services/allanime_service.dart';

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
  State<ModernVideoPlayerScreen> createState() => _ModernVideoPlayerScreenState();
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

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showWebViewOption = false;
      _bloggerVideoUrl = null;
    });

    try {
      await _cleanupControllers();

      String videoSrc;

      if (widget.anime?.source == AnimeSource.allAnime) {
        debugPrint('[VideoPlayer] Getting AllAnime episode URL');
        
        final animeId = widget.anime!.allAnimeId ?? widget.anime!.url;
        final episodeNo = widget.episode.url;
        
        final allAnimeUrl = await AllAnimeService.getEpisodeURL(animeId, episodeNo);
        
        if (allAnimeUrl == null || allAnimeUrl.isEmpty) {
          throw Exception('URL do vídeo não encontrada no AllAnime');
        }
        
        videoSrc = allAnimeUrl;
        debugPrint('[VideoPlayer] AllAnime video URL: $videoSrc');
      } else {
        debugPrint('[VideoPlayer] Getting AnimeFire episode URL');
        videoSrc = await AnimeService.extractVideoURL(widget.episode.url);
        
        if (videoSrc.isEmpty) {
          throw Exception('URL do vídeo não encontrada na página');
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
          throw Exception('URL do vídeo não pôde ser extraída da API');
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

      if (!mounted) return;

      if (_videoPlayerController!.value.hasError) {
        throw Exception(
          'Erro ao inicializar: ${_videoPlayerController!.value.errorDescription}',
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
          return _buildErrorWidget('Erro do player: $errorMessage');
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                'Erro de compatibilidade detectado. Tente usar o player web alternativo.';
            _showWebViewOption = _isIOS && _bloggerVideoUrl != null;
          } else {
            _errorMessage = 'Erro no player: $error';
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
        content: const Text('Link copiado!'),
        backgroundColor: Colors.green,
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
                colors: [Colors.red.withValues(alpha: 0.2), Colors.red.withValues(alpha: 0.1)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'Erro no Player',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (_showWebViewOption && _bloggerVideoUrl != null) ...[
            ElevatedButton.icon(
              onPressed: _openWebViewFallback,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Player Alternativo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: _initializeVideoPlayer,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar Novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cleanupControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: CustomScrollView(
        slivers: [
          // App Bar moderno
          SliverAppBar(
            expandedHeight: 80,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F1E),
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
                  'Episódio ${widget.episode.number}',
                  style: TextStyle(
                    color: Colors.orange.withValues(alpha: 0.9),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
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
            const Text(
              'Carregando stream...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preparando o melhor servidor para você',
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
        child: _buildErrorWidget(_errorMessage ?? 'Erro desconhecido'),
      ),
    );
  }

  Widget _buildLoadedContent() {
    return Column(
      children: [
        // Video Player
        Container(
          margin: const EdgeInsets.all(16),
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

        // Info Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1A2E).withValues(alpha: 0.8),
                const Color(0xFF16213E).withValues(alpha: 0.6),
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
                'Episódio ${widget.episode.number}',
                style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag('⚡ Qualidade dinâmica', Colors.purple),
                  _buildTag('🎯 Player otimizado', Colors.blue),
                  if (_isGoogleStream) _buildTag('☁️ Google Video', Colors.green),
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
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.sensors, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Servidor em uso',
                              style: TextStyle(
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
                        icon: const Icon(Icons.copy, color: Colors.orange),
                        tooltip: 'Copiar link',
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
                      label: const Text('Sincronizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
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
                      onPressed: _currentVideoUrl == null ? null : _copyStreamLink,
                      icon: const Icon(Icons.link),
                      label: const Text('Copiar link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
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
                    label: const Text('Abrir player alternativo'),
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

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
