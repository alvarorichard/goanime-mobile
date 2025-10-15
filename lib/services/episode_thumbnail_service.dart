import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service to fetch episode-specific thumbnails from multiple sources
class EpisodeThumbnailService {
  static const String _tmdbApiKey =
      '6c71a5457f310ab5f5464cf8bb67d365'; // Public TMDB API key
  static const String _tmdbApiBase = 'https://api.themoviedb.org/3';
  static const String _tmdbImageBase = 'https://image.tmdb.org/t/p/w500';
  static const String _kitsuApiBase = 'https://kitsu.io/api/edge';
  static const String _jikanApiBase = 'https://api.jikan.moe/v4';
  static const String _anilistGraphQL = 'https://graphql.anilist.co';

  /// Fetch episode thumbnail from multiple sources
  static Future<String?> getEpisodeThumbnail({
    required String animeTitle,
    required int episodeNumber,
    String? malId,
    String? anilistId,
  }) async {
    debugPrint(
      '[EpisodeThumbnail] Fetching thumbnail for "$animeTitle" Episode $episodeNumber',
    );

    // Try TMDB first (best coverage and quality)
    final tmdbThumbnail = await _getFromTMDB(animeTitle, episodeNumber);
    if (tmdbThumbnail != null) {
      debugPrint('[EpisodeThumbnail] Found from TMDB: $tmdbThumbnail');
      return tmdbThumbnail;
    }

    // Try Kitsu as fallback
    final kitsuThumbnail = await _getFromKitsu(animeTitle, episodeNumber);
    if (kitsuThumbnail != null) {
      debugPrint('[EpisodeThumbnail] Found from Kitsu: $kitsuThumbnail');
      return kitsuThumbnail;
    }

    debugPrint('[EpisodeThumbnail] No specific thumbnail found');
    return null;
  }

  /// Fetch from TMDB (The Movie Database) - Best source for episode images
  static Future<String?> _getFromTMDB(
    String animeTitle,
    int episodeNumber,
  ) async {
    try {
      // Clean the anime title
      final cleanTitle = animeTitle
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .replaceAll(RegExp(r'\d+\.\d+'), '')
          .replaceAll(RegExp(r'A\d+'), '')
          .trim();

      // Search for TV show
      final searchUrl = Uri.parse(
        '$_tmdbApiBase/search/tv?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(cleanTitle)}',
      );

      final searchResponse = await http
          .get(searchUrl)
          .timeout(const Duration(seconds: 5));

      if (searchResponse.statusCode != 200) return null;

      final searchData = json.decode(searchResponse.body);
      final results = searchData['results'] as List?;

      if (results == null || results.isEmpty) return null;

      final showId = results[0]['id'];

      // Get season 1 episodes (most anime are in season 1)
      final episodesUrl = Uri.parse(
        '$_tmdbApiBase/tv/$showId/season/1?api_key=$_tmdbApiKey',
      );

      final episodesResponse = await http
          .get(episodesUrl)
          .timeout(const Duration(seconds: 5));

      if (episodesResponse.statusCode != 200) return null;

      final episodesData = json.decode(episodesResponse.body);
      final episodes = episodesData['episodes'] as List?;

      if (episodes == null || episodes.isEmpty) return null;

      // Find the specific episode
      for (final episode in episodes) {
        if (episode['episode_number'] == episodeNumber) {
          final stillPath = episode['still_path'] as String?;
          if (stillPath != null) {
            return '$_tmdbImageBase$stillPath';
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('[EpisodeThumbnail] TMDB error: $e');
      return null;
    }
  }

  /// Fetch from Kitsu API (fallback source)
  static Future<String?> _getFromKitsu(
    String animeTitle,
    int episodeNumber,
  ) async {
    try {
      // Clean the anime title
      final cleanTitle = animeTitle
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .trim();

      // Search for anime
      final searchUrl = Uri.parse(
        '$_kitsuApiBase/anime?filter[text]=${Uri.encodeComponent(cleanTitle)}&page[limit]=1',
      );

      final searchResponse = await http
          .get(searchUrl)
          .timeout(const Duration(seconds: 5));

      if (searchResponse.statusCode != 200) return null;

      final searchData = json.decode(searchResponse.body);
      final animeData = searchData['data'] as List?;

      if (animeData == null || animeData.isEmpty) return null;

      final animeId = animeData[0]['id'];

      // Get episodes for this anime
      final episodesUrl = Uri.parse(
        '$_kitsuApiBase/episodes?filter[media_id]=$animeId&filter[number]=$episodeNumber&include=thumbnail',
      );

      final episodesResponse = await http
          .get(episodesUrl)
          .timeout(const Duration(seconds: 5));

      if (episodesResponse.statusCode != 200) return null;

      final episodesData = json.decode(episodesResponse.body);
      final episodes = episodesData['data'] as List?;

      if (episodes == null || episodes.isEmpty) return null;

      // Get thumbnail from episode
      final thumbnail = episodes[0]['attributes']?['thumbnail'];

      if (thumbnail != null) {
        // Kitsu returns thumbnail with different sizes
        final original = thumbnail['original']?['url'];
        final large = thumbnail['large']?['url'];
        final medium = thumbnail['medium']?['url'];

        return original ?? large ?? medium;
      }

      return null;
    } catch (e) {
      debugPrint('[EpisodeThumbnail] Kitsu error: $e');
      return null;
    }
  }

  /// Batch fetch thumbnails for multiple episodes (more efficient)
  static Future<Map<int, String>> batchGetThumbnails({
    required String animeTitle,
    required List<int> episodeNumbers,
    String? malId,
    String? anilistId,
  }) async {
    debugPrint(
      '[EpisodeThumbnail] Batch fetching ${episodeNumbers.length} thumbnails for "$animeTitle"',
    );

    final Map<int, String> thumbnails = {};

    // Try AniList first if we have an ID (best for anime)
    if (anilistId != null) {
      final anilistThumbnails = await _batchGetFromAniList(
        anilistId,
        episodeNumbers,
      );
      if (anilistThumbnails.isNotEmpty) {
        thumbnails.addAll(anilistThumbnails);
        debugPrint(
          '[EpisodeThumbnail] AniList provided ${anilistThumbnails.length} thumbnails',
        );
      }
    }

    // Try Jikan (MyAnimeList) if we have remaining episodes and a MAL ID
    if (thumbnails.length < episodeNumbers.length && malId != null) {
      final remainingEpisodes = episodeNumbers
          .where((ep) => !thumbnails.containsKey(ep))
          .toList();
      final jikanThumbnails = await _batchGetFromJikan(
        malId,
        remainingEpisodes,
      );
      if (jikanThumbnails.isNotEmpty) {
        thumbnails.addAll(jikanThumbnails);
        debugPrint(
          '[EpisodeThumbnail] Jikan provided ${jikanThumbnails.length} thumbnails',
        );
      }
    }

    // Try TMDB for remaining episodes
    if (thumbnails.length < episodeNumbers.length) {
      final remainingEpisodes = episodeNumbers
          .where((ep) => !thumbnails.containsKey(ep))
          .toList();
      final tmdbThumbnails = await _batchGetFromTMDB(
        animeTitle,
        remainingEpisodes,
      );
      if (tmdbThumbnails.isNotEmpty) {
        thumbnails.addAll(tmdbThumbnails);
        debugPrint(
          '[EpisodeThumbnail] TMDB provided ${tmdbThumbnails.length} thumbnails',
        );
      }
    }

    // Finally try Kitsu for remaining episodes
    if (thumbnails.length < episodeNumbers.length) {
      final remainingEpisodes = episodeNumbers
          .where((ep) => !thumbnails.containsKey(ep))
          .toList();
      final kitsuThumbnails = await _batchGetFromKitsu(
        animeTitle,
        remainingEpisodes,
      );
      if (kitsuThumbnails.isNotEmpty) {
        thumbnails.addAll(kitsuThumbnails);
        debugPrint(
          '[EpisodeThumbnail] Kitsu provided ${kitsuThumbnails.length} thumbnails',
        );
      }
    }

    // Last resort: Get varied images from AniList characters/screenshots for visual variety
    if (thumbnails.length < episodeNumbers.length && anilistId != null) {
      final remainingEpisodes = episodeNumbers
          .where((ep) => !thumbnails.containsKey(ep))
          .toList();
      final varietyImages = await _getVariedImagesFromAniList(
        anilistId,
        remainingEpisodes,
      );
      if (varietyImages.isNotEmpty) {
        thumbnails.addAll(varietyImages);
        debugPrint(
          '[EpisodeThumbnail] AniList variety images provided ${varietyImages.length} thumbnails',
        );
      }
    }

    debugPrint(
      '[EpisodeThumbnail] Total: ${thumbnails.length}/${episodeNumbers.length} thumbnails found',
    );
    return thumbnails;
  }

  /// Batch fetch from AniList (best for anime with episode screenshots)
  static Future<Map<int, String>> _batchGetFromAniList(
    String anilistId,
    List<int> episodeNumbers,
  ) async {
    final Map<int, String> thumbnails = {};

    try {
      debugPrint('[EpisodeThumbnail] Trying AniList for ID: $anilistId');

      const query = '''
        query(\$id: Int) {
          Media(id: \$id, type: ANIME) {
            streamingEpisodes {
              title
              thumbnail
              url
            }
          }
        }
      ''';

      final response = await http
          .post(
            Uri.parse(_anilistGraphQL),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'query': query,
              'variables': {'id': int.parse(anilistId)},
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return thumbnails;

      final data = json.decode(response.body);
      final episodes = data['data']?['Media']?['streamingEpisodes'] as List?;

      if (episodes == null || episodes.isEmpty) {
        debugPrint('[EpisodeThumbnail] AniList: No streaming episodes found');
        return thumbnails;
      }

      debugPrint(
        '[EpisodeThumbnail] AniList found ${episodes.length} streaming episodes',
      );

      // Match episodes by index (episode number)
      for (int i = 0; i < episodes.length && i < episodeNumbers.length; i++) {
        final thumbnail = episodes[i]['thumbnail'] as String?;
        if (thumbnail != null && thumbnail.isNotEmpty) {
          thumbnails[episodeNumbers[i]] = thumbnail;
        }
      }
    } catch (e) {
      debugPrint('[EpisodeThumbnail] AniList error: $e');
    }

    return thumbnails;
  }

  /// Get varied images from AniList (characters, banners) for visual variety
  static Future<Map<int, String>> _getVariedImagesFromAniList(
    String anilistId,
    List<int> episodeNumbers,
  ) async {
    final Map<int, String> thumbnails = {};

    try {
      const query = '''
        query(\$id: Int) {
          Media(id: \$id, type: ANIME) {
            bannerImage
            coverImage {
              extraLarge
              large
            }
            characters(page: 1, perPage: 25) {
              nodes {
                image {
                  large
                }
              }
            }
          }
        }
      ''';

      final response = await http
          .post(
            Uri.parse(_anilistGraphQL),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'query': query,
              'variables': {'id': int.parse(anilistId)},
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return thumbnails;

      final data = json.decode(response.body);
      final media = data['data']?['Media'];

      if (media == null) return thumbnails;

      // Collect all available images
      List<String> images = [];

      // Add banner if available
      final banner = media['bannerImage'] as String?;
      if (banner != null) images.add(banner);

      // Add cover images
      final cover = media['coverImage'];
      if (cover != null) {
        final extraLarge = cover['extraLarge'] as String?;
        final large = cover['large'] as String?;
        if (extraLarge != null) images.add(extraLarge);
        if (large != null && large != extraLarge) images.add(large);
      }

      // Add character images
      final characters = media['characters']?['nodes'] as List?;
      if (characters != null) {
        for (final char in characters) {
          final charImage = char['image']?['large'] as String?;
          if (charImage != null) images.add(charImage);
        }
      }

      if (images.isEmpty) {
        debugPrint('[EpisodeThumbnail] AniList variety: No images found');
        return thumbnails;
      }

      debugPrint(
        '[EpisodeThumbnail] AniList variety: Found ${images.length} images, distributing to ${episodeNumbers.length} episodes',
      );

      // Distribute images across episodes for variety
      for (int i = 0; i < episodeNumbers.length; i++) {
        thumbnails[episodeNumbers[i]] = images[i % images.length];
      }
    } catch (e) {
      debugPrint('[EpisodeThumbnail] AniList variety error: $e');
    }

    return thumbnails;
  }

  /// Batch fetch from Jikan (MyAnimeList API)
  /// Note: Jikan API doesn't provide episode thumbnails, only episode metadata
  /// This is kept as a placeholder for future improvements
  static Future<Map<int, String>> _batchGetFromJikan(
    String malId,
    List<int> episodeNumbers,
  ) async {
    final Map<int, String> thumbnails = {};

    try {
      debugPrint('[EpisodeThumbnail] Trying Jikan for MAL ID: $malId');

      // Unfortunately, Jikan v4 API does not provide episode thumbnails/screenshots
      // Only episode titles, air dates, and basic metadata
      // We'll try to get anime pictures instead as fallback

      final url = Uri.parse('$_jikanApiBase/anime/$malId/pictures');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return thumbnails;

      final data = json.decode(response.body);
      final pictures = data['data'] as List?;

      if (pictures == null || pictures.isEmpty) {
        debugPrint('[EpisodeThumbnail] Jikan: No pictures found');
        return thumbnails;
      }

      debugPrint(
        '[EpisodeThumbnail] Jikan found ${pictures.length} pictures (using as episode variety)',
      );

      // Use different pictures for different episodes to add variety
      for (int i = 0; i < episodeNumbers.length && i < pictures.length; i++) {
        final picture = pictures[i % pictures.length];
        final imageUrl =
            picture['jpg']?['large_image_url'] as String? ??
            picture['jpg']?['image_url'] as String?;

        if (imageUrl != null) {
          thumbnails[episodeNumbers[i]] = imageUrl;
        }
      }

      if (thumbnails.isNotEmpty) {
        debugPrint(
          '[EpisodeThumbnail] Jikan provided ${thumbnails.length} varied images',
        );
      }
    } catch (e) {
      debugPrint('[EpisodeThumbnail] Jikan error: $e');
    }

    return thumbnails;
  }

  /// Batch fetch from TMDB
  static Future<Map<int, String>> _batchGetFromTMDB(
    String animeTitle,
    List<int> episodeNumbers,
  ) async {
    final Map<int, String> thumbnails = {};

    try {
      // Clean the anime title
      final cleanTitle = animeTitle
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .replaceAll(RegExp(r'\d+\.\d+'), '')
          .replaceAll(RegExp(r'A\d+'), '')
          .replaceAll(RegExp(r'Season \d+'), '')
          .trim();

      debugPrint('[EpisodeThumbnail] TMDB searching for: "$cleanTitle"');

      // Search for TV show with keyword "anime" to improve results
      final searchUrl = Uri.parse(
        '$_tmdbApiBase/search/tv?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(cleanTitle)}&with_keywords=210024|287617', // anime keywords
      );

      final searchResponse = await http
          .get(searchUrl)
          .timeout(const Duration(seconds: 5));

      if (searchResponse.statusCode != 200) return thumbnails;

      final searchData = json.decode(searchResponse.body);
      var results = searchData['results'] as List?;

      // If no results with anime keywords, try without
      if (results == null || results.isEmpty) {
        debugPrint(
          '[EpisodeThumbnail] TMDB: Trying search without anime filter...',
        );
        final fallbackUrl = Uri.parse(
          '$_tmdbApiBase/search/tv?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(cleanTitle)}',
        );

        final fallbackResponse = await http
            .get(fallbackUrl)
            .timeout(const Duration(seconds: 5));

        if (fallbackResponse.statusCode == 200) {
          final fallbackData = json.decode(fallbackResponse.body);
          results = fallbackData['results'] as List?;
        }
      }

      if (results == null || results.isEmpty) {
        debugPrint('[EpisodeThumbnail] TMDB: No show found');
        return thumbnails;
      }

      final showId = results[0]['id'];
      final showName = results[0]['name'];
      debugPrint('[EpisodeThumbnail] TMDB found show: $showName (ID: $showId)');

      // Try season 1 (most anime)
      for (int season = 1; season <= 3; season++) {
        final episodesUrl = Uri.parse(
          '$_tmdbApiBase/tv/$showId/season/$season?api_key=$_tmdbApiKey',
        );

        final episodesResponse = await http
            .get(episodesUrl)
            .timeout(const Duration(seconds: 5));

        if (episodesResponse.statusCode != 200) continue;

        final episodesData = json.decode(episodesResponse.body);
        final episodes = episodesData['episodes'] as List?;

        if (episodes == null) continue;

        debugPrint(
          '[EpisodeThumbnail] TMDB Season $season has ${episodes.length} episodes',
        );

        // Map episodes to thumbnails
        for (final episode in episodes) {
          final epNum = episode['episode_number'] as int?;
          final stillPath = episode['still_path'] as String?;

          if (epNum != null &&
              stillPath != null &&
              episodeNumbers.contains(epNum)) {
            thumbnails[epNum] = '$_tmdbImageBase$stillPath';

            if (thumbnails.length <= 3) {
              debugPrint('[EpisodeThumbnail] TMDB Episode $epNum: $stillPath');
            }
          }
        }

        // If we found thumbnails, stop searching other seasons
        if (thumbnails.isNotEmpty) break;
      }
    } catch (e) {
      debugPrint('[EpisodeThumbnail] TMDB batch error: $e');
    }

    return thumbnails;
  }

  /// Batch fetch from Kitsu (fallback)
  static Future<Map<int, String>> _batchGetFromKitsu(
    String animeTitle,
    List<int> episodeNumbers,
  ) async {
    final Map<int, String> thumbnails = {};

    try {
      final cleanTitle = animeTitle
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .trim();

      final searchUrl = Uri.parse(
        '$_kitsuApiBase/anime?filter[text]=${Uri.encodeComponent(cleanTitle)}&page[limit]=1',
      );

      final searchResponse = await http
          .get(searchUrl)
          .timeout(const Duration(seconds: 5));

      if (searchResponse.statusCode != 200) return thumbnails;

      final searchData = json.decode(searchResponse.body);
      final animeData = searchData['data'] as List?;

      if (animeData == null || animeData.isEmpty) return thumbnails;

      final animeId = animeData[0]['id'];

      final episodesUrl = Uri.parse(
        '$_kitsuApiBase/episodes?filter[media_id]=$animeId&page[limit]=50',
      );

      final episodesResponse = await http
          .get(episodesUrl)
          .timeout(const Duration(seconds: 10));

      if (episodesResponse.statusCode != 200) return thumbnails;

      final episodesData = json.decode(episodesResponse.body);
      final episodes = episodesData['data'] as List?;

      if (episodes == null) return thumbnails;

      for (final episode in episodes) {
        final number = episode['attributes']?['number'] as int?;
        final thumbnail = episode['attributes']?['thumbnail'];

        if (number != null &&
            thumbnail != null &&
            episodeNumbers.contains(number)) {
          final original = thumbnail['original']?['url'];
          final large = thumbnail['large']?['url'];
          final medium = thumbnail['medium']?['url'];

          final thumbnailUrl = original ?? large ?? medium;
          if (thumbnailUrl != null) {
            thumbnails[number] = thumbnailUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('[EpisodeThumbnail] Kitsu batch error: $e');
    }

    return thumbnails;
  }
}
