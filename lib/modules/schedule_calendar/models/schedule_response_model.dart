import 'schedule_day_model.dart';
import 'schedule_entry_model.dart';

class ScheduleResponseModel {
  final List<ScheduleEntryModel> entries;
  final bool hasNextPage;
  final int currentPage;

  ScheduleResponseModel({
    required this.entries,
    this.hasNextPage = false,
    this.currentPage = 1,
  });

  List<ScheduleDayModel> get groupedByDay {
    final Map<int, List<ScheduleEntryModel>> map = {};
    for (final entry in entries) {
      final day = entry.dayOfWeek;
      map.putIfAbsent(day, () => []);
      map[day]!.add(entry);
    }
    final days = map.keys.toList()..sort();
    return days
        .map((day) => ScheduleDayModel(dayOfWeek: day, entries: map[day]!))
        .toList();
  }
}
