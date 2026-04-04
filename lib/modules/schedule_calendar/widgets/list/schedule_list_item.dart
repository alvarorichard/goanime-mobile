import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:goanime/modules/schedule_calendar/schedule_calendar.dart';
import 'package:goanime/screens/source_selection_screen.dart';
import 'package:goanime/theme/app_colors.dart';
import 'package:ionicons/ionicons.dart';

class ScheduleListItem extends StatelessWidget {
  final ScheduleEntryModel entry;

  const ScheduleListItem({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigate(context),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            _AnimeImage(imageUrl: entry.imageUrl),
            Expanded(child: _AnimeInfo(entry: entry)),
            const _PlayButton(),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SourceSelectionScreen(
          animeTitle: entry.title,
          imageUrl: entry.imageUrl ?? '',
          myAnimeListUrl: ScheduleUrls.myAnimeListUrl(entry.malId),
        ),
      ),
    );
  }
}

class _AnimeImage extends StatelessWidget {
  final String? imageUrl;

  const _AnimeImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        bottomLeft: Radius.circular(12),
      ),
      child: CachedNetworkImage(
        imageUrl: imageUrl ?? '',
        width: 75,
        height: 100,
        fit: BoxFit.cover,
        memCacheWidth: 150,
        memCacheHeight: 200,
        placeholder: (context, url) => _placeholder(),
        errorWidget: (context, url, error) => _error(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 75,
      height: 100,
      color: AppColors.surface,
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

  Widget _error() {
    return Container(
      width: 75,
      height: 100,
      color: AppColors.surface,
      child: const Icon(Icons.movie, color: Colors.white24, size: 28),
    );
  }
}

class _AnimeInfo extends StatelessWidget {
  final ScheduleEntryModel entry;

  const _AnimeInfo({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TimeAndScore(entry: entry),
          const SizedBox(height: 6),
          _Title(title: entry.title),
          const SizedBox(height: 6),
          if (entry.genres.isNotEmpty) _Genres(genres: entry.genres),
        ],
      ),
    );
  }
}

class _TimeAndScore extends StatelessWidget {
  final ScheduleEntryModel entry;

  const _TimeAndScore({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Ionicons.time,
          size: 12,
          color: AppColors.primary.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 4),
        Text(
          entry.formattedTime,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        if (entry.score != null) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.star,
            size: 10,
            color: Colors.amber.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 2),
          Text(
            entry.score!.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.amber.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String title;

  const _Title({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Genres extends StatelessWidget {
  final List<String> genres;

  const _Genres({required this.genres});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: genres.take(2).map((genre) {
          return Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              genre,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Ionicons.play, color: AppColors.primary, size: 18),
      ),
    );
  }
}
