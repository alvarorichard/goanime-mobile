import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../services/allanime_service.dart';
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
  String? _allAnimeId;
  String? _allAnimeErrorMessage;
  Anime? _animeFireResult;
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
          _allAnimeId = searchResponse.shows.first.id;
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
          _animeFireResult = animeFireResults.first;
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

  void _selectSource(AnimeSource source) {
    Anime anime;

    if (source == AnimeSource.allAnime && _allAnimeId != null) {
      // Para AllAnime, cria um novo anime com o ID encontrado
      anime = Anime(
        name: widget.animeTitle,
        url: widget.myAnimeListUrl,
        fallbackImageUrl: widget.imageUrl,
        source: AnimeSource.allAnime,
        allAnimeId: _allAnimeId,
      );
    } else if (source == AnimeSource.animeFire && _animeFireResult != null) {
      // Para AnimeFire, usa o anime já encontrado na busca
      anime = _animeFireResult!;
    } else {
      // Fallback (não deveria acontecer)
      anime = Anime(
        name: widget.animeTitle,
        url: widget.myAnimeListUrl,
        fallbackImageUrl: widget.imageUrl,
        source: source,
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ModernEpisodeListScreen(anime: anime),
      ),
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
                  // Título do anime
                  Text(
                    widget.animeTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
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
                        : _allAnimeId != null
                        ? 'Available • Subtitled'
                        : _allAnimeErrorMessage ?? 'Unavailable',
                    icon: Icons.public,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    available: _allAnimeId != null,
                    isLoading: _isSearchingAllAnime,
                    onTap: _allAnimeId != null
                        ? () => _selectSource(AnimeSource.allAnime)
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Opção AnimeFire
                  _buildSourceCard(
                    title: 'AnimeFire',
                    subtitle: _isSearchingAnimeFire
                        ? l10n.searching
                        : _animeFireResult != null
                        ? 'Available • Dubbed/Subtitled'
                        : _animeFireErrorMessage ?? 'Unavailable',
                    icon: Icons.local_fire_department,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                    ),
                    available: _animeFireResult != null,
                    isLoading: _isSearchingAnimeFire,
                    onTap: () => _selectSource(AnimeSource.animeFire),
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
