import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../services/allanime_service.dart';
import '../widgets/watchlist_button.dart';
import 'episode_list_screen.dart';

class SourceSelectionScreen extends StatefulWidget {
  final String animeTitle;
  final String imageUrl;
  final String myAnimeListUrl;

  const SourceSelectionScreen({
    super.key,
    required this.animeTitle,
    required this.imageUrl,
    required this.myAnimeListUrl,
  });

  @override
  State<SourceSelectionScreen> createState() => _SourceSelectionScreenState();
}

class _SourceSelectionScreenState extends State<SourceSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  bool _isSearchingAllAnime = false;
  bool _isSearchingAnimeFire = false;
  List<AllAnimeShow> _allAnimeResults = [];
  String? _allAnimeErrorMessage;
  List<Anime> _animeFireResults = [];
  String? _animeFireErrorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
    _searchAllAnime();
    _searchAnimeFire();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _searchAllAnime() async {
    setState(() {
      _isSearchingAllAnime = true;
      _allAnimeErrorMessage = null;
    });

    try {
      final searchResponse = await AllAnimeService.searchAnime(
        widget.animeTitle,
      );

      if (searchResponse != null && searchResponse.shows.isNotEmpty) {
        setState(() {
          _allAnimeResults = searchResponse.shows;
          _isSearchingAllAnime = false;
        });
      } else {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        setState(() {
          _isSearchingAllAnime = false;
          _allAnimeErrorMessage = l10n.animeNotFoundOnAllAnime;
        });
      }
    } catch (e) {
      debugPrint('Error searching AllAnime: $e');
      setState(() {
        _isSearchingAllAnime = false;
        _allAnimeErrorMessage = 'Error searching on AllAnime';
      });
    }
  }

  Future<void> _searchAnimeFire() async {
    setState(() {
      _isSearchingAnimeFire = true;
      _animeFireErrorMessage = null;
    });

    try {
      final results = await AnimeService.searchAnime(widget.animeTitle);
      final animeFireResults = results
          .where((a) => a.source == AnimeSource.animeFire)
          .toList();

      if (animeFireResults.isNotEmpty) {
        setState(() {
          _animeFireResults = animeFireResults;
          _isSearchingAnimeFire = false;
        });
      } else {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        setState(() {
          _isSearchingAnimeFire = false;
          _animeFireErrorMessage = l10n.animeNotFoundOnAnimeFire;
        });
      }
    } catch (e) {
      debugPrint('Error searching AnimeFire: $e');
      setState(() {
        _isSearchingAnimeFire = false;
        _animeFireErrorMessage = 'Error searching on AnimeFire';
      });
    }
  }

  Future<void> _selectSource(AnimeSource source) async {
    if (source == AnimeSource.allAnime && _allAnimeResults.isNotEmpty) {
      // Se houver múltiplos resultados, mostra dialog para escolher
      if (_allAnimeResults.length > 1) {
        final selectedShow = await _showVersionSelectionDialog(
          source: source,
          allAnimeShows: _allAnimeResults,
        );
        if (selectedShow == null) return; // User cancelled

        final anime = Anime(
          name: selectedShow.displayName,
          url: widget.myAnimeListUrl,
          fallbackImageUrl: widget.imageUrl,
          source: AnimeSource.allAnime,
          allAnimeId: selectedShow.id,
        );

        // Enrich with AniList data before navigating
        await AnimeService.enrichAnimeWithAniList(anime);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ModernEpisodeListScreen(anime: anime),
          ),
        );
      } else {
        // Apenas um resultado, usa diretamente
        final show = _allAnimeResults.first;
        final anime = Anime(
          name: show.displayName,
          url: widget.myAnimeListUrl,
          fallbackImageUrl: widget.imageUrl,
          source: AnimeSource.allAnime,
          allAnimeId: show.id,
        );

        // Enrich with AniList data before navigating
        await AnimeService.enrichAnimeWithAniList(anime);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ModernEpisodeListScreen(anime: anime),
          ),
        );
      }
    } else if (source == AnimeSource.animeFire &&
        _animeFireResults.isNotEmpty) {
      // Se houver múltiplos resultados, mostra dialog para escolher
      if (_animeFireResults.length > 1) {
        final selectedAnime = await _showVersionSelectionDialog(
          source: source,
          animeFireAnimes: _animeFireResults,
        );
        if (selectedAnime == null) return; // User cancelled

        // Enrich with AniList data before navigating
        await AnimeService.enrichAnimeWithAniList(selectedAnime);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ModernEpisodeListScreen(anime: selectedAnime),
          ),
        );
      } else {
        // Apenas um resultado, usa diretamente
        final anime = _animeFireResults.first;

        // Enrich with AniList data before navigating
        await AnimeService.enrichAnimeWithAniList(anime);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ModernEpisodeListScreen(anime: anime),
          ),
        );
      }
    } else {
      // Fallback (não deveria acontecer)
      final anime = Anime(
        name: widget.animeTitle,
        url: widget.myAnimeListUrl,
        fallbackImageUrl: widget.imageUrl,
        source: source,
      );

      // Enrich with AniList data before navigating
      await AnimeService.enrichAnimeWithAniList(anime);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ModernEpisodeListScreen(anime: anime),
        ),
      );
    }
  }

  Future<dynamic> _showVersionSelectionDialog({
    required AnimeSource source,
    List<AllAnimeShow>? allAnimeShows,
    List<Anime>? animeFireAnimes,
  }) async {
    final l10n = AppLocalizations.of(context);

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.backgroundLight,
          title: Text(
            l10n.locale.languageCode == 'pt'
                ? 'Selecione a versão'
                : 'Select Version',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: source == AnimeSource.allAnime
                  ? (allAnimeShows?.length ?? 0)
                  : (animeFireAnimes?.length ?? 0),
              itemBuilder: (context, index) {
                if (source == AnimeSource.allAnime && allAnimeShows != null) {
                  final show = allAnimeShows[index];
                  return ListTile(
                    title: Text(
                      show.displayName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${show.episodeCount} episodes',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.orange,
                    ),
                    onTap: () => Navigator.pop(context, show),
                  );
                } else if (source == AnimeSource.animeFire &&
                    animeFireAnimes != null) {
                  final anime = animeFireAnimes[index];
                  return ListTile(
                    title: Text(
                      anime.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.orange,
                    ),
                    onTap: () => Navigator.pop(context, anime),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.locale.languageCode == 'pt' ? 'Cancelar' : 'Cancel',
                style: const TextStyle(color: Colors.orange),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // AppBar com imagem do anime
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                l10n.selectVersion,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 8,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.surface),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.surface,
                      child: const Icon(Icons.error, color: Colors.white54),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.background.withValues(alpha: 0.8),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Conteúdo
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título do anime com botão de watchlist
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.animeTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      WatchlistButton(
                        animeId: widget.myAnimeListUrl,
                        title: widget.animeTitle,
                        coverImage: widget.imageUrl,
                        myAnimeListUrl: widget.myAnimeListUrl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.selectVersion,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Opção AllAnime
                  _buildSourceCard(
                    title: 'AllAnime',
                    subtitle: _isSearchingAllAnime
                        ? l10n.searching
                        : _allAnimeResults.isNotEmpty
                        ? _allAnimeResults.length > 1
                              ? 'Available • ${_allAnimeResults.length} versions found'
                              : 'Available • Subtitled'
                        : _allAnimeErrorMessage ?? 'Unavailable',
                    icon: Icons.public,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    available: _allAnimeResults.isNotEmpty,
                    isLoading: _isSearchingAllAnime,
                    onTap: _allAnimeResults.isNotEmpty
                        ? () => _selectSource(AnimeSource.allAnime)
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Opção AnimeFire
                  _buildSourceCard(
                    title: 'AnimeFire',
                    subtitle: _isSearchingAnimeFire
                        ? l10n.searching
                        : _animeFireResults.isNotEmpty
                        ? _animeFireResults.length > 1
                              ? 'Available • ${_animeFireResults.length} versions found'
                              : 'Available • Dubbed/Subtitled'
                        : _animeFireErrorMessage ?? 'Unavailable',
                    icon: Icons.local_fire_department,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                    ),
                    available: _animeFireResults.isNotEmpty,
                    isLoading: _isSearchingAnimeFire,
                    onTap: _animeFireResults.isNotEmpty
                        ? () => _selectSource(AnimeSource.animeFire)
                        : null,
                  ),

                  const SizedBox(height: 32),

                  // Info adicional
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.locale.languageCode == 'pt'
                                ? 'Cada fonte pode ter episódios diferentes disponíveis'
                                : 'Each source may have different episodes available',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required bool available,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: available && !isLoading ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: available && !isLoading
              ? gradient
              : LinearGradient(
                  colors: [Colors.grey.shade800, Colors.grey.shade700],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: available && !isLoading
              ? [
                  BoxShadow(
                    color: gradient.colors.first.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: available && !isLoading ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Ícone
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),

                  // Textos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Indicador
                  if (isLoading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  else if (available)
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 20,
                    )
                  else
                    Icon(
                      Icons.block,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
