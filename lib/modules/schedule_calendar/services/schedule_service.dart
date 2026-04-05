import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:goanime/modules/schedule_calendar/schedule_calendar.dart';
import 'package:http/http.dart' as http;

class ScheduleService {
  static const String baseUrl = 'https://api.jikan.moe/v4';
  static const Duration _cacheExpiration = Duration(hours: 24);

  DateTime? _lastSeasonFetchTime;
  List<ScheduleEntryModel>? _cachedSeasonEntries;

  /// Busca animes da temporada atual com cache eficiente
  Future<List<ScheduleEntryModel>> getSeasonSchedule({
    bool forceRefresh = false,
  }) async {
    // Verifica cache em memória
    if (!forceRefresh &&
        _cachedSeasonEntries != null &&
        _lastSeasonFetchTime != null) {
      final cacheAge = DateTime.now().difference(_lastSeasonFetchTime!);
      if (cacheAge < _cacheExpiration) {
        debugPrint(
          '[ScheduleService] ✅ Using cached season entries (age: ${cacheAge.inMinutes}m)',
        );
        return _cachedSeasonEntries!;
      }
    }

    try {
      debugPrint('[ScheduleService] 🌐 Fetching current season anime...');

      final allData = <Map<String, dynamic>>[];
      int page = 1;
      bool hasMore = true;

      // Busca até 3 páginas com rate limiting
      while (hasMore && page <= 3) {
        if (page > 1) await Future.delayed(const Duration(milliseconds: 400));

        final response = await http
            .get(Uri.parse('$baseUrl/seasons/now?page=$page'))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          debugPrint(
            '[ScheduleService] ❌ Page $page returned ${response.statusCode}',
          );
          break;
        }

        final jsonData = json.decode(response.body);
        final data = jsonData['data'] as List<dynamic>? ?? [];
        final pagination = jsonData['pagination'];
        hasMore = pagination?['has_next_page'] ?? false;

        debugPrint('[ScheduleService] Page $page: ${data.length} anime');

        allData.addAll(data.cast<Map<String, dynamic>>());
        page++;
      }

      debugPrint('[ScheduleService] 📊 Total anime fetched: ${allData.length}');

      // Processa apenas animes com informação de horário de transmissão
      final entries = <ScheduleEntryModel>[];
      for (final item in allData) {
        final broadcast = item['broadcast'] as Map<String, dynamic>?;
        if (broadcast != null &&
            broadcast['day'] != null &&
            broadcast['time'] != null) {
          try {
            final entry = ScheduleEntryModel.fromSeasonNowJson(item);
            if (entry != null) entries.add(entry);
          } catch (e) {
            debugPrint('[ScheduleService] ⚠️ Error parsing anime: $e');
          }
        }
      }

      _cachedSeasonEntries = entries;
      _lastSeasonFetchTime = DateTime.now();

      debugPrint(
        '[ScheduleService] ✅ Loaded ${entries.length} entries with broadcast info',
      );

      return entries;
    } catch (e) {
      debugPrint('[ScheduleService] ❌ Error fetching season: $e');

      // Retorna cache expirado se disponível
      if (_cachedSeasonEntries != null) {
        debugPrint('[ScheduleService] Using expired cache due to error');
        return _cachedSeasonEntries!;
      }

      return [];
    }
  }

  /// Limpa o cache de temporada
  void clearSeasonCache() {
    _cachedSeasonEntries = null;
    _lastSeasonFetchTime = null;
    debugPrint('[ScheduleService] 🧹 Season cache cleared');
  }
}
