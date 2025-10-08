import 'package:flutter/material.dart';
import '../models/watchlist_anime.dart';
import '../services/watchlist_service.dart';
import '../services/watchlist_notifier.dart';
import '../theme/app_colors.dart';

class WatchlistButton extends StatefulWidget {
  final String animeId;
  final String title;
  final String coverImage;
  final String myAnimeListUrl;

  const WatchlistButton({
    super.key,
    required this.animeId,
    required this.title,
    required this.coverImage,
    required this.myAnimeListUrl,
  });

  @override
  State<WatchlistButton> createState() => _WatchlistButtonState();
}

class _WatchlistButtonState extends State<WatchlistButton> {
  final WatchlistService _watchlistService = WatchlistService();
  bool _isInWatchlist = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkWatchlist();
  }

  Future<void> _checkWatchlist() async {
    final isInWatchlist = await _watchlistService.isInWatchlist(widget.animeId);
    if (mounted) {
      setState(() {
        _isInWatchlist = isInWatchlist;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleWatchlist() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_isInWatchlist) {
      final success = await _watchlistService.removeFromWatchlist(
        widget.animeId,
      );
      if (success && mounted) {
        setState(() => _isInWatchlist = false);
        WatchlistNotifier().notifyWatchlistChanged();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Removido da watchlist'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      final anime = WatchlistAnime(
        animeId: widget.animeId,
        title: widget.title,
        coverImage: widget.coverImage,
        myAnimeListUrl: widget.myAnimeListUrl,
        addedAt: DateTime.now(),
      );
      final success = await _watchlistService.addToWatchlist(anime);
      if (success && mounted) {
        setState(() => _isInWatchlist = true);
        WatchlistNotifier().notifyWatchlistChanged();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Adicionado à watchlist'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleWatchlist,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(
            color: _isInWatchlist
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Icon(
          _isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
          color: _isInWatchlist ? AppColors.primary : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
