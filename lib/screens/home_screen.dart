import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'genre_animes_screen.dart';
import 'source_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final JikanService _jikanService = JikanService();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fabAnimationController;

  bool _showFab = false;
  double _headerOpacity = 1.0;

  // Estados de carregamento
  bool _isLoadingSeason = true;
  bool _isLoadingTop = true;
  bool _isLoadingAction = true;
  bool _isLoadingRomance = true;
  bool _isLoadingComedy = true;
  bool _isLoadingFantasy = true;

  // Listas de animes
  List<JikanAnime> _seasonAnimes = [];
  List<JikanAnime> _topAnimes = [];
  List<JikanAnime> _actionAnimes = [];
  List<JikanAnime> _romanceAnimes = [];
  List<JikanAnime> _comedyAnimes = [];
  List<JikanAnime> _fantasyAnimes = [];

  // Índice do banner atual
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scrollController.addListener(_onScroll);
    _loadAllData();
    _startBannerRotation();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;

    // Mostrar FAB quando rolar para baixo
    if (offset > 300 && !_showFab) {
      setState(() => _showFab = true);
      _fabAnimationController.forward();
    } else if (offset <= 300 && _showFab) {
      setState(() => _showFab = false);
      _fabAnimationController.reverse();
    }

    // Header transparente no topo, preto sólido ao rolar (estilo Netflix)
    final newOpacity = offset > 0 ? 1.0 : 0.0;
    if ((newOpacity - _headerOpacity).abs() > 0.01) {
      setState(() {
        _headerOpacity = newOpacity;
      });
    }
  }

  void _startBannerRotation() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _seasonAnimes.isNotEmpty) {
        setState(() {
          _currentBannerIndex =
              (_currentBannerIndex + 1) % _seasonAnimes.length.clamp(0, 5);
        });
        _startBannerRotation();
      }
    });
  }

  Future<void> _loadAllData() async {
    // Carrega dados com delays para respeitar rate limit da Jikan API
    _loadCurrentSeason();
    await Future.delayed(const Duration(milliseconds: 600));
    _loadTopAnimes();
    await Future.delayed(const Duration(milliseconds: 600));
    _loadActionAnimes();
    await Future.delayed(const Duration(milliseconds: 600));
    _loadRomanceAnimes();
    await Future.delayed(const Duration(milliseconds: 600));
    _loadComedyAnimes();
    await Future.delayed(const Duration(milliseconds: 600));
    _loadFantasyAnimes();
  }

  Future<void> _loadCurrentSeason() async {
    setState(() => _isLoadingSeason = true);
    try {
      final animes = await _jikanService.getCurrentSeasonAnimes(limit: 15);
      if (mounted) {
        setState(() {
          _seasonAnimes = animes;
          _isLoadingSeason = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading season animes: $e');
      if (mounted) setState(() => _isLoadingSeason = false);
    }
  }

  Future<void> _loadTopAnimes() async {
    setState(() => _isLoadingTop = true);
    try {
      final animes = await _jikanService.getTopAnimes(limit: 15);
      if (mounted) {
        setState(() {
          _topAnimes = animes;
          _isLoadingTop = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading top animes: $e');
      if (mounted) setState(() => _isLoadingTop = false);
    }
  }

  Future<void> _loadActionAnimes() async {
    setState(() => _isLoadingAction = true);
    try {
      final animes = await _jikanService.getAnimesByGenre(
        JikanGenreIds.action,
        limit: 15,
      );
      if (mounted) {
        setState(() {
          _actionAnimes = animes;
          _isLoadingAction = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading action animes: $e');
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _loadRomanceAnimes() async {
    setState(() => _isLoadingRomance = true);
    try {
      debugPrint(
        'Loading Romance animes with genre ID: ${JikanGenreIds.romance}',
      );
      final animes = await _jikanService.getAnimesByGenre(
        JikanGenreIds.romance,
        limit: 15,
      );
      debugPrint('Loaded ${animes.length} romance animes');
      if (mounted) {
        setState(() {
          _romanceAnimes = animes;
          _isLoadingRomance = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading romance animes: $e');
      if (mounted) setState(() => _isLoadingRomance = false);
    }
  }

  Future<void> _loadComedyAnimes() async {
    setState(() => _isLoadingComedy = true);
    try {
      final animes = await _jikanService.getAnimesByGenre(
        JikanGenreIds.comedy,
        limit: 15,
      );
      if (mounted) {
        setState(() {
          _comedyAnimes = animes;
          _isLoadingComedy = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading comedy animes: $e');
      if (mounted) setState(() => _isLoadingComedy = false);
    }
  }

  Future<void> _loadFantasyAnimes() async {
    setState(() => _isLoadingFantasy = true);
    try {
      debugPrint(
        'Loading Fantasy animes with genre ID: ${JikanGenreIds.fantasy}',
      );
      final animes = await _jikanService.getAnimesByGenre(
        JikanGenreIds.fantasy,
        limit: 15,
      );
      debugPrint('Loaded ${animes.length} fantasy animes');
      if (mounted) {
        setState(() {
          _fantasyAnimes = animes;
          _isLoadingFantasy = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading fantasy animes: $e');
      if (mounted) setState(() => _isLoadingFantasy = false);
    }
  }

  void _onAnimeTap(JikanAnime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SourceSelectionScreen(
          animeTitle: anime.title,
          imageUrl: anime.imageUrl,
          myAnimeListUrl: 'https://myanimelist.net/anime/${anime.malId}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Banner Hero com Parallax
            if (_seasonAnimes.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildHeroBanner(_seasonAnimes[_currentBannerIndex]),
              ),

            // Conteúdo principal
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Seção: Destaques da Temporada
                  _buildModernSection(
                    title: l10n.seasonHighlights,
                    icon: Ionicons.trending_up_outline,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    animes: _seasonAnimes,
                    isLoading: _isLoadingSeason,
                    sectionId: 'season',
                    genreId: null,
                  ),

                  // Seção: Top Animes
                  _buildModernSection(
                    title: l10n.topAnime,
                    icon: LucideIcons.trophy,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD93D), Color(0xFFFFA500)],
                    ),
                    animes: _topAnimes,
                    isLoading: _isLoadingTop,
                    sectionId: 'top',
                    genreId: null,
                  ),

                  // Seção: Ação
                  _buildModernSection(
                    title: l10n.action,
                    icon: LucideIcons.swords,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    ),
                    animes: _actionAnimes,
                    isLoading: _isLoadingAction,
                    sectionId: 'action',
                    genreId: JikanGenreIds.action,
                  ),

                  // Seção: Romance
                  _buildModernSection(
                    title: l10n.romance,
                    icon: LucideIcons.heart,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B9D), Color(0xFFC44569)],
                    ),
                    animes: _romanceAnimes,
                    isLoading: _isLoadingRomance,
                    sectionId: 'romance',
                    genreId: JikanGenreIds.romance,
                  ),

                  // Seção: Comédia
                  _buildModernSection(
                    title: l10n.comedy,
                    icon: LucideIcons.laugh,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                    ),
                    animes: _comedyAnimes,
                    isLoading: _isLoadingComedy,
                    sectionId: 'comedy',
                    genreId: JikanGenreIds.comedy,
                  ),

                  // Seção: Fantasia
                  _buildModernSection(
                    title: l10n.fantasy,
                    icon: LucideIcons.wand2,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    animes: _fantasyAnimes,
                    isLoading: _isLoadingFantasy,
                    sectionId: 'fantasy',
                    genreId: JikanGenreIds.fantasy,
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showFab
          ? ScaleTransition(
              scale: _fabAnimationController,
              child: FloatingActionButton(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _headerOpacity > 0
          ? AppColors.background
          : Colors.transparent,
      elevation: 0,
      toolbarHeight: 60,
      title: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.play_circle_filled,
          color: Colors.white,
          size: 24,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 26),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
            size: 26,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildHeroBanner(JikanAnime anime) {
    final l10n = AppLocalizations.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200), // Slower entrance
      curve: Curves.easeOutQuart, // Smoother, more elegant curve
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -60 * (1 - value)), // More dramatic slide from top
          child: Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.90 + (0.10 * value), // More noticeable scale
              child: child,
            ),
          ),
        );
      },
      child: Container(
        height: 500,
        margin: const EdgeInsets.only(top: 0),
        child: Stack(
          children: [
            // Imagem de fundo com parallax
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: anime.largImageUrl ?? anime.imageUrl,
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
            ),

            // Gradient overlay com múltiplas camadas (Netflix-style)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.3),
                      AppColors.background.withValues(alpha: 0.85),
                      AppColors.background,
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Conteúdo
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título
                    Text(
                      anime.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 8,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Informações com Glassmorphism
                    Row(
                      children: [
                        if (anime.score != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      anime.score!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (anime.episodes != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.tv,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${anime.episodes} eps',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botão Play
                    ElevatedButton.icon(
                      onPressed: () => _onAnimeTap(anime),
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: Text(
                        l10n.watchNow.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required List<JikanAnime> animes,
    required bool isLoading,
    String? sectionId,
    int? genreId,
  }) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da seção com Glassmorphism
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(
              milliseconds: 900,
            ), // Slower for better visibility
            curve: Curves.easeOutQuart, // Smoother curve
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(
                  -100 * (1 - value),
                  0,
                ), // More pronounced horizontal slide
                child: Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.88 + (0.12 * value), // Slightly more scale
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              gradient.colors.first.withValues(alpha: 0.3),
                              gradient.colors.last.withValues(alpha: 0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: gradient.colors.first.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: gradient.colors.first.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GenreAnimesScreen(
                                title: title,
                                icon: icon,
                                gradient: gradient,
                                genreId: genreId,
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.seeAll,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: AppColors.primary,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lista de animes
          SizedBox(
            height: 280,
            child: isLoading
                ? _buildLoadingCards()
                : animes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: animes.length,
                    itemBuilder: (context, index) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(
                          milliseconds: 800 + (index * 150),
                        ), // Slower animation
                        curve: Curves.easeOutQuart, // Smoother curve
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(
                              80 *
                                  (1 -
                                      value), // Stronger horizontal slide from right
                              20 * (1 - value), // Subtle vertical slide
                            ),
                            child: Opacity(
                              opacity: value,
                              child: Transform.scale(
                                scale:
                                    0.85 +
                                    (0.15 * value), // Gentler scale effect
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: _buildModernAnimeCard(
                          animes[index],
                          gradient,
                          sectionId ?? title,
                          index,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAnimeCard(
    JikanAnime anime,
    Gradient gradient,
    String sectionId,
    int index,
  ) {
    return GestureDetector(
      onTap: () => _onAnimeTap(anime),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card com imagem + Glassmorphism
            Hero(
              tag: 'anime_${sectionId}_${anime.malId}_$index',
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Imagem
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: anime.imageUrl,
                        width: 160,
                        height: 220,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.surface,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.error, color: Colors.white54),
                        ),
                      ),
                    ),

                    // Gradient overlay com blur
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
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
                      ),
                    ),

                    // Score badge com Glassmorphism
                    if (anime.score != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    anime.score!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Título
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCards() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          width: 160,
          margin: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Text(
        l10n.noAnimeFound,
        style: const TextStyle(color: Colors.white54),
      ),
    );
  }
}
