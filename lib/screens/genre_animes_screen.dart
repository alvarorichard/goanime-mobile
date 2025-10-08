import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'source_selection_screen.dart';

class GenreAnimesScreen extends StatefulWidget {
  final String title;
  final int? genreId;
  final IconData icon;
  final Gradient gradient;

  const GenreAnimesScreen({
    super.key,
    required this.title,
    this.genreId,
    required this.icon,
    required this.gradient,
  });

  @override
  State<GenreAnimesScreen> createState() => _GenreAnimesScreenState();
}

class _GenreAnimesScreenState extends State<GenreAnimesScreen> {
  final JikanService _jikanService = JikanService();
  final ScrollController _scrollController = ScrollController();

  List<JikanAnime> _animes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMorePages = true;

  @override
  void initState() {
    super.initState();
    _loadAnimes();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages) {
        _loadMoreAnimes();
      }
    }
  }

  Future<void> _loadAnimes() async {
    setState(() => _isLoading = true);
    try {
      List<JikanAnime> animes;

      if (widget.genreId != null) {
        animes = await _jikanService.getAnimesByGenre(
          widget.genreId!,
          limit: 25,
        );
      } else {
        // Para "Top Anime" ou "Season Highlights"
        animes = await _jikanService.getTopAnimes(limit: 25);
      }

      if (mounted) {
        setState(() {
          _animes = animes;
          _isLoading = false;
          _hasMorePages = animes.length >= 25;
        });
      }
    } catch (e) {
      debugPrint('Error loading animes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreAnimes() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      await Future.delayed(const Duration(milliseconds: 600)); // Rate limiting

      List<JikanAnime> newAnimes;

      if (widget.genreId != null) {
        newAnimes = await _jikanService.getAnimesByGenre(
          widget.genreId!,
          page: _currentPage,
          limit: 25,
        );
      } else {
        newAnimes = await _jikanService.getTopAnimes(
          page: _currentPage,
          limit: 25,
        );
      }

      if (mounted) {
        setState(() {
          _animes.addAll(newAnimes);
          _isLoadingMore = false;
          _hasMorePages = newAnimes.length >= 25;
        });
      }
    } catch (e) {
      debugPrint('Error loading more animes: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage--; // Reverte o incremento em caso de erro
        });
      }
    }
  }

  void _onAnimeTap(JikanAnime jikanAnime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SourceSelectionScreen(
          animeTitle: jikanAnime.title,
          imageUrl: jikanAnime.imageUrl,
          myAnimeListUrl: 'https://myanimelist.net/anime/${jikanAnime.malId}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // AppBar com gradiente
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 8,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(gradient: widget.gradient),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        widget.icon,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.background.withValues(alpha: 0.85),
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Conteúdo
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF00BCD4)),
                    const SizedBox(height: 16),
                    Text(
                      l10n.loading,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            )
          else if (_animes.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noResultsFound,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= _animes.length) return null;
                  return _buildAnimeCard(_animes[index]);
                }, childCount: _animes.length),
              ),
            ),

          // Loading indicator para paginação
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
                ),
              ),
            ),

          // Espaçamento final
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _buildAnimeCard(JikanAnime anime) {
    return GestureDetector(
      onTap: () => _onAnimeTap(anime),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagem
              CachedNetworkImage(
                imageUrl: anime.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.surface,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surface,
                  child: const Icon(Icons.error, color: Colors.white54),
                ),
              ),

              // Gradient overlay
              Positioned.fill(
                child: Container(
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
              ),

              // Score badge
              if (anime.score != null && anime.score! > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          anime.score!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Título
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Text(
                  anime.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
