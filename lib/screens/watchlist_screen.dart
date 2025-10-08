import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/watchlist_anime.dart';
import '../services/watchlist_service.dart';
import '../services/watchlist_notifier.dart';
import '../theme/app_colors.dart';
import 'source_selection_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with AutomaticKeepAliveClientMixin {
  final WatchlistService _watchlistService = WatchlistService();
  final WatchlistNotifier _watchlistNotifier = WatchlistNotifier();
  List<WatchlistAnime> _watchlist = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();

    // Escuta mudanças na watchlist
    _watchlistNotifier.addListener(_onWatchlistChanged);
  }

  @override
  void dispose() {
    _watchlistNotifier.removeListener(_onWatchlistChanged);
    super.dispose();
  }

  void _onWatchlistChanged() {
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    setState(() => _isLoading = true);
    final watchlist = await _watchlistService.getWatchlist();
    if (mounted) {
      setState(() {
        _watchlist = watchlist;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromWatchlist(WatchlistAnime anime) async {
    final success = await _watchlistService.removeFromWatchlist(anime.animeId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${anime.title} removido da watchlist'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadWatchlist();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.bookmark, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Watchlist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          if (_watchlist.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white70),
              tooltip: 'Limpar watchlist',
              onPressed: () => _showClearDialog(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _watchlist.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadWatchlist,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _watchlist.length,
                itemBuilder: (context, index) {
                  final anime = _watchlist[index];
                  return _buildAnimeCard(anime);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 120,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),
          Text(
            'Sua watchlist está vazia',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Adicione animes para assistir depois',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeCard(WatchlistAnime anime) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SourceSelectionScreen(
              animeTitle: anime.title,
              imageUrl: anime.coverImage,
              myAnimeListUrl: anime.myAnimeListUrl,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Imagem de capa
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: anime.coverImage,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
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
                    Icons.movie,
                    color: Colors.white30,
                    size: 48,
                  ),
                ),
              ),
            ),

            // Overlay gradiente
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),

            // Botão de remover
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _removeFromWatchlist(anime),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),

            // Título
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Limpar Watchlist?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tem certeza que deseja remover todos os animes da watchlist?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pop();
              await _watchlistService.clearWatchlist();
              _loadWatchlist();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Watchlist limpa'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('Limpar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
