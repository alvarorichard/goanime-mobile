import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../screens/video_player_screen.dart';
import '../../../theme/app_colors.dart';
import '../controllers/continue_watching_controller.dart';
import '../widgets/continue_watching_card.dart';

class ContinueWatchingScreen extends StatefulWidget {
  const ContinueWatchingScreen({super.key});

  @override
  State<ContinueWatchingScreen> createState() => _ContinueWatchingScreenState();
}

class _ContinueWatchingScreenState extends State<ContinueWatchingScreen>
    with WidgetsBindingObserver {
  late ContinueWatchingController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = ContinueWatchingController();
    _controller.addListener(_onControllerChanged);
    _controller.loadContinueWatching();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[ContinueWatchingScreen] App resumed, refreshing...');
      _controller.refresh();
    }
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void _openVideo(int index) {
    final item = _controller.items[index];

    final episode = Episode(
      number: item.episodeNumber,
      url: item.episodeUrl,
      thumbnail: item.imageUrl,
      title: item.animeTitle,
    );

    final anime = Anime(
      name: item.animeTitle,
      url: item.animeUrl ?? '',
      source: item.source == 'AnimeFire'
          ? AnimeSource.animeFire
          : AnimeSource.allAnime,
      allAnimeId: item.animeId,
      fallbackImageUrl: item.imageUrl,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ModernVideoPlayerScreen(
            anime: anime,
            episode: episode,
            animeTitle: item.animeTitle,
          ),
        ),
      );
    }
  }

  void _removeItem(int index) {
    final item = _controller.items[index];
    _controller.removeProgress(item.id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item removido'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Limpar histórico?'),
        content: const Text(
          'Todos os itens de "Continue Assistindo" serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              _controller.clearAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Histórico limpo')));
            },
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Continue Assistindo'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (_controller.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_controller.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.list_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Nenhum item',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Seu histórico de visualização aparecerá aqui',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final isTablet = MediaQuery.of(context).size.width > 600;
    final itemsPerRow = isTablet ? 4 : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: itemsPerRow,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: _controller.items.length,
      itemBuilder: (context, index) {
        return ContinueWatchingCard(
          item: _controller.items[index],
          onTap: () => _openVideo(index),
          onRemove: () => _removeItem(index),
        );
      },
    );
  }
}
