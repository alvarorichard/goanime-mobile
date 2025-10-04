import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/jikan_models.dart';

class JikanService {
  static const String baseUrl = 'https://api.jikan.moe/v4';
  
  // Rate limiting: Jikan API tem limite de 3 requisições por segundo
  // Usando intervalo de 500ms para evitar erro 429
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 500);

  /// Aguarda o intervalo mínimo entre requisições
  Future<void> _waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Busca os top animes
  Future<List<JikanAnime>> getTopAnimes({int page = 1, int limit = 20}) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/top/anime?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        return jikanResponse.data;
      } else {
        throw Exception('Failed to load top animes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching top animes: $e');
      return [];
    }
  }

  /// Busca animes da temporada atual
  Future<List<JikanAnime>> getCurrentSeasonAnimes({int page = 1, int limit = 20}) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/seasons/now?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        return jikanResponse.data;
      } else {
        throw Exception('Failed to load current season animes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching current season animes: $e');
      return [];
    }
  }

  /// Busca animes por gênero
  /// Gêneros disponíveis:
  /// - Action: 1
  /// - Adventure: 2
  /// - Comedy: 4
  /// - Drama: 8
  /// - Fantasy: 10
  /// - Horror: 14
  /// - Mystery: 7
  /// - Romance: 22
  /// - Sci-Fi: 24
  /// - Slice of Life: 36
  /// - Sports: 30
  /// - Supernatural: 37
  Future<List<JikanAnime>> getAnimesByGenre(
    int genreId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/anime?genres=$genreId&page=$page&limit=$limit&order_by=score&sort=desc'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        return jikanResponse.data;
      } else {
        throw Exception('Failed to load animes by genre: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching animes by genre: $e');
      return [];
    }
  }

  /// Busca animes populares (ordenados por membros)
  Future<List<JikanAnime>> getPopularAnimes({int page = 1, int limit = 20}) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/anime?order_by=members&sort=desc&page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        return jikanResponse.data;
      } else {
        throw Exception('Failed to load popular animes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching popular animes: $e');
      return [];
    }
  }

  /// Busca animes em exibição
  Future<List<JikanAnime>> getAiringAnimes({int page = 1, int limit = 20}) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/anime?status=airing&order_by=score&sort=desc&page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        return jikanResponse.data;
      } else {
        throw Exception('Failed to load airing animes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching airing animes: $e');
      return [];
    }
  }

  /// Busca recomendações de animes
  Future<List<JikanAnime>> getRecommendedAnimes({int page = 1}) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/recommendations/anime?page=$page'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> data = jsonData['data'] ?? [];
        
        // Extrai animes das recomendações
        final List<JikanAnime> animes = [];
        for (var item in data.take(20)) {
          if (item['entry'] != null && item['entry'].isNotEmpty) {
            for (var entry in item['entry']) {
              try {
                animes.add(JikanAnime.fromJson(entry));
              } catch (e) {
                print('Error parsing recommendation entry: $e');
              }
            }
          }
        }
        
        // Remove duplicatas
        final uniqueAnimes = <int, JikanAnime>{};
        for (var anime in animes) {
          uniqueAnimes[anime.malId] = anime;
        }
        
        return uniqueAnimes.values.toList();
      } else {
        throw Exception('Failed to load recommended animes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching recommended animes: $e');
      return [];
    }
  }

  /// Busca anime por ID
  Future<JikanAnime?> getAnimeById(int malId) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/anime/$malId'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return JikanAnime.fromJson(jsonData['data']);
      } else {
        throw Exception('Failed to load anime: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching anime by id: $e');
      return null;
    }
  }

  /// Busca animes por termo de pesquisa
  Future<List<JikanAnime>> searchAnimes(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      await _waitForRateLimit();
      final response = await http.get(
        Uri.parse('$baseUrl/anime?q=${Uri.encodeComponent(query)}&page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final jikanResponse = JikanResponse<JikanAnime>.fromJson(
          jsonData,
          (json) => JikanAnime.fromJson(json),
        );
        return jikanResponse.data;
      } else {
        throw Exception('Failed to search animes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching animes: $e');
      return [];
    }
  }
}

// IDs de gêneros mais populares
class JikanGenreIds {
  static const int action = 1;
  static const int adventure = 2;
  static const int comedy = 4;
  static const int drama = 8;
  static const int fantasy = 10;
  static const int horror = 14;
  static const int mystery = 7;
  static const int romance = 22;
  static const int sciFi = 24;
  static const int sliceOfLife = 36;
  static const int sports = 30;
  static const int supernatural = 37;
}
