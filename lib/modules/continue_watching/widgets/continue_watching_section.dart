import 'package:flutter/material.dart';
import 'package:goanime/main.dart';
import 'package:goanime/modules/continue_watching/continue_watching.dart';
import 'package:goanime/screens/video_player_screen.dart';
import 'package:goanime/theme/app_colors.dart';
import 'package:goanime/utils/responsive.dart';

const _debugTag = '[ContinueWatchingSection]';

class ContinueWatchingSection extends StatefulWidget {
  const ContinueWatchingSection({super.key});

  @override
  State<ContinueWatchingSection> createState() =>
      _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<ContinueWatchingSection> {
  late ContinueWatchingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ContinueWatchingController();
    _controller.addListener(_onControllerChanged);
    _controller.loadContinueWatching();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _removeItem(ContinueWatchingModel item) {
    _controller.removeProgress(item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item removido'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onCardTap(
    BuildContext context,
    ContinueWatchingModel item,
  ) async {
    if (!context.mounted) return;

    try {
      debugPrint(
        '$_debugTag 🎬 ${item.animeTitle} - Ep ${item.episodeNumber} | ${item.formattedProgress}/${item.formattedDuration}',
      );

      // Criar objetos do episódio e anime
      final episode = Episode(
        number: item.episodeNumber,
        url: item.episodeUrl,
        thumbnail: item.imageUrl,
        title: '${item.animeTitle} - Ep ${item.episodeNumber}',
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

      // Navegar para o player de vídeo
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ModernVideoPlayerScreen(
            anime: anime,
            episode: episode,
            animeTitle: item.animeTitle,
          ),
        ),
      );

      // Recarregar dados após voltar (progresso foi atualizado no video player)
      if (mounted) {
        await _controller.refresh();
      }
    } catch (e) {
      debugPrint('$_debugTag ❌ Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading || _controller.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildContent();
  }

  Widget _buildContent() {
    final horizontalPadding = Responsive.getHorizontalPadding(context);
    final cardHeight = Responsive.getCardHeight(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.3),
                        AppColors.secondary.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Continue Assistindo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lista horizontal
          SizedBox(
            height: cardHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: _controller.items.length,
              cacheExtent: 500,
              itemBuilder: (context, index) {
                final item = _controller.items[index];
                return Container(
                  width: Responsive.getHorizontalListItemWidth(context),
                  margin: const EdgeInsets.only(right: 12),
                  child: ContinueWatchingCard(
                    key: ValueKey(item.id),
                    item: item,
                    onTap: () => _onCardTap(context, item),
                    onRemove: () => _removeItem(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
