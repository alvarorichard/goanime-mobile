class ScheduleEntryModel {
  final int malId;
  final String title;
  final String? imageUrl;
  final String? titleEnglish;
  final DateTime airDate;
  final int episodeNumber;
  final String? synopsis;
  final List<String> genres;
  final double? score;

  ScheduleEntryModel({
    required this.malId,
    required this.title,
    this.imageUrl,
    this.titleEnglish,
    required this.airDate,
    required this.episodeNumber,
    this.synopsis,
    this.genres = const [],
    this.score,
  });

  bool get isToday {
    final now = DateTime.now();
    return airDate.year == now.year &&
        airDate.month == now.month &&
        airDate.day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return airDate.year == tomorrow.year &&
        airDate.month == tomorrow.month &&
        airDate.day == tomorrow.day;
  }

  bool get hasAired => DateTime.now().isAfter(airDate);
  int get dayOfWeek => airDate.weekday;

  String get formattedTime {
    final hour = airDate.hour.toString().padLeft(2, '0');
    final minute = airDate.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get relativeDay {
    if (isToday) return 'Hoje';
    if (isTomorrow) return 'Amanhã';

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

  String get formattedDate {
    final day = airDate.day.toString().padLeft(2, '0');
    final month = airDate.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  factory ScheduleEntryModel.fromJson(Map<String, dynamic> json) {
    final broadcast = json['broadcast'] as Map<String, dynamic>?;
    final airDateString = broadcast?['day'] ?? '';
    final airTime = broadcast?['time'] ?? '';

    DateTime airDate = DateTime.now();
    final dayOfWeek = _parseDayOfWeek(airDateString);
    if (dayOfWeek != null) {
      final now = DateTime.now();
      final daysUntilNext = (dayOfWeek - now.weekday + 7) % 7;
      airDate = now.add(Duration(days: daysUntilNext));
    }

    if (airTime.isNotEmpty) {
      final timeParts = airTime.split(':');
      if (timeParts.length == 2) {
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        airDate = DateTime(
          airDate.year,
          airDate.month,
          airDate.day,
          hour,
          minute,
        );
      }
    }

    return ScheduleEntryModel(
      malId: json['mal_id'] ?? 0,
      title: json['title'] ?? 'Unknown',
      titleEnglish: json['title_english'],
      imageUrl:
          json['images']?['jpg']?['image_url'] ??
          json['images']?['webp']?['image_url'],
      airDate: airDate,
      episodeNumber: 1,
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((g) => g['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toList() ??
          [],
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  static ScheduleEntryModel? fromSeasonNowJson(Map<String, dynamic> json) {
    final broadcast = json['broadcast'] as Map<String, dynamic>?;
    if (broadcast == null ||
        broadcast['day'] == null ||
        broadcast['time'] == null) {
      return null;
    }

    final airDateString = broadcast['day'] as String;
    var airTime = broadcast['time'] as String? ?? '';
    final dayOfWeek = _parseDayOfWeek(airDateString);
    if (dayOfWeek == null) return null;

    final now = DateTime.now();
    final daysUntilNext = (dayOfWeek - now.weekday + 7) % 7;
    var airDate = now.add(Duration(days: daysUntilNext));

    if (airTime.isNotEmpty) {
      final timeParts = airTime.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        airDate = DateTime(
          airDate.year,
          airDate.month,
          airDate.day,
          hour,
          minute,
        );
      }
    }

    int episodeNumber = 1;
    if (json['episodes'] != null) {
      episodeNumber = (json['episodes'] as num?)?.toInt() ?? 1;
    }

    return ScheduleEntryModel(
      malId: json['mal_id'] ?? 0,
      title: json['title'] ?? json['title_english'] ?? 'Unknown',
      titleEnglish: json['title_english'],
      imageUrl:
          json['images']?['webp']?['large_image_url'] ??
          json['images']?['webp']?['image_url'] ??
          json['images']?['jpg']?['large_image_url'] ??
          json['images']?['jpg']?['image_url'],
      airDate: airDate,
      episodeNumber: episodeNumber,
      synopsis: json['synopsis'],
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((g) => g['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toList() ??
          [],
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mal_id': malId,
      'title': title,
      'title_english': titleEnglish,
      'images': {
        'jpg': {'image_url': imageUrl},
      },
      'broadcast': {
        'day': _getDayOfWeekString(dayOfWeek),
        'time': formattedTime,
      },
      'genres': genres.map((g) => {'name': g}).toList(),
      'score': score,
    };
  }

  static int? _parseDayOfWeek(String day) {
    final days = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
      'mondays': 1,
      'tuesdays': 2,
      'wednesdays': 3,
      'thursdays': 4,
      'fridays': 5,
      'saturdays': 6,
      'sundays': 7,
    };

    return days[day.toLowerCase().trim()];
  }

  static String _getDayOfWeekString(int day) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[day - 1];
  }
}
