import 'package:flutter/material.dart';
import 'package:goanime/modules/schedule_calendar/schedule_calendar.dart';
import 'package:goanime/services/locale_service.dart';
import 'package:goanime/theme/app_colors.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

class ScheduleDayHeaderWidget extends StatelessWidget {
  final ScheduleCalendarController controller;

  const ScheduleDayHeaderWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Garante que o widget reconstrua quando o idioma mudar
    context.watch<LocaleService>();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.hasSelectedDay) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(child: _buildDayInfo()),
              if (controller.selectedDayEntries.isNotEmpty)
                _buildViewMoreButton(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Ionicons.calendar, color: AppColors.primary, size: 20),
    );
  }

  Widget _buildDayInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          controller.selectedDayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          controller.selectedDayFormatted,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildViewMoreButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToList(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ver ${controller.selectedDayEntries.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  void _navigateToList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleListScreen(
          weekday: controller.selectedDay!.weekday,
          dayName: controller.selectedDayName,
          initialEntries: controller.selectedDayEntries,
        ),
      ),
    );
  }
}
