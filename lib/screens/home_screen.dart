import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/jikan_models.dart';
import '../modules/continue_watching/widgets/continue_watching_section.dart';
import '../services/jikan_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/shimmer_loading.dart';
import 'genre_animes_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'source_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final JikanService _jikanService = JikanService();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fabAnimationController;

  bool _showFab = false;
  double _headerOpacity = 1.0;
  bool _dataLoaded = false;
  bool _isLoading = true;

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
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bannerPageController = PageController();

    _scrollController.addListener(_onScroll);
    if (!_dataLoaded) {
      _loadAllData();
    }
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

    if (offset > 300 && !_showFab) {
      setState(() => _showFab = true);
      _fabAnimationController.forward();
    } else if (offset <= 300 && _showFab) {
      setState(() => _showFab = false);
      _fabAnimationController.reverse();
    }

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

  /// Carrega TODOS os dados de uma vez usando o método otimizado
  Future<void> _loadAllData({bool forceRefresh = false}) async {
    _dataLoaded = true;

    if (!forceRefresh && _seasonAnimes.isNotEmpty) {
      // Já tem dados, não precisa recarregar
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Carrega tudo de uma vez com o novo método paralelo
      final homeData = await _jikanService.loadHomeData(
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _seasonAnimes = homeData.seasonAnimes;
          _topAnimes = homeData.topAnimes;
          _actionAnimes = homeData.actionAnimes;
          _romanceAnimes = homeData.romanceAnimes;
          _comedyAnimes = homeData.comedyAnimes;
          _fantasyAnimes = homeData.fantasyAnimes;
          _isLoading = false;
        });

        // Pre-cache das imagens do banner para transições suaves
        _precacheBannerImages();
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Pre-carrega imagens do banner para transições mais suaves
  void _precacheBannerImages() {
    final bannerAnimes = _seasonAnimes.take(5);
    for (final anime in bannerAnimes) {
      final imageUrl = anime.largImageUrl ?? anime.imageUrl;
      precacheImage(CachedNetworkImageProvider(imageUrl), context);
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
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () => _loadAllData(forceRefresh: true),
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

                  // Seção: Continue Assistindo
                  const ContinueWatchingSection(),

                  // Seção: Destaques da Temporada
                  _buildModernSection(
                    title: l10n.seasonHighlights,
                    icon: Ionicons.trending_up_outline,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    animes: _seasonAnimes,
                    isLoading: _isLoading && _seasonAnimes.isEmpty,
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
                    isLoading: _isLoading && _topAnimes.isEmpty,
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
                    isLoading: _isLoading && _actionAnimes.isEmpty,
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
                    isLoading: _isLoading && _romanceAnimes.isEmpty,
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
                    isLoading: _isLoading && _comedyAnimes.isEmpty,
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
                    isLoading: _isLoading && _fantasyAnimes.isEmpty,
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

    return AnimatedOpacity(
      opacity: _seasonAnimes.isEmpty ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive banner height
          final bannerHeight = Responsive.getBannerHeight(context);
          final padding = Responsive.getHorizontalPadding(context);

          // Ajuste para diferentes dispositivos
          final bannerTopMargin = Responsive.value(
            context,
            phone: 106.0,
            tablet: 100.0,
            quest: 90.0,
          );

          return Container(
            height: bannerHeight,
            margin: EdgeInsets.only(top: bannerTopMargin, bottom: 12),
            child: Stack(
              children: [
                // PageView with rounded corners
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Responsive.value(
                          context,
                          phone: 20.0,
                          tablet: 24.0,
                          quest: 28.0,
                        ),
                      ),
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
              filterQuality: FilterQuality.medium,
              memCacheWidth: 600,
              memCacheHeight: 800,
              maxWidthDiskCache: 600,
              maxHeightDiskCache: 800,
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
    final horizontalPadding = Responsive.getHorizontalPadding(context);
    final sectionHeight = Responsive.getSectionHeight(context);
    final titleSize = Responsive.getSectionTitleSize(context);

    return AnimatedOpacity(
      opacity: isLoading ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da seção (simplificado para performance)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                children: [
                  // Ícone da seção (simplificado para performance)
                  Container(
                    padding: EdgeInsets.all(
                      Responsive.value(context, phone: 9.0, tablet: 11.0),
                    ),
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
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: Responsive.value(
                        context,
                        phone: 19.0,
                        tablet: 22.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botão "Ver todos" simplificado
                  Material(
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
                            width: 1,
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista de animes (otimizada - responsiva)
            SizedBox(
              height: sectionHeight,
              child: isLoading
                  ? _buildLoadingCards()
                  : animes.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      itemCount: animes.length,
                      cacheExtent: 500, // Pre-render cards para scroll suave
                      itemBuilder: (context, index) {
                        return _buildModernAnimeCard(
                          animes[index],
                          gradient,
                          sectionId ?? title,
                          index,
                          showScore: sectionId != 'season',
                        );
                      },
                    ),
            ),
          ],
        ),
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
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);

    return _AnimatedAnimeCard(
      anime: anime,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      spacing: spacing,
      sectionId: sectionId,
      index: index,
      showScore: showScore,
      onTap: () => _onAnimeTap(anime),
    );
  }

  Widget _buildLoadingCards() {
    final cardWidth = Responsive.getHorizontalListItemWidth(context);
    final cardHeight = Responsive.getCardHeight(context);
    final spacing = Responsive.getCardSpacing(context);
    final padding = Responsive.getHorizontalPadding(context);

    return ShimmerAnimeList(
      itemWidth: cardWidth,
      itemHeight: cardHeight,
      spacing: spacing,
      padding: EdgeInsets.symmetric(horizontal: padding),
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

/// Card de anime com animação leve de hover/press
class _AnimatedAnimeCard extends StatefulWidget {
  final JikanAnime anime;
  final double cardWidth;
  final double cardHeight;
  final double spacing;
  final String sectionId;
  final int index;
  final bool showScore;
  final VoidCallback onTap;

  const _AnimatedAnimeCard({
    required this.anime,
    required this.cardWidth,
    required this.cardHeight,
    required this.spacing,
    required this.sectionId,
    required this.index,
    required this.showScore,
    required this.onTap,
  });

  @override
  State<_AnimatedAnimeCard> createState() => _AnimatedAnimeCardState();
}

class _AnimatedAnimeCardState extends State<_AnimatedAnimeCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isola o card para evitar repaint de toda a lista
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: widget.cardWidth,
            margin: EdgeInsets.only(right: widget.spacing),
            transform: Matrix4.identity()
              ..setEntry(0, 0, _isPressed ? 0.96 : (_isHovered ? 1.03 : 1.0))
              ..setEntry(1, 1, _isPressed ? 0.96 : (_isHovered ? 1.03 : 1.0)),
            transformAlignment: Alignment.center,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card com imagem (otimizado)
                Hero(
                  tag:
                      'anime_${widget.sectionId}_${widget.anime.malId}_${widget.index}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: widget.cardHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _isHovered
                              ? AppColors.primary.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.3),
                          blurRadius: _isHovered ? 14 : 8,
                          offset: Offset(0, _isHovered ? 6 : 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Imagem (cache otimizado 2x para retina)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl:
                                widget.anime.largImageUrl ??
                                widget.anime.imageUrl,
                            width: widget.cardWidth,
                            height: widget.cardHeight,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            memCacheWidth: (widget.cardWidth * 2).toInt(),
                            memCacheHeight: (widget.cardHeight * 2).toInt(),
                            placeholder: (context, url) => Container(
                              color: AppColors.surface,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surface,
                              child: const Icon(
                                Icons.error,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),

                        // Gradient overlay simples (sem blur)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
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

                        // Score badge simples (sem blur para performance)
                        if (widget.showScore && widget.anime.score != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
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
                                    widget.anime.score!.toStringAsFixed(1),
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

                        // Hover overlay
                        if (_isHovered)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: _isHovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 2,
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
                  widget.anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.value(
                      context,
                      phone: 13.0,
                      tablet: 14.0,
                    ),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
