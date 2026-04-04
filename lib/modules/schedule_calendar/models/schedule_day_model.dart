class ScheduleDayModel {
  final int dayOfWeek;
  final List entries;

  ScheduleDayModel({required this.dayOfWeek, required this.entries});

  String get dayName {
    const days = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];
    return days[dayOfWeek - 1];
  }

  String get dayNameEn {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[dayOfWeek - 1];
  }

  bool get isToday => dayOfWeek == DateTime.now().weekday;
}
