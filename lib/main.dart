import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'google_video_proxy.dart';
import 'models/anilist_models.dart';
import 'services/anilist_service.dart';
import 'services/allanime_service.dart';
import 'services/locale_service.dart';
import 'l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'screens/home_screen.dart';
import 'screens/video_player_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleService(),
      child: const MyApp(),
    ),
  );
}

// Logo Widget Helper
class LogoWidget extends StatelessWidget {
  final double size;
  final Color? color;

  const LogoWidget({super.key, this.size = 80, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.play_circle_filled,
      size: size,
      color: color ?? Colors.white70,
      shadows: const [
        Shadow(offset: Offset(0, 1), blurRadius: 3.0, color: Colors.black26),
      ],
    );
  }
}

// Theme Provider
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true; // Dark theme by default

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

// Models
class Episode {
  final String number;
  final String url;

  Episode({required this.number, required this.url});

  @override
  String toString() => number;
}

enum AnimeSource { animeFire, allAnime }

class Anime {
  final String name;
  final String url;
  final AnimeSource source;
  final String? allAnimeId; // ID do AllAnime para buscar episódios
  final String? fallbackImageUrl; // Imagem de fallback antes do AniList carregar
  MediaDetails? aniListData;
  bool isLoadingAniList = false;

  Anime({
    required this.name,
    required this.url,
    this.source = AnimeSource.animeFire,
    this.allAnimeId,
    this.aniListData,
    this.fallbackImageUrl,
  });

  @override
  String toString() => name;

  String get imageUrl =>
      aniListData?.coverImage.best ?? fallbackImageUrl ?? '';
  String get bannerUrl => aniListData?.bannerImage ?? '';
  String get description => aniListData?.description ?? '';
  int? get malId => aniListData?.idMal;
  int? get anilistId => aniListData?.id;
  List<String> get genres => aniListData?.genres ?? [];
  String? get status => aniListData?.status;
  int? get episodeCount => aniListData?.episodes;
  double? get averageScore => aniListData?.averageScore;
  String get sourceName =>
      source == AnimeSource.animeFire ? 'AnimeFire' : 'AllAnime';
}

class VideoData {
  final String src;
  final String label;

  VideoData({required this.src, required this.label});

  factory VideoData.fromJson(Map<String, dynamic> json) {
    return VideoData(src: json['src'] ?? '', label: json['label'] ?? '');
  }
}

class VideoResponse {
  final List<VideoData> data;
  final Map<String, dynamic> resposta;

  VideoResponse({required this.data, required this.resposta});

  factory VideoResponse.fromJson(Map<String, dynamic> json) {
    var dataList = json['data'] as List? ?? [];
    List<VideoData> videoDataList = dataList
        .map((item) => VideoData.fromJson(item))
        .toList();

    return VideoResponse(data: videoDataList, resposta: json['resposta'] ?? {});
  }
}

class VideoStreamResult {
  final String url;
  final Map<String, String> headers;
  final bool isGoogleVideo;

  const VideoStreamResult({
    required this.url,
    Map<String, String>? headers,
    this.isGoogleVideo = false,
  }) : headers = headers ?? const {};

  bool get hasHeaders => headers.isNotEmpty;
}

// Database Helper
class DatabaseHelper {
  static Database? _database;
  static const String dbName = 'anime.db';
  static const String animeTable = 'anime';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final path = p.join(await getDatabasesPath(), dbName);
    return await openDatabase(path, version: 1, onCreate: _createDb);
  }

  static Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $animeTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
  }

  static Future<void> addAnimeNames(List<String> animeNames) async {
    final db = await database;
    for (String name in animeNames) {
      await db.insert(animeTable, {'name': name});
    }
  }

  static Future<List<String>> getAnimeNames() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(animeTable);
    return List.generate(maps.length, (i) => maps[i]['name']);
  }
}

// API Service
class AnimeService {
  static const String baseSiteUrl = 'https://animefire.plus';
  static const String _googleVideoUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1';
  static const String _bloggerOrigin = 'https://www.blogger.com';
  static const String _bloggerReferer = 'https://www.blogger.com/';

  static Future<List<Anime>> searchAnime(String animeName) async {
    try {
      debugPrint('[AnimeService] Searching in multiple sources: $animeName');

      // Buscar simultaneamente em AnimeFire e AllAnime
      final results = await Future.wait([
        _searchAnimeFire(animeName),
        _searchAllAnime(animeName),
      ]);

      // Combinar resultados
      final List<Anime> allAnimes = [];
      allAnimes.addAll(results[0]); // AnimeFire
      allAnimes.addAll(results[1]); // AllAnime

      debugPrint(
        '[AnimeService] Total results: ${allAnimes.length} (AnimeFire: ${results[0].length}, AllAnime: ${results[1].length})',
      );

      // Enriquecer com dados do AniList em paralelo
      await Future.wait(
        allAnimes.map((anime) => enrichAnimeWithAniList(anime)),
      );

      return allAnimes;
    } catch (e) {
      throw Exception('Error searching anime: $e');
    }
  }

  /// Busca no AnimeFire
  static Future<List<Anime>> _searchAnimeFire(String animeName) async {
    final String searchUrl =
        '$baseSiteUrl/pesquisar/${_treatAnimeName(animeName)}';

    try {
      final response = await http
          .get(Uri.parse(searchUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[AnimeFire] Search failed: ${response.statusCode}');
        return [];
      }

      final document = html_parser.parse(response.body);
      final animeElements = document.querySelectorAll('.row.ml-1.mr-1 a');

      List<Anime> animes = [];
      for (var element in animeElements) {
        final name = element.text.trim();
        final url = element.attributes['href'] ?? '';
        if (name.isNotEmpty && url.isNotEmpty) {
          animes.add(
            Anime(name: name, url: url, source: AnimeSource.animeFire),
          );
        }
      }

      debugPrint('[AnimeFire] Found ${animes.length} results');
      return animes;
    } catch (e) {
      debugPrint('[AnimeFire] Search error: $e');
      return [];
    }
  }

  /// Busca no AllAnime
  static Future<List<Anime>> _searchAllAnime(String animeName) async {
    try {
      final response = await AllAnimeService.searchAnime(animeName);

      if (response == null || response.shows.isEmpty) {
        debugPrint('[AllAnime] No results found');
        return [];
      }

      List<Anime> animes = [];
      for (var show in response.shows) {
        final episodeInfo = show.episodeCount > 0
            ? ' (${show.episodeCount} eps)'
            : '';
        
        // Usar thumbnail do AllAnime como fallback se disponível
        final fallbackImage = show.thumbnail?.isNotEmpty == true
            ? show.thumbnail!
            : null;
        
        animes.add(
          Anime(
            name: '${show.displayName}$episodeInfo',
            url: show.id, // Para AllAnime, a "URL" é o ID
            source: AnimeSource.allAnime,
            allAnimeId: show.id,
            fallbackImageUrl: fallbackImage, // Fallback até AniList carregar
          ),
        );
      }

      debugPrint('[AllAnime] Found ${animes.length} results');
      return animes;
    } catch (e) {
      debugPrint('[AllAnime] Search error: $e');
      return [];
    }
  }

  /// Enriches an anime with data from AniList
  static Future<void> enrichAnimeWithAniList(Anime anime) async {
    try {
      anime.isLoadingAniList = true;

      final aniListResponse = await AniListService.fetchAnimeFromAniList(
        anime.name,
      );

      if (aniListResponse != null) {
        anime.aniListData = aniListResponse.data.media;
        debugPrint(
          '[AnimeService] Enriched ${anime.name} with AniList data - '
          'ID: ${anime.anilistId}, Cover: ${anime.imageUrl}',
        );
      } else {
        debugPrint('[AnimeService] No AniList data found for ${anime.name}');
      }
    } catch (e) {
      debugPrint(
        '[AnimeService] Failed to enrich ${anime.name} with AniList: $e',
      );
    } finally {
      anime.isLoadingAniList = false;
    }
  }

  static Future<List<Episode>> getAnimeEpisodes(Anime anime) async {
    try {
      debugPrint(
        '[AnimeService] Getting episodes for ${anime.name} from ${anime.sourceName}',
      );

      if (anime.source == AnimeSource.allAnime) {
        return await _getEpisodesFromAllAnime(anime);
      } else {
        return await _getEpisodesFromAnimeFire(anime.url);
      }
    } catch (e) {
      throw Exception('Error getting episodes: $e');
    }
  }

  /// Busca episódios do AnimeFire
  static Future<List<Episode>> _getEpisodesFromAnimeFire(
    String animeUrl,
  ) async {
    try {
      final response = await http
          .get(Uri.parse(animeUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to get episodes: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);
      final episodeElements = document.querySelectorAll(
        'a.lEp.epT.divNumEp.smallbox.px-2.mx-1.text-left.d-flex',
      );

      List<Episode> episodes = [];
      for (var element in episodeElements) {
        final number = element.text.trim();
        final url = element.attributes['href'] ?? '';
        if (number.isNotEmpty && url.isNotEmpty) {
          episodes.add(Episode(number: number, url: url));
        }
      }

      debugPrint('[AnimeFire] Found ${episodes.length} episodes');
      return episodes;
    } catch (e) {
      debugPrint('[AnimeFire] Get episodes error: $e');
      throw Exception('Error getting episodes from AnimeFire: $e');
    }
  }

  /// Busca episódios do AllAnime
  static Future<List<Episode>> _getEpisodesFromAllAnime(Anime anime) async {
    try {
      final animeId = anime.allAnimeId ?? anime.url;
      final episodesList = await AllAnimeService.getEpisodesList(animeId);

      if (episodesList.isEmpty) {
        debugPrint('[AllAnime] No episodes found');
        return [];
      }

      List<Episode> episodes = [];
      for (var episodeNo in episodesList) {
        final displayNumber = episodeNo.contains('.')
            ? 'Episódio $episodeNo'
            : 'Episódio $episodeNo';
        episodes.add(
          Episode(
            number: displayNumber,
            url: episodeNo, // Para AllAnime, guardamos o número do episódio
          ),
        );
      }

      debugPrint('[AllAnime] Found ${episodes.length} episodes');
      return episodes;
    } catch (e) {
      debugPrint('[AllAnime] Get episodes error: $e');
      throw Exception('Error getting episodes from AllAnime: $e');
    }
  }

  static Future<String> extractVideoURL(String episodeUrl) async {
    try {
      debugPrint('Extracting video URL from page: $episodeUrl');

      final response = await http.get(Uri.parse(episodeUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to get video page: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);

      // Try different selectors for video elements
      final selectors = [
        'video',
        'div[data-video-src]',
        'div[data-src]',
        'div[data-url]',
        'div[data-video]',
        'div[data-player]',
        'iframe[src*="video"]',
        'iframe[src*="player"]',
      ];

      for (String selector in selectors) {
        final elements = document.querySelectorAll(selector);
        if (elements.isNotEmpty) {
          debugPrint('Found elements with selector: $selector');

          // Try different attribute names
          final attributes = [
            'data-video-src',
            'data-src',
            'data-url',
            'data-video',
            'src',
          ];

          for (var element in elements) {
            for (String attr in attributes) {
              final videoSrc = element.attributes[attr];
              if (videoSrc != null && videoSrc.isNotEmpty) {
                debugPrint('Found video URL in attribute $attr: $videoSrc');
                return videoSrc;
              }
            }
          }
        }
      }

      // If no video element found, try to find in page content
      debugPrint('No video elements found, searching in page content');

      // Try to find blogger link
      final bloggerLink = _findBloggerLink(response.body);
      if (bloggerLink.isNotEmpty) {
        debugPrint('Found blogger link: $bloggerLink');
        return bloggerLink;
      }

      // Try to find direct video URL in content
      final videoUrlPattern = RegExp(r'https?://[^\s<>"]+?\.(?:mp4|m3u8)');
      final match = videoUrlPattern.firstMatch(response.body);
      if (match != null) {
        final directUrl = match.group(0)!;
        debugPrint('Found direct video URL: $directUrl');
        return directUrl;
      }

      throw Exception('No video source found in the page');
    } catch (e) {
      throw Exception('Error extracting video URL: $e');
    }
  }

  static Future<VideoStreamResult> extractActualVideoURL(
    String videoSrc,
  ) async {
    try {
      debugPrint('Processing video source: $videoSrc');

      // If it's a blogger.com URL, extract and process the actual video URL
      if (videoSrc.contains('blogger.com')) {
        return await _extractBloggerVideoURL(videoSrc);
      }

      // If the URL is from animefire.plus, fetch the content
      if (videoSrc.contains('animefire.plus/video/')) {
        debugPrint('Found animefire.plus video URL, fetching content...');

        final response = await http.get(Uri.parse(videoSrc));
        if (response.statusCode != 200) {
          throw Exception('Failed to get video data: ${response.statusCode}');
        }

        try {
          // Try to parse as JSON first
          final jsonData = json.decode(response.body);
          final videoResponse = VideoResponse.fromJson(jsonData);

          if (videoResponse.data.isNotEmpty) {
            debugPrint(
              'Found video data with ${videoResponse.data.length} qualities',
            );
            // Return the first available quality (can be enhanced later for quality selection)
            return VideoStreamResult(url: videoResponse.data[0].src);
          }
        } catch (jsonError) {
          debugPrint('Failed to parse as JSON, trying other methods...');
        }

        // Fallback: Try to find direct video URL in content
        final videoUrlPattern = RegExp(r'https?://[^\s<>"]+?\.(?:mp4|m3u8)');
        final match = videoUrlPattern.firstMatch(response.body);
        if (match != null) {
          final directUrl = match.group(0)!;
          debugPrint('Found direct video URL: $directUrl');
          return VideoStreamResult(url: directUrl);
        }

        // Try to find blogger link in the content
        final bloggerLink = _findBloggerLink(response.body);
        if (bloggerLink.isNotEmpty) {
          debugPrint('Found blogger link: $bloggerLink');
          return await _extractBloggerVideoURL(bloggerLink);
        }
      }

      // Default: try to fetch as JSON
      final response = await http.get(Uri.parse(videoSrc));
      if (response.statusCode != 200) {
        throw Exception('Failed to get video data: ${response.statusCode}');
      }

      final jsonData = json.decode(response.body);
      final videoResponse = VideoResponse.fromJson(jsonData);

      if (videoResponse.data.isEmpty) {
        throw Exception('No video data found');
      }

      return VideoStreamResult(url: videoResponse.data[0].src);
    } catch (e) {
      throw Exception('Error extracting actual video URL: $e');
    }
  }

  // Helper function to find Blogger video links
  static String _findBloggerLink(String content) {
    final pattern = RegExp(
      r'https://www\.blogger\.com/video\.g\?token=([A-Za-z0-9_-]+)',
    );
    final match = pattern.firstMatch(content);

    if (match != null) {
      return match.group(0) ?? '';
    }

    return '';
  }

  // Extract actual video URL from Blogger
  static Future<VideoStreamResult> _extractBloggerVideoURL(
    String bloggerUrl,
  ) async {
    try {
      debugPrint('Extracting actual video URL from Blogger: $bloggerUrl');

      final response = await http.get(
        Uri.parse(bloggerUrl),
        headers: {
          HttpHeaders.userAgentHeader: _googleVideoUserAgent,
          HttpHeaders.refererHeader: 'https://animefire.plus/',
        },
      );

      debugPrint('Blogger response status: ${response.statusCode}');
      debugPrint('Response headers: ${response.headers}');

      if (response.headers.containsKey('location')) {
        final location = response.headers['location']!;
        debugPrint('Found redirect in headers: $location');
        if (location.contains('.mp4') ||
            location.contains('googlevideo.com') ||
            location.contains('googleusercontent.com')) {
          return await _createVideoStreamResult(location, referer: bloggerUrl);
        }
      }

      final content = response.body;
      debugPrint('Response body length: ${content.length}');

      if (content.isNotEmpty) {
        final previewLength = content.length > 2000 ? 2000 : content.length;
        debugPrint('Response preview: ${content.substring(0, previewLength)}');
      }

      final videoConfigStart = content.indexOf('VIDEO_CONFIG = ');
      if (videoConfigStart != -1) {
        final jsonStart = content.indexOf('{', videoConfigStart);
        if (jsonStart != -1) {
          int braceCount = 0;
          int jsonEnd = jsonStart;

          for (int i = jsonStart; i < content.length; i++) {
            if (content[i] == '{') {
              braceCount++;
            } else if (content[i] == '}') {
              braceCount--;
              if (braceCount == 0) {
                jsonEnd = i;
                break;
              }
            }
          }

          if (jsonEnd > jsonStart) {
            final configJson = content.substring(jsonStart, jsonEnd + 1);
            debugPrint(
              'Found VIDEO_CONFIG JSON: ${configJson.length > 500 ? '${configJson.substring(0, 500)}...' : configJson}',
            );

            try {
              final config = json.decode(configJson);
              if (config is Map) {
                if (config.containsKey('streams') &&
                    config['streams'] is List) {
                  final streams = config['streams'] as List;
                  if (streams.isNotEmpty && streams[0] is Map) {
                    final firstStream = streams[0] as Map;
                    if (firstStream.containsKey('play_url')) {
                      final videoUrl = firstStream['play_url'].toString();
                      debugPrint(
                        'Found video URL in streams[0].play_url: $videoUrl',
                      );
                      return await _createVideoStreamResult(
                        videoUrl,
                        referer: bloggerUrl,
                      );
                    }
                  }
                }

                final possibleKeys = [
                  'url',
                  'stream_url',
                  'video_url',
                  'source',
                  'src',
                ];
                for (final key in possibleKeys) {
                  if (config.containsKey(key) && config[key] != null) {
                    final videoUrl = config[key].toString();
                    if (videoUrl.isNotEmpty && videoUrl.contains('http')) {
                      debugPrint(
                        'Found video URL in VIDEO_CONFIG[$key]: $videoUrl',
                      );
                      return await _createVideoStreamResult(
                        videoUrl,
                        referer: bloggerUrl,
                      );
                    }
                  }
                }
              }
            } catch (jsonError) {
              debugPrint('Failed to parse VIDEO_CONFIG JSON: $jsonError');

              final playUrlPattern = RegExp(r'"play_url"\s*:\s*"([^"]+)"');
              final playUrlMatch = playUrlPattern.firstMatch(configJson);
              if (playUrlMatch != null) {
                final videoUrl = playUrlMatch.group(1)!;
                debugPrint(
                  'Extracted play_url directly from JSON string: $videoUrl',
                );
                return await _createVideoStreamResult(
                  videoUrl,
                  referer: bloggerUrl,
                );
              }
            }
          }
        }
      }

      final patterns = [
        RegExp(
          r'https://[^"\s<>]+videoplayback[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(
          r'https://[^"\s<>]+\.googlevideo\.com[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(
          r'https://[^"\s<>]+\.googleusercontent\.com[^"\s<>]*videoplayback[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(
          r'https://[^"\s<>]+\.googleapis\.com[^"\s<>]*',
          caseSensitive: false,
        ),
        RegExp(r'stream_url.*?"([^"]*)"', caseSensitive: false),
        RegExp(r'video_url.*?"([^"]*)"', caseSensitive: false),
        RegExp(r'"url":\s*"([^"]*videoplayback[^"]*)"', caseSensitive: false),
        RegExp(r'"url":\s*"([^"]*\.mp4[^"]*)"', caseSensitive: false),
        RegExp(r'https://[^"\s<>]+\.mp4[^"\s<>]*', caseSensitive: false),
      ];

      for (int i = 0; i < patterns.length; i++) {
        final pattern = patterns[i];
        final match = pattern.firstMatch(content);
        if (match != null) {
          String videoUrl = match.group(1) ?? match.group(0)!;
          videoUrl = videoUrl
              .replaceAll(r'\u003d', '=')
              .replaceAll(r'\u0026', '&')
              .replaceAll(r'\\/', '/')
              .replaceAll(r'\\', '')
              .replaceAll(r'\/', '/');

          debugPrint('Found video URL with pattern ${i + 1}: $videoUrl');

          if (videoUrl.startsWith('http') &&
              (videoUrl.contains('.mp4') ||
                  videoUrl.contains('googlevideo') ||
                  videoUrl.contains('googleusercontent'))) {
            return await _createVideoStreamResult(
              videoUrl,
              referer: bloggerUrl,
            );
          }
        }
      }

      final scriptMatches = RegExp(
        r'<script[^>]*>(.*?)</script>',
        dotAll: true,
      ).allMatches(content);
      for (final scriptMatch in scriptMatches) {
        final scriptContent = scriptMatch.group(1) ?? '';
        final jsPatterns = [
          RegExp(r'https://[^"]+videoplayback[^"]*'),
          RegExp(r'https://[^"]+\.googlevideo\.com[^"]*'),
          RegExp(
            r'https://[^"]+\.googleusercontent\.com[^"]*videoplayback[^"]*',
          ),
        ];

        for (final jsPattern in jsPatterns) {
          final jsMatch = jsPattern.firstMatch(scriptContent);
          if (jsMatch != null) {
            final videoUrl = jsMatch.group(0)!;
            debugPrint('Found video URL in JavaScript: $videoUrl');
            return await _createVideoStreamResult(
              videoUrl,
              referer: bloggerUrl,
            );
          }
        }
      }

      final tokenMatch = RegExp(
        r'token=([A-Za-z0-9_-]+)',
      ).firstMatch(bloggerUrl);
      if (tokenMatch != null) {
        final token = tokenMatch.group(1)!;
        debugPrint('Extracted token: $token');

        final alternativeUrls = [
          'https://www.blogger.com/video-play/mp4/$token',
          'https://blogger.googleusercontent.com/video.g?token=$token',
          'https://redirector.googlevideo.com/videoplayback?token=$token',
        ];

        for (final altUrl in alternativeUrls) {
          debugPrint('Trying alternative URL: $altUrl');
          try {
            final testResponse = await http.head(Uri.parse(altUrl));
            if (testResponse.statusCode == 200 ||
                testResponse.statusCode == 302) {
              debugPrint('Alternative URL works: $altUrl');
              return await _createVideoStreamResult(
                altUrl,
                referer: bloggerUrl,
              );
            }
          } catch (e) {
            debugPrint('Alternative URL failed: $altUrl - $e');
          }
        }
      }

      debugPrint('Could not extract video URL from Blogger response');
      return VideoStreamResult(url: bloggerUrl);
    } catch (e) {
      debugPrint('Error extracting Blogger video URL: $e');
      return VideoStreamResult(url: bloggerUrl);
    }
  }

  static Future<VideoStreamResult> _createVideoStreamResult(
    String url, {
    String? referer,
  }) async {
    if (url.contains('googlevideo.com') || url.contains('videoplayback')) {
      debugPrint('Processing Google Video URL for native playback...');
      return await _processGoogleVideoURL(url, referer: referer);
    }

    return VideoStreamResult(url: url);
  }

  // Process Google Video URLs for native compatibility
  static Future<VideoStreamResult> _processGoogleVideoURL(
    String googleVideoUrl, {
    String? referer,
  }) async {
    try {
      debugPrint('Processing Google Video URL for playback: $googleVideoUrl');

      final originalUri = Uri.parse(googleVideoUrl);
      final sanitizedUri = _sanitizeGoogleVideoUri(originalUri);

      final httpClient = HttpClient();
      httpClient.userAgent = _googleVideoUserAgent;
      httpClient.connectionTimeout = const Duration(seconds: 12);

      final request = await httpClient.getUrl(sanitizedUri);
      request.followRedirects = true;
      request.headers
        ..set(HttpHeaders.acceptHeader, 'video/mp4,video/*;q=0.9,*/*;q=0.8')
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9')
        ..set(HttpHeaders.acceptEncodingHeader, 'identity')
        ..set(HttpHeaders.rangeHeader, 'bytes=0-1')
        ..set(HttpHeaders.refererHeader, referer ?? _bloggerReferer)
        ..set('Origin', _bloggerOrigin)
        ..set(HttpHeaders.connectionHeader, 'keep-alive');

      final response = await request.close();
      final effectiveUri = response.redirects.isNotEmpty
          ? response.redirects.last.location
          : sanitizedUri;
      final cookies = response.cookies;
      debugPrint('Google Video URL response status: ${response.statusCode}');
      await response.drain();
      httpClient.close(force: true);

      final cookieHeader = cookies.isEmpty
          ? ''
          : cookies
                .map((cookie) => '${cookie.name}=${cookie.value}')
                .join('; ');

      final headers = <String, String>{
        HttpHeaders.userAgentHeader: _googleVideoUserAgent,
        HttpHeaders.acceptHeader: 'video/mp4,video/*;q=0.9,*/*;q=0.8',
        HttpHeaders.acceptLanguageHeader: 'en-US,en;q=0.9',
        HttpHeaders.acceptEncodingHeader: 'identity',
        HttpHeaders.refererHeader: referer ?? _bloggerReferer,
        'Origin': _bloggerOrigin,
      };

      if (cookieHeader.isNotEmpty) {
        headers[HttpHeaders.cookieHeader] = cookieHeader;
      }

      final finalUrl = effectiveUri.toString();
      debugPrint('Cleaned Google Video URL: $finalUrl');

      return VideoStreamResult(
        url: finalUrl,
        headers: headers,
        isGoogleVideo: true,
      );
    } catch (e) {
      debugPrint('Error processing Google Video URL: $e');

      final fallbackHeaders = {
        HttpHeaders.userAgentHeader: _googleVideoUserAgent,
        HttpHeaders.refererHeader: referer ?? _bloggerReferer,
        'Origin': _bloggerOrigin,
      };

      return VideoStreamResult(
        url: googleVideoUrl,
        headers: fallbackHeaders,
        isGoogleVideo: true,
      );
    }
  }

  static Uri _sanitizeGoogleVideoUri(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);
    params.removeWhere((key, value) => value.isEmpty);
    return uri.replace(queryParameters: params);
  }

  static String _treatAnimeName(String animeName) {
    return animeName.toLowerCase().replaceAll(' ', '-');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    final localeService = Provider.of<LocaleService>(context);
    
    return AnimatedBuilder(
      animation: _themeProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'GoAnime',
          debugShowCheckedModeBanner: false,
          locale: localeService.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
          themeMode: _themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const HomeScreen(),
        );
      },
    );
  }
}

// Search Screen
class AnimeSearchScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const AnimeSearchScreen({super.key, required this.themeProvider});

  @override
  State<AnimeSearchScreen> createState() => _AnimeSearchScreenState();
}

class _AnimeSearchScreenState extends State<AnimeSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Anime> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _searchAnime() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await AnimeService.searchAnime(
        _searchController.text.trim(),
      );
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });

      // Add anime names to database
      final animeNames = results.map((anime) => anime.name).toList();
      await DatabaseHelper.addAnimeNames(animeNames);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.14),
            ),
            color: colorScheme.surface.withValues(alpha: 0.7),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por título, saga ou estúdio...',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
                child: Icon(Icons.search_rounded, color: colorScheme.primary),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: _searchAnime,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Buscar'),
                      ),
              ),
            ),
            onSubmitted: (_) => _searchAnime(),
            textInputAction: TextInputAction.search,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_searchResults.isEmpty) {
      if (_isLoading) {
        return _buildLoadingState();
      }
      return _buildEmptyState();
    }

    return _buildResultsList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Procurando pelos melhores episódios...'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.airplay_rounded, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Explore o catálogo',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pesquise por títulos populares, gêneros ou utilize sua lista de favoritos.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colorScheme.errorContainer,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_rounded,
            size: 56,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(height: 16),
          Text(
            'Não foi possível concluir sua busca',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onErrorContainer,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Tente novamente em instantes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onErrorContainer.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          FilledButton.tonalIcon(
            onPressed: _searchAnime,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
            style: FilledButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
              backgroundColor: colorScheme.onErrorContainer.withValues(
                alpha: 0.12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    final theme = Theme.of(context);
    final label =
        '${_searchResults.length} resultado${_searchResults.length == 1 ? '' : 's'} encontrados';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final anime = _searchResults[index];
            return _AnimeResultCard(
              anime: anime,
              index: index,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnimeDetailScreen(anime: anime),
                  ),
                );
              },
              onEpisodesTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EpisodeListScreen(anime: anime),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 60),
              title: const Text(
                'GoAnime',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3.0,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF04c6c5), Color(0xFF03a5a4)],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  widget.themeProvider.isDarkMode
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: () {
                  widget.themeProvider.toggleTheme();
                  HapticFeedback.lightImpact();
                },
                tooltip: widget.themeProvider.isDarkMode
                    ? 'Tema claro'
                    : 'Tema escuro',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comece uma nova maratona',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pesquise por títulos, sagas ou estúdios para encontrar seu anime.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSearchField(context),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _buildSearchContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimeResultCard extends StatelessWidget {
  final Anime anime;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onEpisodesTap;

  const _AnimeResultCard({
    required this.anime,
    required this.index,
    required this.onTap,
    this.onEpisodesTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final indexLabel = (index + 1).toString().padLeft(2, '0');
    final hasImage = anime.imageUrl.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      splashColor: colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
              colorScheme.surface,
            ],
          ),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Anime Cover Image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 80,
                  height: 110,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ),
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: anime.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            return _buildPlaceholder(
                              colorScheme,
                              indexLabel,
                              theme,
                            );
                          },
                        )
                      : _buildPlaceholder(colorScheme, indexLabel, theme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            anime.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: anime.source == AnimeSource.animeFire
                                ? Colors.orange.withValues(alpha: 0.2)
                                : Colors.purple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: anime.source == AnimeSource.animeFire
                                  ? Colors.orange.withValues(alpha: 0.5)
                                  : Colors.purple.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            anime.sourceName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: anime.source == AnimeSource.animeFire
                                  ? Colors.orange.shade800
                                  : Colors.purple.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (anime.genres.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: anime.genres.take(2).map((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              genre,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (anime.averageScore != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(anime.averageScore! / 10).toStringAsFixed(1)}/10',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                          if (anime.episodeCount != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.movie_filter_rounded,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${anime.episodeCount} eps',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else
                      Text(
                        'Toque para ver episódios',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.72,
                          ),
                          letterSpacing: 0.1,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onEpisodesTap != null)
                InkWell(
                  onTap: onEpisodesTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
    ColorScheme colorScheme,
    String indexLabel,
    ThemeData theme,
  ) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.8),
            colorScheme.secondaryContainer.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_rounded,
            size: 32,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 4),
          Text(
            '#$indexLabel',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Anime Detail Screen - Estilo Crunchyroll
class AnimeDetailScreen extends StatelessWidget {
  final Anime anime;

  const AnimeDetailScreen({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasBanner = anime.bannerUrl.isNotEmpty;
    final hasDescription = anime.description.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar com Banner
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner ou Gradiente
                  if (hasBanner)
                    CachedNetworkImage(
                      imageUrl: anime.bannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                      ),
                    ),
                  // Overlay Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo Principal
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header com Capa e Info Principal
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Capa
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: anime.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: anime.imageUrl,
                                width: 100,
                                height: 145,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 100,
                                  height: 145,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 100,
                                  height: 145,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.movie_rounded,
                                    size: 40,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : Container(
                                width: 100,
                                height: 145,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primaryContainer,
                                      colorScheme.secondaryContainer,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.movie_rounded,
                                  size: 40,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),

                      // Info Principal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),

                            // Rating
                            if (anime.averageScore != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade600,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (anime.averageScore! / 10)
                                          .toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),

                            // Informações secundárias
                            _buildInfoRow(
                              context,
                              Icons.movie_filter_rounded,
                              anime.episodeCount != null
                                  ? '${anime.episodeCount} eps'
                                  : 'Episódios variados',
                            ),
                            if (anime.status != null) ...[
                              const SizedBox(height: 5),
                              _buildInfoRow(
                                context,
                                Icons.radio_button_checked,
                                _translateStatus(anime.status!),
                              ),
                            ],
                            if (anime.aniListData?.format != null) ...[
                              const SizedBox(height: 5),
                              _buildInfoRow(
                                context,
                                Icons.category_rounded,
                                anime.aniListData!.format!.displayName,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Botão "Assistir Episódios"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EpisodeListScreen(anime: anime),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text(
                        'Assistir Episódios',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Gêneros
                if (anime.genres.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gêneros',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: anime.genres.map((genre) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.secondary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                genre,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Descrição/Sinopse
                if (hasDescription) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sinopse',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _cleanDescription(anime.description),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                              fontSize: 14,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Informações Adicionais
                if (anime.aniListData != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informações',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              if (anime.aniListData!.season != null &&
                                  anime.aniListData!.seasonYear != null)
                                _buildInfoTile(
                                  context,
                                  'Temporada',
                                  '${_translateSeason(anime.aniListData!.season!)} ${anime.aniListData!.seasonYear}',
                                ),
                              if (anime.anilistId != null)
                                _buildInfoTile(
                                  context,
                                  'AniList ID',
                                  anime.anilistId.toString(),
                                ),
                              if (anime.malId != null)
                                _buildInfoTile(
                                  context,
                                  'MyAnimeList ID',
                                  anime.malId.toString(),
                                ),
                              if (anime.aniListData!.popularity != null)
                                _buildInfoTile(
                                  context,
                                  'Popularidade',
                                  '#${anime.aniListData!.popularity}',
                                  isLast: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    String label,
    String value, {
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 10),
          Divider(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            height: 1,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  String _cleanDescription(String description) {
    // Remove HTML tags
    String cleaned = description.replaceAll(RegExp(r'<[^>]*>'), '');
    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Decode HTML entities
    cleaned = cleaned
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#039;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n');
    return cleaned;
  }

  String _translateStatus(String status) {
    switch (status.toUpperCase()) {
      case 'FINISHED':
        return 'Finalizado';
      case 'RELEASING':
        return 'Em Lançamento';
      case 'NOT_YET_RELEASED':
        return 'Não Lançado';
      case 'CANCELLED':
        return 'Cancelado';
      case 'HIATUS':
        return 'Em Hiato';
      default:
        return status;
    }
  }

  String _translateSeason(String season) {
    switch (season.toUpperCase()) {
      case 'WINTER':
        return 'Inverno';
      case 'SPRING':
        return 'Primavera';
      case 'SUMMER':
        return 'Verão';
      case 'FALL':
        return 'Outono';
      default:
        return season;
    }
  }
}

// Episode List Screen
class EpisodeListScreen extends StatefulWidget {
  final Anime anime;

  const EpisodeListScreen({super.key, required this.anime});

  @override
  State<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends State<EpisodeListScreen> {
  List<Episode> _episodes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final episodes = await AnimeService.getAnimeEpisodes(widget.anime);
      setState(() {
        _episodes = episodes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEpisodes =
        !_isLoading && _errorMessage == null && _episodes.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            title: Text(
              widget.anime.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              titlePadding: EdgeInsets.zero,
              background: _buildFlexibleHeader(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildStatusContent(context),
              ),
            ),
          ),
          if (hasEpisodes)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final episode = _episodes[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _episodes.length - 1 ? 0 : 10,
                    ),
                    child: _EpisodeCard(
                      episode: episode,
                      index: index,
                      onTap: () => _openEpisode(episode),
                    ),
                  );
                }, childCount: _episodes.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlexibleHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasBanner = widget.anime.bannerUrl.isNotEmpty;
    final hasImage = widget.anime.imageUrl.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background - Banner or Gradient
        if (hasBanner)
          CachedNetworkImage(
            imageUrl: widget.anime.bannerUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.secondary],
                ),
              ),
            ),
            errorWidget: (context, url, error) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                ),
              );
            },
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
            ),
          ),
        // Overlay gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.65),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Cover image
                      if (hasImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: widget.anime.imageUrl,
                            width: 60,
                            height: 85,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 60,
                              height: 85,
                              color: Colors.white.withValues(alpha: 0.1),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return Container(
                                width: 60,
                                height: 85,
                                color: Colors.white.withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.movie_rounded,
                                  size: 28,
                                  color: Colors.white54,
                                ),
                              );
                            },
                          ),
                        )
                      else
                        const LogoWidget(size: 32, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.anime.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (widget.anime.averageScore != null ||
                                widget.anime.episodeCount != null)
                              Row(
                                children: [
                                  if (widget.anime.averageScore != null) ...[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Colors.amber.shade400,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      (widget.anime.averageScore! / 10)
                                          .toStringAsFixed(1),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ],
                                  if (widget.anime.episodeCount != null) ...[
                                    if (widget.anime.averageScore != null)
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        width: 3,
                                        height: 3,
                                        decoration: const BoxDecoration(
                                          color: Colors.white54,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Icon(
                                      Icons.movie_filter_rounded,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${widget.anime.episodeCount} eps',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ],
                                ],
                              )
                            else
                              Text(
                                'Episódios disponíveis',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 12,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusContent(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_errorMessage != null) {
      return _buildErrorState(context);
    }

    if (_episodes.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildEpisodesHeader(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('episode-loading'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surface.withValues(alpha: 0.8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Carregando episódios...',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('episode-error'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.errorContainer,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 40,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar episódios',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onErrorContainer,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Tente novamente em alguns instantes.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _loadEpisodes,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Tentar novamente',
              style: TextStyle(fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
              backgroundColor: colorScheme.onErrorContainer.withValues(
                alpha: 0.12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('episode-empty'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tv_off_rounded, size: 48, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Nenhum episódio disponível',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Volte mais tarde para novas atualizações.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('episode-header'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surface.withValues(alpha: 0.85),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.playlist_play_rounded,
            color: colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_episodes.length} episódio${_episodes.length == 1 ? '' : 's'}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEpisode(Episode episode) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ModernVideoPlayerScreen(
          episode: episode,
          animeTitle: widget.anime.name,
          anime: widget.anime, // Passar anime completo
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  final Episode episode;
  final int index;
  final VoidCallback onTap;

  const _EpisodeCard({
    required this.episode,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayTitle = episode.number.toLowerCase().contains('epis')
        ? episode.number
        : 'Episódio ${episode.number}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.18),
              colorScheme.surface,
            ],
          ),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.09),
              blurRadius: 22,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Assista com qualidade estabilizada e sem travamentos.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Video Player Screen
class VideoPlayerScreen extends StatefulWidget {
  final Episode episode;
  final String animeTitle;
  final Anime? anime; // Objeto anime completo para saber a fonte

  const VideoPlayerScreen({
    super.key,
    required this.episode,
    required this.animeTitle,
    this.anime,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
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
      // Cleanup previous controllers
      await _cleanupControllers();

      String videoSrc;

      // Verificar se é AllAnime
      if (widget.anime?.source == AnimeSource.allAnime) {
        debugPrint('[VideoPlayer] Getting AllAnime episode URL');
        
        final animeId = widget.anime!.allAnimeId ?? widget.anime!.url;
        final episodeNo = widget.episode.url; // Para AllAnime, url é o número do episódio
        
        // Buscar URL do episódio no AllAnime
        final allAnimeUrl = await AllAnimeService.getEpisodeURL(animeId, episodeNo);
        
        if (allAnimeUrl == null || allAnimeUrl.isEmpty) {
          throw Exception('URL do vídeo não encontrada no AllAnime');
        }
        
        videoSrc = allAnimeUrl;
        debugPrint('[VideoPlayer] AllAnime video URL: $videoSrc');
      } else {
        // AnimeFire - comportamento padrão
        debugPrint('[VideoPlayer] Getting AnimeFire episode URL');
        videoSrc = await AnimeService.extractVideoURL(widget.episode.url);
        
        if (videoSrc.isEmpty) {
          throw Exception('URL do vídeo não encontrada na página');
        }
      }

      _bloggerVideoUrl = videoSrc;

      String resolvedVideoUrl;
      Map<String, String> controllerHeaders;

      // Para AllAnime, usar URL diretamente sem processamento adicional
      if (widget.anime?.source == AnimeSource.allAnime) {
        debugPrint('[VideoPlayer] Using AllAnime URL directly for streaming');
        resolvedVideoUrl = videoSrc;
        controllerHeaders = {
          HttpHeaders.userAgentHeader:
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36',
        };
        _isGoogleStream = false;
      } else {
        // AnimeFire - processar com extractActualVideoURL
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

      // Add error listener
      _videoPlayerController!.addListener(_videoPlayerListener);

      await _videoPlayerController!.initialize();

      if (!mounted) return;

      // Check if initialization was successful
      if (_videoPlayerController!.value.hasError) {
        throw Exception(
          'Erro ao inicializar: ${_videoPlayerController!.value.errorDescription}',
        );
      }

      // Create Chewie controller with safe values
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
        // Check if this is a Blogger-related error that might benefit from WebView fallback
        final isBloggerError =
            error?.contains('OSStatus error -12847') == true ||
            error?.contains('media format is not supported') == true ||
            error?.contains('CoreMediaErrorDomain error -12939') == true;

        setState(() {
          if (isBloggerError) {
            _errorMessage =
                'Erro de compatibilidade detectado. Tente usar o player web alternativo.';
            // You could add a flag here to show a WebView player button
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
    if (fallbackUrl == null) {
      return;
    }

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
    return 16 / 9; // fallback
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

  Widget _buildLoadedContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 64),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.85),
                      colorScheme.surface,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agora reproduzindo',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.8),
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: AspectRatio(
                        aspectRatio: _calculateAspectRatio(),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: Colors.black),
                            Chewie(controller: _chewieController!),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withValues(alpha: 0.1),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.animeTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Episódio ${widget.episode.number}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _buildMetadataPills(context),
                        ),
                        if (_currentVideoUrl != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.sensors_rounded,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Servidor em uso',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        Uri.parse(_currentVideoUrl!).host,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withAlpha(170),
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _copyStreamLink,
                                  tooltip: 'Copiar link da stream',
                                  icon: const Icon(Icons.copy_rounded),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _initializeVideoPlayer,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  textStyle: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Sincronizar stream'),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _currentVideoUrl == null
                                    ? null
                                    : _copyStreamLink,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                ),
                                icon: const Icon(Icons.link_rounded),
                                label: const Text('Copiar link'),
                              ),
                            ),
                          ],
                        ),
                        if (_hasWebFallback) ...[
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _openWebViewFallback,
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.secondary,
                              foregroundColor: colorScheme.onSecondary,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              textStyle: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Abrir player alternativo'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildMetadataPills(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tags = <String>{'Qualidade dinâmica', 'Player otimizado'};

    final lowerEpisode = widget.episode.number.toLowerCase();
    if (lowerEpisode.contains('dub') || lowerEpisode.contains('dublado')) {
      tags.add('Dublado');
    } else if (lowerEpisode.contains('leg')) {
      tags.add('Legendado');
    }

    if (_isGoogleStream) {
      tags.add('Google Video');
    }

    return tags
        .map(
          (tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  tag,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  bool get _hasWebFallback => _isIOS && _bloggerVideoUrl != null;

  void _copyStreamLink() {
    if (_currentVideoUrl == null) return;
    Clipboard.setData(ClipboardData(text: _currentVideoUrl!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link do stream copiado para a área de transferência'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade400,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ops! Algo deu errado',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            if (_showWebViewOption && _bloggerVideoUrl != null) ...[
              FilledButton.icon(
                onPressed: _openWebViewFallback,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Abrir player alternativo'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
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
              const SizedBox(height: 16),
              Text(
                'Se você estiver usando iPhone/iPad, o player nativo pode não suportar esse formato. O player web alternativo pode contornar essa limitação.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 24),
            ],
            ElevatedButton.icon(
              onPressed: _initializeVideoPlayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
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
          ],
        ),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${widget.animeTitle} - Ep ${widget.episode.number}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Colors.black26,
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _initializeVideoPlayer,
              tooltip: 'Recarregar',
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).shadowColor.withValues(alpha: 0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Carregando vídeo...',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Extraindo URL do vídeo...',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
              ? Center(child: _buildErrorWidget(_errorMessage!))
              : _chewieController != null &&
                    _videoPlayerController?.value.isInitialized == true
              ? _buildLoadedContent(context)
              : Center(
                  child: _buildErrorWidget('Falha ao inicializar o player'),
                ),
        ),
      ),
    );
  }
}

class BloggerWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String title;

  const BloggerWebViewScreen({
    super.key,
    required this.initialUrl,
    required this.title,
  });

  @override
  State<BloggerWebViewScreen> createState() => _BloggerWebViewScreenState();
}

class _BloggerWebViewScreenState extends State<BloggerWebViewScreen> {
  late final WebViewController _controller;
  double _progress = 0;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 '
        'Mobile/15E148 Safari/604.1',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onPageStarted: (_) {
            setState(() {
              _progress = 0;
            });
          },
          onPageFinished: (_) {
            setState(() {
              _progress = 1;
            });
          },
          onNavigationRequest: (navigation) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_progress < 1)
            LinearProgressIndicator(
              value: _progress,
              minHeight: 3,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.white10,
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
