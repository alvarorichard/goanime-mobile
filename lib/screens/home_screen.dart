import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/jikan_models.dart';
import '../services/jikan_service.dart';
import '../main.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final JikanService _jikanService = JikanService();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _fabAnimationController;
  late AnimationController _headerAnimationController;
  
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
    _headerAnimationController = AnimationController(
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
    _headerAnimationController.dispose();
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
    
    // Fade out do header ao rolar
    setState(() {
      _headerOpacity = (1 - (offset / 400)).clamp(0.0, 1.0);
    });
  }

  void _startBannerRotation() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _seasonAnimes.isNotEmpty) {
        setState(() {
          _currentBannerIndex = (_currentBannerIndex + 1) % _seasonAnimes.length.clamp(0, 5);
        });
        _startBannerRotation();
      }
    });
  }

  Future<void> _loadAllData() async {
    // Carrega dados com delays para respeitar rate limit
    _loadCurrentSeason();
    await Future.delayed(const Duration(milliseconds: 400));
    _loadTopAnimes();
    await Future.delayed(const Duration(milliseconds: 400));
    _loadActionAnimes();
    await Future.delayed(const Duration(milliseconds: 400));
    _loadRomanceAnimes();
    await Future.delayed(const Duration(milliseconds: 400));
    _loadComedyAnimes();
    await Future.delayed(const Duration(milliseconds: 400));
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
      print('Error loading season animes: $e');
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
      print('Error loading top animes: $e');
      if (mounted) setState(() => _isLoadingTop = false);
    }
  }

  Future<void> _loadActionAnimes() async {
    setState(() => _isLoadingAction = true);
    try {
      final animes = await _jikanService.getAnimesByGenre(JikanGenreIds.action, limit: 15);
      if (mounted) {
        setState(() {
          _actionAnimes = animes;
          _isLoadingAction = false;
        });
      }
    } catch (e) {
      print('Error loading action animes: $e');
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _loadRomanceAnimes() async {
    setState(() => _isLoadingRomance = true);
    try {
      final animes = await _jikanService.getAnimesByGenre(JikanGenreIds.romance, limit: 15);
      if (mounted) {
        setState(() {
          _romanceAnimes = animes;
          _isLoadingRomance = false;
        });
      }
    } catch (e) {
      print('Error loading romance animes: $e');
      if (mounted) setState(() => _isLoadingRomance = false);
    }
  }

  Future<void> _loadComedyAnimes() async {
    setState(() => _isLoadingComedy = true);
    try {
      final animes = await _jikanService.getAnimesByGenre(JikanGenreIds.comedy, limit: 15);
      if (mounted) {
        setState(() {
          _comedyAnimes = animes;
          _isLoadingComedy = false;
        });
      }
    } catch (e) {
      print('Error loading comedy animes: $e');
      if (mounted) setState(() => _isLoadingComedy = false);
    }
  }

  Future<void> _loadFantasyAnimes() async {
    setState(() => _isLoadingFantasy = true);
    try {
      final animes = await _jikanService.getAnimesByGenre(JikanGenreIds.fantasy, limit: 15);
      if (mounted) {
        setState(() {
          _fantasyAnimes = animes;
          _isLoadingFantasy = false;
        });
      }
    } catch (e) {
      print('Error loading fantasy animes: $e');
      if (mounted) setState(() => _isLoadingFantasy = false);
    }
  }

  Future<void> _onAnimeTap(JikanAnime anime) async {
    // Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Buscando ${anime.title}...',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Busca o anime no AllAnime/AnimeFire
      final results = await AnimeService.searchAnime(anime.title);
      
      if (!mounted) return;
      Navigator.pop(context); // Remove loading

      if (results.isEmpty) {
        _showErrorDialog('Anime não encontrado', 
          'Não foi possível encontrar "${anime.title}" no AllAnime ou AnimeFire.');
        return;
      }

      // Se encontrou apenas um, vai direto para episódios
      if (results.length == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EpisodeListScreen(anime: results.first),
          ),
        );
      } else {
        // Se encontrou vários, mostra diálogo para escolher
        _showAnimeSelectionDialog(anime.title, results);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Remove loading
      _showErrorDialog('Erro', 'Erro ao buscar anime: $e');
    }
  }

  void _showAnimeSelectionDialog(String searchTerm, List<Anime> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Selecione a versão',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final anime = results[index];
              return ListTile(
                leading: Icon(
                  anime.source == AnimeSource.allAnime 
                    ? Icons.star 
                    : Icons.local_fire_department,
                  color: Colors.orange,
                ),
                title: Text(
                  anime.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  anime.sourceName,
                  style: TextStyle(color: Colors.grey[400]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EpisodeListScreen(anime: anime),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: Colors.orange,
        backgroundColor: const Color(0xFF1A1A2E),
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
                    title: 'Destaques da Temporada',
                    icon: Icons.whatshot,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    ),
                    animes: _seasonAnimes,
                    isLoading: _isLoadingSeason,
                  ),
                  
                  // Seção: Top Animes
                  _buildModernSection(
                    title: 'Top Animes',
                    icon: Icons.star,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD93D), Color(0xFFFFA500)],
                    ),
                    animes: _topAnimes,
                    isLoading: _isLoadingTop,
                  ),
                  
                  // Seção: Ação
                  _buildModernSection(
                    title: 'Ação',
                    icon: Icons.flash_on,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    ),
                    animes: _actionAnimes,
                    isLoading: _isLoadingAction,
                  ),
                  
                  // Seção: Romance
                  _buildModernSection(
                    title: 'Romance',
                    icon: Icons.favorite,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B9D), Color(0xFFC44569)],
                    ),
                    animes: _romanceAnimes,
                    isLoading: _isLoadingRomance,
                  ),
                  
                  // Seção: Comédia
                  _buildModernSection(
                    title: 'Comédia',
                    icon: Icons.emoji_emotions,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                    ),
                    animes: _comedyAnimes,
                    isLoading: _isLoadingComedy,
                  ),
                  
                  // Seção: Fantasia
                  _buildModernSection(
                    title: 'Fantasia',
                    icon: Icons.auto_awesome,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    animes: _fantasyAnimes,
                    isLoading: _isLoadingFantasy,
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
              backgroundColor: Colors.orange,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
          )
        : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0F0F1E).withOpacity(0.8),
                  const Color(0xFF1A1A2E).withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Opacity(
        opacity: _headerOpacity,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              ).createShader(bounds),
              child: const Text(
                'GoAnime',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.search, color: Colors.white),
          ),
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(position: offsetAnimation, child: child);
                },
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeroBanner(JikanAnime anime) {
    return Container(
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
                color: const Color(0xFF1A1A2E),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: const Color(0xFF1A1A2E),
                child: const Icon(Icons.error, color: Colors.white54),
              ),
            ),
          ),
          
          // Gradient overlay com múltiplas camadas
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0F0F1E).withOpacity(0.3),
                    const Color(0xFF0F0F1E).withOpacity(0.8),
                    const Color(0xFF0F0F1E),
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
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
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.whatshot, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'EM ALTA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
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
                  
                  // Informações
                  Row(
                    children: [
                      if (anime.score != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
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
                        const SizedBox(width: 12),
                      ],
                      if (anime.episodes != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tv, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${anime.episodes} eps',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
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
                    label: const Text(
                      'ASSISTIR AGORA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                      shadowColor: Colors.orange.withOpacity(0.5),
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

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required List<JikanAnime> animes,
    required bool isLoading,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da seção
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver Todos',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, color: Colors.orange, size: 14),
                    ],
                  ),
                ),
              ],
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
                          return _buildModernAnimeCard(animes[index], gradient);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAnimeCard(JikanAnime anime, Gradient gradient) {
    return GestureDetector(
      onTap: () => _onAnimeTap(anime),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card com imagem
            Hero(
              tag: 'anime_${anime.malId}',
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.colors.first.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
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
                          color: const Color(0xFF1A1A2E),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.orange),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF1A1A2E),
                          child: const Icon(Icons.error, color: Colors.white54),
                        ),
                      ),
                    ),
                    
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Score badge
                    if (anime.score != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 12),
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
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
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
    return const Center(
      child: Text(
        'Nenhum anime encontrado',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }
}
