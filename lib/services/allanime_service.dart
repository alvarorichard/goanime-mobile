import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// AllAnime API Service - Integração com AllAnime.day
class AllAnimeService {
  static const String _allAnimeReferer = 'https://allanime.to';
  static const String _allAnimeBase = 'allanime.day';
  static const String _allAnimeAPI = 'https://api.allanime.day/api';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0';

  /// Busca animes no AllAnime
  static Future<AllAnimeSearchResponse?> searchAnime(String query) async {
    try {
      debugPrint('[AllAnime] Searching for: $query');

      // GraphQL query com thumbnail
      const searchGql = '''
        query(\$search: SearchInput, \$limit: Int, \$page: Int, \$translationType: VaildTranslationTypeEnumType, \$countryOrigin: VaildCountryOriginEnumType) {
          shows(search: \$search, limit: \$limit, page: \$page, translationType: \$translationType, countryOrigin: \$countryOrigin) {
            edges {
              _id
              name
              englishName
              availableEpisodes
              thumbnail
              __typename
            }
          }
        }
      ''';

      // Variáveis da query
      final variables = {
        'search': {'allowAdult': false, 'allowUnknown': false, 'query': query},
        'limit': 40,
        'page': 1,
        'translationType': 'sub',
        'countryOrigin': 'ALL',
      };

      final variablesJson = jsonEncode(variables);
      final url = Uri.parse(
        '$_allAnimeAPI?variables=${Uri.encodeComponent(variablesJson)}&query=${Uri.encodeComponent(searchGql)}',
      );

      final response = await http
          .get(
            url,
            headers: {'User-Agent': _userAgent, 'Referer': _allAnimeReferer},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint(
          '[AllAnime] Found ${data['data']?['shows']?['edges']?.length ?? 0} results',
        );
        return AllAnimeSearchResponse.fromJson(data);
      } else {
        debugPrint('[AllAnime] Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[AllAnime] Search error: $e');
      return null;
    }
  }

  /// Busca lista de episódios de um anime
  static Future<List<String>> getEpisodesList(
    String animeId, {
    String mode = 'sub',
  }) async {
    try {
      debugPrint('[AllAnime] Getting episodes for anime: $animeId');

      const episodesListGql = '''
        query (\$showId: String!) {
          show(_id: \$showId) {
            _id
            availableEpisodesDetail
          }
        }
      ''';

      final variables = jsonEncode({'showId': animeId});
      final url = Uri.parse(
        '$_allAnimeAPI?variables=${Uri.encodeComponent(variables)}&query=${Uri.encodeComponent(episodesListGql)}',
      );

      final response = await http
          .get(
            url,
            headers: {'User-Agent': _userAgent, 'Referer': _allAnimeReferer},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final availableEpisodesDetail =
            data['data']?['show']?['availableEpisodesDetail'];

        if (availableEpisodesDetail != null &&
            availableEpisodesDetail[mode] != null) {
          final episodes = List<String>.from(availableEpisodesDetail[mode]);
          episodes.sort((a, b) {
            final numA = double.tryParse(a) ?? 0;
            final numB = double.tryParse(b) ?? 0;
            return numA.compareTo(numB);
          });
          debugPrint('[AllAnime] Found ${episodes.length} episodes');
          return episodes;
        }
      }

      debugPrint('[AllAnime] No episodes found');
      return [];
    } catch (e) {
      debugPrint('[AllAnime] Get episodes error: $e');
      return [];
    }
  }

  /// Decodifica URL encoded do AllAnime (baseado no Curd)
  static String _decodeSourceURL(String encoded) {
    // Mapeamento de decodificação exato do Curd
    const replacements = {
      '01': '9',
      '08': '0',
      '05': '=',
      '0a': '2',
      '0b': '3',
      '0c': '4',
      '07': '?',
      '00': '8',
      '5c': 'd',
      '0f': '7',
      '5e': 'f',
      '17': '/',
      '54': 'l',
      '09': '1',
      '48': 'p',
      '4f': 'w',
      '0e': '6',
      '5b': 'c',
      '5d': 'e',
      '0d': '5',
      '53': 'k',
      '1e': '&',
      '5a': 'b',
      '59': 'a',
      '4a': 'r',
      '4c': 't',
      '4e': 'v',
      '57': 'o',
      '51': 'i',
    };

    final parts = encoded.split(':');
    final mainPart = parts[0];
    final port = parts.length > 1 ? ':${parts[1]}' : '';

    final regex = RegExp(r'..');
    final pairs = regex.allMatches(mainPart).map((m) => m.group(0)!).toList();

    for (int i = 0; i < pairs.length; i++) {
      if (replacements.containsKey(pairs[i])) {
        pairs[i] = replacements[pairs[i]]!;
      }
    }

    var result = pairs.join('') + port;
    result = result.replaceAll('/clock', '/clock.json');

    if (result.startsWith('/')) {
      result = 'https://$_allAnimeBase$result';
    }

    return result;
  }

  /// Extrai URLs de fonte da resposta da API
  static List<String> _extractSourceURLs(Map<String, dynamic> data) {
    final urls = <String>[];
    final sourceUrls = data['data']?['episode']?['sourceUrls'] as List?;

    if (sourceUrls != null) {
      for (final source in sourceUrls) {
        final sourceUrl = source['sourceUrl'] as String?;
        if (sourceUrl != null) {
          if (sourceUrl.startsWith('--')) {
            final encoded = sourceUrl.substring(2);
            final decoded = _decodeSourceURL(encoded);
            urls.add(decoded);
          } else {
            urls.add(sourceUrl);
          }
        }
      }
    }

    return urls;
  }

  /// Busca URL do episódio
  static Future<String?> getEpisodeURL(
    String animeId,
    String episodeNo, {
    String mode = 'sub',
  }) async {
    try {
      debugPrint(
        '[AllAnime] Getting episode URL: $animeId - Episode $episodeNo',
      );

      const episodeEmbedGQL = '''
        query (\$showId: String!, \$translationType: VaildTranslationTypeEnumType!, \$episodeString: String!) {
          episode(showId: \$showId, translationType: \$translationType, episodeString: \$episodeString) {
            episodeString
            sourceUrls
          }
        }
      ''';

      final variables = jsonEncode({
        'showId': animeId,
        'translationType': mode,
        'episodeString': episodeNo,
      });

      final url = Uri.parse(
        '$_allAnimeAPI?variables=${Uri.encodeComponent(variables)}&query=${Uri.encodeComponent(episodeEmbedGQL)}',
      );

      final response = await http
          .get(
            url,
            headers: {'User-Agent': _userAgent, 'Referer': _allAnimeReferer},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sourceURLs = _extractSourceURLs(data);

        if (sourceURLs.isNotEmpty) {
          // Tentar obter o link de vídeo da primeira fonte
          for (final sourceURL in sourceURLs) {
            final videoURL = await _getVideoLink(sourceURL);
            if (videoURL != null) {
              debugPrint('[AllAnime] Found video URL: $videoURL');
              return videoURL;
            }
          }
        }
      }

      debugPrint('[AllAnime] No video URL found');
      return null;
    } catch (e) {
      debugPrint('[AllAnime] Get episode URL error: $e');
      return null;
    }
  }

  /// Extrai link de vídeo da URL de fonte
  static Future<String?> _getVideoLink(String sourceURL) async {
    try {
      final response = await http
          .get(
            Uri.parse(sourceURL),
            headers: {'User-Agent': _userAgent, 'Referer': _allAnimeReferer},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Buscar por links no formato JSON
        if (data['links'] != null) {
          final links = data['links'] as List;
          for (final link in links) {
            final videoLink = link['link'] as String?;
            if (videoLink != null) {
              return videoLink.replaceAll(r'\', '');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AllAnime] Get video link error: $e');
    }
    return null;
  }
}

/// Resposta da busca do AllAnime
class AllAnimeSearchResponse {
  final List<AllAnimeShow> shows;

  AllAnimeSearchResponse({required this.shows});

  factory AllAnimeSearchResponse.fromJson(Map<String, dynamic> json) {
    final edges = json['data']?['shows']?['edges'] as List? ?? [];
    final shows = edges.map((edge) => AllAnimeShow.fromJson(edge)).toList();
    return AllAnimeSearchResponse(shows: shows);
  }
}

/// Informações de um anime do AllAnime
class AllAnimeShow {
  final String id;
  final String name;
  final String? englishName;
  final Map<String, dynamic>? availableEpisodes;
  final String? thumbnail;

  AllAnimeShow({
    required this.id,
    required this.name,
    this.englishName,
    this.availableEpisodes,
    this.thumbnail,
  });

  factory AllAnimeShow.fromJson(Map<String, dynamic> json) {
    return AllAnimeShow(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      englishName: json['englishName'],
      availableEpisodes: json['availableEpisodes'] as Map<String, dynamic>?,
      thumbnail: json['thumbnail'],
    );
  }

  String get displayName =>
      englishName?.isNotEmpty == true ? englishName! : name;

  int get episodeCount {
    if (availableEpisodes != null) {
      final sub = availableEpisodes!['sub'];
      if (sub is num) return sub.toInt();
    }
    return 0;
  }
}
