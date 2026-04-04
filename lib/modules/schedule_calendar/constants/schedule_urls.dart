/// Constantes de URLs usadas no módulo de calendário
class ScheduleUrls {
  ScheduleUrls._();

  /// URL base do MyAnimeList
  static const String myAnimeListBaseUrl = 'https://myanimelist.net/anime';

  /// Gera a URL completa do MyAnimeList para um anime
  static String myAnimeListUrl(int malId) {
    return '$myAnimeListBaseUrl/$malId';
  }
}
