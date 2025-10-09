import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import 'video_player_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/download_button.dart';
import '../services/download_service.dart';

export 'package:provider/provider.dart';

// Function to remove HTML tags from description
String _removeHtmlTags(String htmlText) {
  return htmlText
      .replaceAll(RegExp(r'<br>|<br/>|<br />'), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

// Function to extract only the episode number
String _getEpisodeNumber(String episodeText, int index) {
  // Try various patterns to extract episode number
  final patterns = [
    RegExp(r'Episódio\s*(\d+)', caseSensitive: false),
    RegExp(r'Episode\s*(\d+)', caseSensitive: false),
    RegExp(r'Ep\.?\s*(\d+)', caseSensitive: false),
    RegExp(r'-\s*Episódio\s*(\d+)', caseSensitive: false),
    RegExp(r'\b(\d+)$'), // Number at the end
    RegExp(r'\d+'), // Any number
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(episodeText);
    if (match != null) {
      final number = match.group(1) ?? match.group(0);
      if (number != null && number.isNotEmpty) {
        return number;
      }
    }
  }

  // If no number found, use the index
  return '${index + 1}';
}

// Function to generate episode label
String _getEpisodeLabel(String episodeText, int index) {
  final number = _getEpisodeNumber(episodeText, index);
  return 'Episode $number';
}

class ModernEpisodeListScreen extends StatefulWidget {
  final Anime anime;

  const ModernEpisodeListScreen({super.key, required this.anime});

  @override
  State<ModernEpisodeListScreen> createState() =>
      _ModernEpisodeListScreenState();
}

class _ModernEpisodeListScreenState extends State<ModernEpisodeListScreen>
    with SingleTickerProviderStateMixin {
  List<Episode> _episodes = [];
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animationController;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
    _loadEpisodes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final episodes = await AnimeService.getAnimeEpisodes(widget.anime);
      if (mounted) {
        setState(() {
          _episodes = episodes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _openEpisode(Episode episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModernVideoPlayerScreen(
          anime: widget.anime,
          episode: episode,
          animeTitle: widget.anime.name,
        ),
      ),
    );
  }

  void _showBatchDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => BatchDownloadDialog(
        animeId: widget.anime.url,
        animeName: widget.anime.name,
        thumbnailUrl: widget.anime.imageUrl,
        episodes: _episodes.map((e) {
          final episodeNumber = _getEpisodeNumber(
            e.number,
            _episodes.indexOf(e),
          );
          return {
            'number': episodeNumber,
            'title': _getEpisodeLabel(e.number, _episodes.indexOf(e)),
            'url': e.url,
          };
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar com Hero Banner
          _buildSliverAppBar(),

          // Informações do Anime
          SliverToBoxAdapter(child: _buildAnimeInfo()),

          // Toggle View Button
          SliverToBoxAdapter(child: _buildViewToggle()),

          // Episode List
          if (_isLoading)
            SliverToBoxAdapter(child: _buildLoadingState())
          else if (_errorMessage != null)
            SliverToBoxAdapter(child: _buildErrorState())
          else if (_episodes.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            _isGridView ? _buildGridView() : _buildListView(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final hasImage = widget.anime.imageUrl.isNotEmpty;
    final hasBanner = widget.anime.bannerUrl.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        // Batch download button
        if (!_isLoading && _episodes.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            tooltip: 'Batch Download',
            onPressed: _showBatchDownloadDialog,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (hasBanner)
              CachedNetworkImage(
                imageUrl: widget.anime.bannerUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: const Color(0xFF1A1A2E)),
                errorWidget: (context, url, error) =>
                    Container(color: const Color(0xFF1A1A2E)),
              )
            else if (hasImage)
              CachedNetworkImage(
                imageUrl: widget.anime.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: const Color(0xFF1A1A2E)),
                errorWidget: (context, url, error) =>
                    Container(color: const Color(0xFF1A1A2E)),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                ),
              ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.7),
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),

            // Title at bottom
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.anime.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          widget.anime.sourceName,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.anime.aniListData?.averageScore != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (widget.anime.aniListData!.averageScore! / 10)
                                    .toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildAnimeInfo() {
    final anime = widget.anime;
    final hasDescription = anime.description.isNotEmpty;
    final hasGenres = anime.genres.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row
          Row(
            children: [
              _buildStatItem(Icons.tv, '${_episodes.length} eps', Colors.blue),
              const SizedBox(width: 16),
              if (anime.status != null)
                _buildStatItem(Icons.info_outline, anime.status!, Colors.green),
              if (anime.episodeCount != null) ...[
                const SizedBox(width: 16),
                _buildStatItem(
                  Icons.calendar_today,
                  'Total: ${anime.episodeCount}',
                  Colors.purple,
                ),
              ],
            ],
          ),

          // Description
          if (hasDescription) ...[
            const SizedBox(height: 20),
            Text(
              _removeHtmlTags(anime.description),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Genres
          if (hasGenres) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: anime.genres.map((genre) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.getPrimaryGradient(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    genre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Episodes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildViewButton(
                  icon: Icons.view_list,
                  isSelected: !_isGridView,
                  onTap: () => setState(() => _isGridView = false),
                ),
                _buildViewButton(
                  icon: Icons.grid_view,
                  isSelected: _isGridView,
                  onTap: () => setState(() => _isGridView = true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final episode = _episodes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EpisodeListCard(
              episode: episode,
              index: index,
              onTap: () => _openEpisode(episode),
              animeTitle: widget.anime.name,
              animeThumbnail: widget.anime.imageUrl,
            ),
          );
        }, childCount: _episodes.length),
      ),
    );
  }

  Widget _buildGridView() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final episode = _episodes[index];
          return _EpisodeGridCard(
            episode: episode,
            index: index,
            onTap: () => _openEpisode(episode),
            animeTitle: widget.anime.name,
          );
        }, childCount: _episodes.length),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading episodes...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading episodes',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEpisodes,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No episodes found',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// Episode List Card
class _EpisodeListCard extends StatelessWidget {
  final Episode episode;
  final int index;
  final VoidCallback onTap;
  final String animeTitle;
  final String animeThumbnail;

  const _EpisodeListCard({
    required this.episode,
    required this.index,
    required this.onTap,
    required this.animeTitle,
    required this.animeThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A2E).withValues(alpha: 0.8),
              const Color(0xFF16213E).withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            // Episode Number Badge
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: AppColors.getPrimaryGradient(),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryShadow,
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _getEpisodeNumber(episode.number, index),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Episode Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    animeTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getEpisodeLabel(episode.number, index),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Download Button
            DownloadButton(
              animeId: animeTitle,
              animeName: animeTitle,
              episodeNumber: _getEpisodeNumber(episode.number, index),
              episodeTitle: _getEpisodeLabel(episode.number, index),
              videoUrl: episode.url,
              thumbnailUrl: animeThumbnail,
              quality: DownloadQuality.auto,
            ),
            const SizedBox(width: 8),

            // Play Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Episode Grid Card
class _EpisodeGridCard extends StatelessWidget {
  final Episode episode;
  final int index;
  final VoidCallback onTap;
  final String animeTitle;

  const _EpisodeGridCard({
    required this.episode,
    required this.index,
    required this.onTap,
    required this.animeTitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getEpisodeNumber(episode.number, index),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'EP',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Download status badge (top-left)
            Positioned(
              top: 8,
              left: 8,
              child: Consumer<DownloadService>(
                builder: (context, downloadService, _) {
                  final episodeNumber = _getEpisodeNumber(
                    episode.number,
                    index,
                  );
                  final downloadId = '${animeTitle}_$episodeNumber';
                  final download = downloadService.getDownload(downloadId);

                  if (download?.status == DownloadStatus.completed) {
                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.download_done,
                        color: Colors.white,
                        size: 14,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),

            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
