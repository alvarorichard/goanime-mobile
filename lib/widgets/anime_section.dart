import 'package:flutter/material.dart';
import '../models/jikan_models.dart';
import 'anime_card.dart';

class AnimeSection extends StatelessWidget {
  final String title;
  final List<JikanAnime> animes;
  final bool isLoading;
  final VoidCallback? onSeeAll;
  final Function(JikanAnime)? onAnimeTap;
  final bool showLargeCards;

  const AnimeSection({
    super.key,
    required this.title,
    required this.animes,
    this.isLoading = false,
    this.onSeeAll,
    this.onAnimeTap,
    this.showLargeCards = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da seção
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text(
                    'Ver Todos',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Lista de animes
        if (isLoading)
          _buildLoadingState()
        else if (animes.isEmpty)
          _buildEmptyState()
        else if (showLargeCards)
          _buildLargeCardsList()
        else
          _buildHorizontalList(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHorizontalList() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: animes.length,
        itemBuilder: (context, index) {
          final anime = animes[index];
          return AnimeCard(
            anime: anime,
            onTap: onAnimeTap != null ? () => onAnimeTap!(anime) : null,
          );
        },
      ),
    );
  }

  Widget _buildLargeCardsList() {
    return Column(
      children: animes.map((anime) {
        return AnimeCardLarge(
          anime: anime,
          onTap: onAnimeTap != null ? () => onAnimeTap!(anime) : null,
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 240,
      child: Center(
        child: Text(
          'Nenhum anime encontrado',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
