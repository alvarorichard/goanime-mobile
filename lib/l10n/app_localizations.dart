import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English (default)
    Locale('pt', 'BR'), // Portuguese
  ];

  // Common
  String get appName => locale.languageCode == 'pt' ? 'GoAnime' : 'GoAnime';
  String get search => locale.languageCode == 'pt' ? 'Buscar' : 'Search';
  String get settings =>
      locale.languageCode == 'pt' ? 'Configurações' : 'Settings';
  String get loading =>
      locale.languageCode == 'pt' ? 'Carregando...' : 'Loading...';
  String get error => locale.languageCode == 'pt' ? 'Erro' : 'Error';
  String get retry =>
      locale.languageCode == 'pt' ? 'Tentar Novamente' : 'Retry';
  String get close => locale.languageCode == 'pt' ? 'Fechar' : 'Close';

  // Home Screen
  String get home => locale.languageCode == 'pt' ? 'Início' : 'Home';
  String get trending => locale.languageCode == 'pt' ? 'Em Alta' : 'Trending';
  String get topAnime =>
      locale.languageCode == 'pt' ? 'Top Anime' : 'Top Anime';
  String get action => locale.languageCode == 'pt' ? 'Ação' : 'Action';
  String get romance => locale.languageCode == 'pt' ? 'Romance' : 'Romance';
  String get comedy => locale.languageCode == 'pt' ? 'Comédia' : 'Comedy';
  String get fantasy => locale.languageCode == 'pt' ? 'Fantasia' : 'Fantasy';
  String get currentSeason =>
      locale.languageCode == 'pt' ? 'Temporada Atual' : 'Current Season';
  String get seasonHighlights => locale.languageCode == 'pt'
      ? 'Destaques da Temporada'
      : 'Season Highlights';
  String get seeAll => locale.languageCode == 'pt' ? 'Ver Todos' : 'See All';
  String get errorLoadingAnime => locale.languageCode == 'pt'
      ? 'Erro ao carregar animes'
      : 'Error loading anime';

  // Search Screen
  String get searchAnime =>
      locale.languageCode == 'pt' ? 'Buscar Anime...' : 'Search Anime...';
  String get recentSearches =>
      locale.languageCode == 'pt' ? 'Buscas Recentes' : 'Recent Searches';
  String get trending30Days =>
      locale.languageCode == 'pt' ? 'Em Alta (30 dias)' : 'Trending (30 days)';
  String get filterByGenre =>
      locale.languageCode == 'pt' ? 'Filtrar por Gênero' : 'Filter by Genre';
  String get clearHistory =>
      locale.languageCode == 'pt' ? 'Limpar Histórico' : 'Clear History';
  String get noRecentSearches => locale.languageCode == 'pt'
      ? 'Nenhuma busca recente'
      : 'No recent searches';
  String get searchForAnime => locale.languageCode == 'pt'
      ? 'Busque por seu anime favorito'
      : 'Search for your favorite anime';
  String get noResultsFound => locale.languageCode == 'pt'
      ? 'Nenhum resultado encontrado'
      : 'No results found';
  String get tryDifferentKeywords => locale.languageCode == 'pt'
      ? 'Tente palavras-chave diferentes'
      : 'Try different keywords';

  // Genres
  String get allGenres => locale.languageCode == 'pt' ? 'Todos' : 'All';
  String get adventure =>
      locale.languageCode == 'pt' ? 'Aventura' : 'Adventure';
  String get drama => locale.languageCode == 'pt' ? 'Drama' : 'Drama';
  String get sciFi =>
      locale.languageCode == 'pt' ? 'Ficção Científica' : 'Sci-Fi';
  String get horror => locale.languageCode == 'pt' ? 'Terror' : 'Horror';
  String get mystery => locale.languageCode == 'pt' ? 'Mistério' : 'Mystery';
  String get supernatural =>
      locale.languageCode == 'pt' ? 'Sobrenatural' : 'Supernatural';
  String get sports => locale.languageCode == 'pt' ? 'Esportes' : 'Sports';
  String get sliceOfLife =>
      locale.languageCode == 'pt' ? 'Slice of Life' : 'Slice of Life';

  // Episode List Screen
  String get episodes => locale.languageCode == 'pt' ? 'Episódios' : 'Episodes';
  String episode(String number) =>
      locale.languageCode == 'pt' ? 'Episódio $number' : 'Episode $number';
  String get episodeCount => locale.languageCode == 'pt' ? 'eps' : 'eps';
  String get total => locale.languageCode == 'pt' ? 'Total' : 'Total';
  String get status => locale.languageCode == 'pt' ? 'Status' : 'Status';
  String get finished =>
      locale.languageCode == 'pt' ? 'Finalizado' : 'Finished';
  String get ongoing => locale.languageCode == 'pt' ? 'Em Exibição' : 'Ongoing';
  String get tapToWatch =>
      locale.languageCode == 'pt' ? 'Toque para assistir' : 'Tap to watch';
  String get watchNow =>
      locale.languageCode == 'pt' ? 'Assistir Agora' : 'Watch Now';
  String get searching =>
      locale.languageCode == 'pt' ? 'Buscando...' : 'Searching...';
  String get selectVersion =>
      locale.languageCode == 'pt' ? 'Selecione a Versão' : 'Select Version';
  String get loadingEpisodes => locale.languageCode == 'pt'
      ? 'Carregando episódios...'
      : 'Loading episodes...';
  String get errorLoadingEpisodes => locale.languageCode == 'pt'
      ? 'Erro ao carregar episódios'
      : 'Error loading episodes';
  String get noEpisodesFound => locale.languageCode == 'pt'
      ? 'Nenhum episódio encontrado'
      : 'No episodes found';
  String get noAnimeFound => locale.languageCode == 'pt'
      ? 'Nenhum anime encontrado'
      : 'No anime found';
  String get animeNotFoundOnAllAnime => locale.languageCode == 'pt'
      ? 'Anime não encontrado no AllAnime'
      : 'Anime not found on AllAnime';
  String get animeNotFoundOnAnimeFire => locale.languageCode == 'pt'
      ? 'Anime não encontrado no AnimeFire'
      : 'Anime not found on AnimeFire';

  // Video Player Screen
  String get nowPlaying =>
      locale.languageCode == 'pt' ? 'Agora reproduzindo' : 'Now playing';
  String get loadingStream => locale.languageCode == 'pt'
      ? 'Carregando stream...'
      : 'Loading stream...';
  String get preparingServer => locale.languageCode == 'pt'
      ? 'Preparando o melhor servidor para você'
      : 'Preparing the best server for you';
  String get playerError =>
      locale.languageCode == 'pt' ? 'Erro no Player' : 'Player Error';
  String get serverInUse =>
      locale.languageCode == 'pt' ? 'Servidor em uso' : 'Server in use';
  String get copyLink =>
      locale.languageCode == 'pt' ? 'Copiar link' : 'Copy link';
  String get syncStream =>
      locale.languageCode == 'pt' ? 'Sincronizar' : 'Synchronize';
  String get alternativePlayer => locale.languageCode == 'pt'
      ? 'Abrir player alternativo'
      : 'Open alternative player';
  String get linkCopied =>
      locale.languageCode == 'pt' ? 'Link copiado!' : 'Link copied!';
  String get dynamicQuality =>
      locale.languageCode == 'pt' ? 'Dynamic quality' : 'Dynamic quality';
  String get optimizedPlayer =>
      locale.languageCode == 'pt' ? 'Optimized player' : 'Optimized player';
  String get googleVideo =>
      locale.languageCode == 'pt' ? 'Google Video' : 'Google Video';

  // Settings Screen
  String get language => locale.languageCode == 'pt' ? 'Idioma' : 'Language';
  String get selectLanguage =>
      locale.languageCode == 'pt' ? 'Selecione o idioma' : 'Select language';
  String get english => locale.languageCode == 'pt' ? 'Inglês' : 'English';
  String get portuguese =>
      locale.languageCode == 'pt' ? 'Português' : 'Portuguese';
  String get appearance =>
      locale.languageCode == 'pt' ? 'Aparência' : 'Appearance';
  String get about => locale.languageCode == 'pt' ? 'Sobre' : 'About';
  String get version => locale.languageCode == 'pt' ? 'Versão' : 'Version';
  String get languageChanged => locale.languageCode == 'pt'
      ? 'Idioma alterado com sucesso'
      : 'Language changed successfully';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'pt'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
