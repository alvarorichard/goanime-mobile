import 'package:flutter/material.dart';
import 'package:goanime/modules/schedule_calendar/schedule_calendar.dart';
import 'package:goanime/screens/source_selection_screen.dart';
import 'package:goanime/theme/app_colors.dart';

class ScheduleListScreen extends StatefulWidget {
  final int weekday;
  final String dayName;
  final List<ScheduleEntryModel> initialEntries;

  const ScheduleListScreen({
    super.key,
    required this.weekday,
    required this.dayName,
    required this.initialEntries,
  });

  @override
  State<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  late List<ScheduleEntryModel> _entries;
  bool _isLoadingMore = false;
  bool _hasMoreToLoad = true;

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.initialEntries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_entries.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.dayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        leading: _backButton(),
      ),
      body: _entries.isEmpty ? _emptyState() : _animeList(),
    );
  }

  Widget _backButton() {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum anime para este dia',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _animeList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification.metrics.pixels >=
                scrollNotification.metrics.maxScrollExtent - 200 &&
            !_isLoadingMore &&
            _hasMoreToLoad) {
          _loadMoreEntries();
        }
        return true;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == _entries.length) return const _LoadingMore();
          final entry = _entries[index];
          return GestureDetector(
            onTap: () => _openSource(entry),
            child: ScheduleListItem(entry: entry),
          );
        },
      ),
    );
  }

  Future<void> _loadMoreEntries() async {
    if (_isLoadingMore || !_hasMoreToLoad) return;
    setState(() => _isLoadingMore = true);

    try {
      debugPrint(
        '[ScheduleList] 🔍 Buscando mais animes para weekday ${widget.weekday}...',
      );
      final allSeasonEntries = await _scheduleService.getSeasonSchedule();

      final uniqueEntries = <int, ScheduleEntryModel>{};
      for (final entry in allSeasonEntries) {
        if (entry.dayOfWeek == widget.weekday) {
          uniqueEntries[entry.malId] = entry;
        }
      }

      final newEntries = uniqueEntries.values.toList();
      newEntries.sort((a, b) => a.airDate.compareTo(b.airDate));

      int addedCount = 0;
      for (var entry in newEntries) {
        if (!_entries.any((e) => e.malId == entry.malId)) {
          _entries.add(entry);
          addedCount++;
        }
      }

      debugPrint(
        '[ScheduleList] ✅ Adicionados $addedCount novos animes (total: ${_entries.length})',
      );

      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMoreToLoad = false;
        });
      }
    } catch (e) {
      debugPrint('[ScheduleList] ❌ Erro ao carregar mais: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _openSource(ScheduleEntryModel entry) {
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

class _LoadingMore extends StatelessWidget {
  const _LoadingMore();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              'Carregando mais animes...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
