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
  late PageController _bannerPageController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bannerPageController = PageController();

    _scrollController.addListener(_onScroll);
    _loadAllData();
    _startBannerRotation();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _scrollController.dispose();
    _bannerPageController.dispose();
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
      if (mounted &&
          _seasonAnimes.isNotEmpty &&
          _bannerPageController.hasClients) {
        final nextIndex =
            (_currentBannerIndex + 1) % _seasonAnimes.length.clamp(0, 5);
        _bannerPageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
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
              SliverToBoxAdapter(child: _buildHeroBannerCarousel()),

            // Conteúdo principal
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 24),

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
          ? AppColors.background.withValues(alpha: 0.95)
          : Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      flexibleSpace: _headerOpacity > 0
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background,
                    AppColors.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
            )
          : null,
      title: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.play_circle_filled,
          color: Colors.white,
          size: 22,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
          tooltip: 'Search',
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
            size: 24,
          ),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeroBannerCarousel() {
    final bannerAnimes = _seasonAnimes.take(5).toList();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -60 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Transform.scale(scale: 0.90 + (0.10 * value), child: child),
          ),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive height based on screen width
          final screenWidth = constraints.maxWidth;
          // Banner height reduzido levemente: 63% of width, clamped 215-295px
          final bannerHeight = (screenWidth * 0.63).clamp(215.0, 295.0);

          // Abaixado levemente: 106px do topo (antes 100px)
          // Status bar (~44-47px) + AppBar (64px) = ~108-111px
          // Pequeno espaço de segurança sem sobrepor ícones
          final bannerTopMargin = 106.0;

          return Container(
            height: bannerHeight,
            margin: EdgeInsets.only(top: bannerTopMargin, bottom: 12),
            child: Stack(
              children: [
                // PageView with rounded corners
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: PageView.builder(
                        controller: _bannerPageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentBannerIndex = index;
                          });
                        },
                        itemCount: bannerAnimes.length,
                        itemBuilder: (context, index) {
                          final anime = bannerAnimes[index];
                          return _buildBannerItem(anime);
                        },
                      ),
                    ),
                  ),
                ),

                // Dot indicators
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      bannerAnimes.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentBannerIndex == index ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentBannerIndex == index
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: _currentBannerIndex == index
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerItem(JikanAnime anime) {
    return GestureDetector(
      onTap: () => _onAnimeTap(anime),
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: anime.largImageUrl ?? anime.imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              memCacheWidth: 1200,
              memCacheHeight: 1600,
              maxWidthDiskCache: 1200,
              maxHeightDiskCache: 1600,
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

          // Subtle gradient overlay (Apple-style - more subtle)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Title overlay
          Positioned(
            bottom: 10,
            left: 12,
            right: 12,
            child: Text(
              anime.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black45,
                  ),
                ],
                letterSpacing: 0.2,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
                        padding: const EdgeInsets.all(9),
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
                        child: Icon(icon, color: Colors.white, size: 19),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
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
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1.5,
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
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: AppColors.primary,
                                  size: 11,
                                ),
                              ],
                            ),
                          ),
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
                          showScore: sectionId != 'season',
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
    int index, {
    bool showScore = true,
  }) {
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
                        imageUrl: anime.largImageUrl ?? anime.imageUrl,
                        width: 160,
                        height: 220,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        memCacheWidth: 480, // Cache 3x para máxima qualidade
                        memCacheHeight: 660,
                        maxWidthDiskCache: 480,
                        maxHeightDiskCache: 660,
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

                    // Score badge com Glassmorphism (only if showScore is true)
                    if (showScore && anime.score != null)
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
