import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/anilist_models.dart';

class AniListService {
  static const String _apiUrl = 'https://graphql.anilist.co';
  static const String _graphQLQuery = '''
    query (\$search: String) {
      Media(search: \$search, type: ANIME) {
        id
        idMal
        title {
          romaji
          english
          native
        }
        coverImage {
          extraLarge
          large
          medium
          color
        }
        bannerImage
        description
        episodes
        status
        season
        seasonYear
        averageScore
        popularity
        genres
        format
      }
    }
  ''';

  /// Fetches anime information from AniList API
  static Future<AniListResponse?> fetchAnimeFromAniList(String animeName) async {
    try {
      final cleanedName = _cleanTitle(animeName);
      debugPrint('[AniList] Querying for: $cleanedName');

      final requestBody = json.encode({
        'query': _graphQLQuery,
        'variables': {
          'search': cleanedName,
        },
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        debugPrint('[AniList] Error: HTTP ${response.statusCode}');
        return null;
      }

      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      
      if (jsonResponse.containsKey('errors')) {
        debugPrint('[AniList] GraphQL errors: ${jsonResponse['errors']}');
        return null;
      }

      final aniListResponse = AniListResponse.fromJson(jsonResponse);
      
      debugPrint('[AniList] Success: ID ${aniListResponse.data.media.id}, '
          'Title: ${aniListResponse.data.media.title.preferred}');
      
      return aniListResponse;
    } catch (e) {
      debugPrint('[AniList] Exception: $e');
      return null;
    }
  }

  /// Cleans anime title for better AniList search results
  static String _cleanTitle(String title) {
    // Remove common suffixes and patterns
    String cleaned = title;
    
    // Remove source tags like [AnimeFire] or [AllAnime]
    cleaned = cleaned.replaceAll(RegExp(r'[🔥🌐]?\[(?:animefire|allanime)\]\s*', caseSensitive: false), '');
    
    // Remove language indicators
    cleaned = cleaned.replaceAll(RegExp(r'(?:dublado|legendado|dub|sub)\s*', caseSensitive: false), '');
    
    // Remove "Todos os Episodios" and similar
    cleaned = cleaned.replaceAll(RegExp(r'todos\s+os\s+episodios', caseSensitive: false), '');
    
    // Remove season/episode indicators like "2.0 A2" or "3.5"
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+(\.\d+)?\s+A\d+\s*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+(\.\d+)?\s*$'), '');
    
    // Remove content in parentheses if it contains language info
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*\([^)]*(?:dublado|legendado|dub|sub)[^)]*\)', caseSensitive: false),
      '',
    );
    
    // Remove episode count like "(171 episodes)"
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(\d+\s+episodes?\)'), '');
    
    // Remove special titles and additions after colon
    cleaned = cleaned.replaceAll(
      RegExp(
        r':\s*(?:Jump Festa \d+|The All Magic Knights|Sword of the Wizard King|Mahou Tei no Ken).*$',
        caseSensitive: false,
      ),
      '',
    );
    
    // Normalize whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    debugPrint('[AniList] Cleaned title: "$title" -> "$cleaned"');
    return cleaned;
  }

  /// Fetches anime by MAL ID
  static Future<AniListResponse?> fetchAnimeByMalId(int malId) async {
    const query = '''
      query (\$malId: Int) {
        Media(idMal: \$malId, type: ANIME) {
          id
          idMal
          title {
            romaji
            english
            native
          }
          coverImage {
            extraLarge
            large
            medium
            color
          }
          bannerImage
          description
          episodes
          status
          season
          seasonYear
          averageScore
          popularity
          genres
          format
        }
      }
    ''';

    try {
      final requestBody = json.encode({
        'query': query,
        'variables': {'malId': malId},
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        debugPrint('[AniList] Error fetching by MAL ID: HTTP ${response.statusCode}');
        return null;
      }

      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      return AniListResponse.fromJson(jsonResponse);
    } catch (e) {
      debugPrint('[AniList] Exception fetching by MAL ID: $e');
      return null;
    }
  }

  /// Fetches anime by AniList ID
  static Future<AniListResponse?> fetchAnimeById(int anilistId) async {
    const query = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          id
          idMal
          title {
            romaji
            english
            native
          }
          coverImage {
            extraLarge
            large
            medium
            color
          }
          bannerImage
          description
          episodes
          status
          season
          seasonYear
          averageScore
          popularity
          genres
          format
        }
      }
    ''';

    try {
      final requestBody = json.encode({
        'query': query,
        'variables': {'id': anilistId},
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode != 200) {
        debugPrint('[AniList] Error fetching by ID: HTTP ${response.statusCode}');
        return null;
      }

      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      return AniListResponse.fromJson(jsonResponse);
    } catch (e) {
      debugPrint('[AniList] Exception fetching by ID: $e');
      return null;
    }
  }
}
