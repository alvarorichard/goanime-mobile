import 'package:flutter/material.dart';
import 'package:goanime/l10n/app_localizations.dart';
import 'package:goanime/modules/schedule_calendar/schedule_calendar.dart';
import 'package:goanime/services/locale_service.dart';
import 'package:goanime/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ScheduleCalendarScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const ScheduleCalendarScreen({super.key, this.onBackPressed});

  @override
  State<ScheduleCalendarScreen> createState() => _ScheduleCalendarScreenState();
}

class _ScheduleCalendarScreenState extends State<ScheduleCalendarScreen> {
  late final ScheduleCalendarController _controller;

  @override
  void initState() {
    super.initState();
    final localeService = context.read<LocaleService>();
    _controller = ScheduleCalendarController(localeService: localeService);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.releaseCalendar,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: _backButton(canPop),
      ),
      body: Column(
        children: [
          ScheduleCalendarWidget(controller: _controller),
          const SizedBox(height: 8),
          ScheduleDayHeaderWidget(controller: _controller),
          Expanded(child: _calendarContent()),
        ],
      ),
    );
  }

  Widget _backButton(bool canPop) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      onPressed: () {
        if (canPop) {
          Navigator.pop(context);
        } else if (widget.onBackPressed != null) {
          widget.onBackPressed!();
        }
      },
    );
  }

  Widget _calendarContent() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        if (_controller.isLoadingDay) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (_controller.isOutOfRange) return _OutOfRangeState();
        if (_controller.selectedDayEntries.isEmpty) {
          return _EmptyCalendarState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _controller.selectedDayEntries.length,
          itemBuilder: (context, index) {
            final entry = _controller.selectedDayEntries[index];
            return ScheduleAnimeCard(entry: entry);
          },
        );
      },
    );
  }
}

class _OutOfRangeState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Data fora da temporada atual',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'O calendário mostra apenas animes da temporada atual (±3 meses)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyCalendarState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            l10n.noReleasesToday,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.checkBackLater,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
