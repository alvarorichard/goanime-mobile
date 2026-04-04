import 'package:flutter/material.dart';
import 'package:goanime/modules/schedule_calendar/schedule_calendar.dart';
import 'package:goanime/services/locale_service.dart';
import 'package:goanime/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleCalendarWidget extends StatelessWidget {
  final ScheduleCalendarController controller;

  const ScheduleCalendarWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Ouve mudanças de idioma para atualizar o calendário
    final isPortuguese = context.watch<LocaleService>().isPortuguese;
    final locale = isPortuguese ? 'pt_BR' : 'en_US';

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => TableCalendar(
          locale: locale, // Define o idioma explicitamente
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: controller.focusedMonth,
          selectedDayPredicate: (day) => _isSameDay(day),
          onDaySelected: controller.onDaySelected,
          onPageChanged: controller.onPageChanged,
          calendarStyle: _calendarStyle,
          headerStyle: _headerStyle,
          daysOfWeekStyle: _daysOfWeekStyle,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime day) {
    return controller.selectedDay != null &&
        day.year == controller.selectedDay!.year &&
        day.month == controller.selectedDay!.month &&
        day.day == controller.selectedDay!.day;
  }

  CalendarStyle get _calendarStyle => CalendarStyle(
    selectedDecoration: const BoxDecoration(
      color: AppColors.primary,
      shape: BoxShape.circle,
    ),
    todayDecoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.3),
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.primary, width: 2),
    ),
    defaultTextStyle: const TextStyle(color: Colors.white),
    todayTextStyle: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    selectedTextStyle: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    outsideTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
    weekendTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
  );

  HeaderStyle get _headerStyle => HeaderStyle(
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
    leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
    rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
    titleCentered: true,
    formatButtonVisible: false,
  );

  DaysOfWeekStyle get _daysOfWeekStyle => DaysOfWeekStyle(
    weekdayStyle: TextStyle(
      color: Colors.white.withValues(alpha: 0.6),
      fontWeight: FontWeight.bold,
    ),
    weekendStyle: TextStyle(
      color: Colors.white.withValues(alpha: 0.8),
      fontWeight: FontWeight.bold,
    ),
  );
}
