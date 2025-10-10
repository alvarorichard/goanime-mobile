import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/aniskip_models.dart';

class AniSkipService {
  static const String baseUrl = 'https://api.aniskip.com/v2';

  /// Fetches skip times data trying multiple strategies
  /// 1. Try with MAL ID if available
  /// 2. Try with AniList ID if MAL ID fails
  static Future<SkipTimes> getSkipTimesMultiStrategy({
    int? malId,
    int? anilistId,
    required int episodeNumber,
    int? episodeLengthSeconds,
  }) async {
    if (episodeLengthSeconds == null || episodeLengthSeconds <= 0) {
      debugPrint(
        '[AniSkip] ⚠️  Invalid episode length provided to service: '
        '$episodeLengthSeconds. Skipping API call.',
      );
      return SkipTimes.empty();
    }

    // Strategy 1: Try MAL ID first
    if (malId != null) {
      debugPrint('[AniSkip] 🎯 Strategy 1: Trying with MAL ID: $malId');
      final result = await _fetchSkipTimes(
        animeId: malId,
        episodeNumber: episodeNumber,
        idType: 'MAL',
        episodeLengthSeconds: episodeLengthSeconds,
      );
      if (result.hasSkipTimes) {
        return result;
      }
    }

    // Strategy 2: Try AniList ID
    if (anilistId != null) {
      debugPrint('[AniSkip] 🎯 Strategy 2: Trying with AniList ID: $anilistId');
      final result = await _fetchSkipTimes(
        animeId: anilistId,
        episodeNumber: episodeNumber,
        idType: 'AniList',
        episodeLengthSeconds: episodeLengthSeconds,
      );
      if (result.hasSkipTimes) {
        return result;
      }
    }

    debugPrint('[AniSkip] ❌ No skip times found with any strategy');
    return SkipTimes.empty();
  }

  /// Fetches skip times data for a given anime ID and episode number
  static Future<SkipTimes> _fetchSkipTimes({
    required int animeId,
    required int episodeNumber,
    required String idType,
    required int episodeLengthSeconds,
  }) async {
    try {
      // Build URL - AniSkip API expects types as array parameters
      // Format: ?types[]=op&types[]=ed
      final uri = Uri.https(
        'api.aniskip.com',
        '/v2/skip-times/$animeId/$episodeNumber',
        {
          'types[]': ['op', 'ed'],
          'episodeLength': episodeLengthSeconds.toString(),
        },
      );

      debugPrint('[AniSkip API] 🌐 Request ($idType): $uri');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[AniSkip API] ⏱️  Request timeout after 10s');
              throw Exception('Request timeout');
            },
          );

      debugPrint('[AniSkip API] 📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('[AniSkip API] 📄 Response body: ${response.body}');
        final jsonData = json.decode(response.body);
        final skipResponse = SkipTimesResponse.fromJson(jsonData);

        if (skipResponse.found) {
          debugPrint(
            '[AniSkip API] ✅ Found ${skipResponse.results.length} skip time(s) using $idType ID',
          );
          return skipResponse.toSkipTimes();
        } else {
          debugPrint(
            '[AniSkip API] ℹ️  API returned found=false for $idType ID',
          );
        }
      } else if (response.statusCode == 404) {
        debugPrint(
          '[AniSkip API] 404 - No skip times found for $idType ID: $animeId',
        );
        return SkipTimes.empty();
      } else {
        debugPrint(
          '[AniSkip API] ❌ Request failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[AniSkip API] ❌ Exception with $idType ID: $e');
    }

    return SkipTimes.empty();
  }

  /// Legacy method for backward compatibility
  /// Use [getSkipTimesMultiStrategy] instead for better fallback support
  @Deprecated('Use getSkipTimesMultiStrategy for better fallback support')
  static Future<SkipTimes> getSkipTimes(
    int malId,
    int episodeNumber, {
    int? episodeLengthSeconds,
  }) async {
    return getSkipTimesMultiStrategy(
      malId: malId,
      episodeNumber: episodeNumber,
      episodeLengthSeconds: episodeLengthSeconds,
    );
  }

  /// Rounds a time value to the specified precision
  static double roundTime(double timeValue, int precision) {
    final multiplier = 1.0 * (10 ^ precision);
    return (timeValue * multiplier).round() / multiplier;
  }
}
