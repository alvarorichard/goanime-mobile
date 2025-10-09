import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/download_service.dart';
import '../theme/app_colors.dart';

/// Download button widget - shows download status and allows interaction
class DownloadButton extends StatelessWidget {
  final String animeId;
  final String animeName;
  final String episodeNumber;
  final String episodeTitle;
  final String videoUrl;
  final String thumbnailUrl;
  final DownloadQuality quality;

  const DownloadButton({
    super.key,
    required this.animeId,
    required this.animeName,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.quality = DownloadQuality.auto,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, _) {
        final downloadId = '${animeId}_$episodeNumber';
        final download = downloadService.getDownload(downloadId);

        if (download == null) {
          // Not downloaded - show download button
          return IconButton(
            icon: const Icon(Icons.download, color: AppColors.textSecondary),
            onPressed: () => _startDownload(context, downloadService),
          );
        }

        // Show status based on download state
        switch (download.status) {
          case DownloadStatus.downloading:
            return Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: download.progress,
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.pause,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  onPressed: () => downloadService.pauseDownload(downloadId),
                ),
              ],
            );

          case DownloadStatus.paused:
            return IconButton(
              icon: const Icon(Icons.play_arrow, color: AppColors.accent),
              onPressed: () => downloadService.resumeDownload(downloadId),
            );

          case DownloadStatus.queued:
            return const IconButton(
              icon: Icon(Icons.schedule, color: AppColors.textSecondary),
              onPressed: null,
            );

          case DownloadStatus.completed:
            return IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () =>
                  _showDownloadOptions(context, downloadService, downloadId),
            );

          case DownloadStatus.failed:
            return IconButton(
              icon: const Icon(Icons.error, color: Colors.red),
              onPressed: () => downloadService.retryDownload(downloadId),
            );

          case DownloadStatus.cancelled:
            return IconButton(
              icon: const Icon(Icons.download, color: AppColors.textSecondary),
              onPressed: () => _startDownload(context, downloadService),
            );
        }
      },
    );
  }

  Future<void> _startDownload(
    BuildContext context,
    DownloadService downloadService,
  ) async {
    try {
      await downloadService.addDownload(
        animeId: animeId,
        animeName: animeName,
        episodeNumber: episodeNumber,
        episodeTitle: episodeTitle,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        quality: quality,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added Episode $episodeNumber to downloads'),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showDownloadOptions(
    BuildContext context,
    DownloadService downloadService,
    String downloadId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Download Options',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Download',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                downloadService.deleteDownload(downloadId);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Batch download dialog - allows downloading multiple episodes
class BatchDownloadDialog extends StatefulWidget {
  final String animeId;
  final String animeName;
  final String thumbnailUrl;
  final List<Map<String, String>> episodes;

  const BatchDownloadDialog({
    super.key,
    required this.animeId,
    required this.animeName,
    required this.thumbnailUrl,
    required this.episodes,
  });

  @override
  State<BatchDownloadDialog> createState() => _BatchDownloadDialogState();
}

class _BatchDownloadDialogState extends State<BatchDownloadDialog> {
  final Set<int> _selectedEpisodes = {};
  DownloadQuality _selectedQuality = DownloadQuality.auto;
  bool _selectAll = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.background, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Batch Download',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.animeName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Quality selector
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Quality:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SegmentedButton<DownloadQuality>(
                      segments: const [
                        ButtonSegment(
                          value: DownloadQuality.auto,
                          label: Text('Auto'),
                        ),
                        ButtonSegment(
                          value: DownloadQuality.low,
                          label: Text('480p'),
                        ),
                        ButtonSegment(
                          value: DownloadQuality.medium,
                          label: Text('720p'),
                        ),
                        ButtonSegment(
                          value: DownloadQuality.high,
                          label: Text('1080p'),
                        ),
                      ],
                      selected: {_selectedQuality},
                      onSelectionChanged: (Set<DownloadQuality> selected) {
                        setState(() => _selectedQuality = selected.first);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Select all checkbox
            CheckboxListTile(
              title: const Text(
                'Select All',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              value: _selectAll,
              onChanged: (value) {
                setState(() {
                  _selectAll = value ?? false;
                  if (_selectAll) {
                    _selectedEpisodes.clear();
                    _selectedEpisodes.addAll(
                      List.generate(widget.episodes.length, (i) => i),
                    );
                  } else {
                    _selectedEpisodes.clear();
                  }
                });
              },
            ),

            const Divider(color: AppColors.background),

            // Episodes list
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.episodes.length,
                itemBuilder: (context, index) {
                  final episode = widget.episodes[index];
                  final isSelected = _selectedEpisodes.contains(index);

                  return CheckboxListTile(
                    title: Text(
                      'Episode ${episode['number']}',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: episode['title'] != null
                        ? Text(
                            episode['title']!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedEpisodes.add(index);
                        } else {
                          _selectedEpisodes.remove(index);
                        }
                        _selectAll =
                            _selectedEpisodes.length == widget.episodes.length;
                      });
                    },
                  );
                },
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.background, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedEpisodes.isEmpty
                        ? null
                        : () => _startBatchDownload(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    child: Text(
                      'Download ${_selectedEpisodes.length} Episodes',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startBatchDownload(BuildContext context) async {
    final downloadService = context.read<DownloadService>();
    final selectedEpisodesList = _selectedEpisodes
        .map((index) => widget.episodes[index])
        .toList();

    try {
      final downloadIds = await downloadService.addBatchDownloads(
        animeId: widget.animeId,
        animeName: widget.animeName,
        episodes: selectedEpisodesList,
        thumbnailUrl: widget.thumbnailUrl,
        quality: _selectedQuality,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${downloadIds.length} episodes to downloads'),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
