// Models for AniSkip API
class SkipTimes {
  final Skip? op; // Opening
  final Skip? ed; // Ending

  SkipTimes({this.op, this.ed});

  factory SkipTimes.empty() {
    return SkipTimes(op: null, ed: null);
  }

  bool get hasSkipTimes => op != null || ed != null;
}

class Skip {
  final double start; // Start time in seconds
  final double end; // End time in seconds

  Skip({required this.start, required this.end});

  factory Skip.fromJson(Map<String, dynamic> json) {
    return Skip(
      start: (json['start'] ?? 0).toDouble(),
      end: (json['end'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'start': start, 'end': end};
  }

  bool isInRange(double currentSeconds) {
    return currentSeconds >= start && currentSeconds <= end;
  }
}

class SkipInterval {
  final double startTime;
  final double endTime;

  SkipInterval({required this.startTime, required this.endTime});

  factory SkipInterval.fromJson(Map<String, dynamic> json) {
    return SkipInterval(
      startTime: (json['startTime'] ?? 0).toDouble(),
      endTime: (json['endTime'] ?? 0).toDouble(),
    );
  }
}

class SkipTimesResult {
  final SkipInterval interval;
  final String type; // 'op' or 'ed'
  final String episodeLength;

  SkipTimesResult({
    required this.interval,
    required this.type,
    required this.episodeLength,
  });

  factory SkipTimesResult.fromJson(Map<String, dynamic> json) {
    return SkipTimesResult(
      interval: SkipInterval.fromJson(json['interval'] ?? {}),
      type: json['skipType'] ?? '',
      episodeLength: json['episodeLength']?.toString() ?? '0',
    );
  }
}

class SkipTimesResponse {
  final bool found;
  final List<SkipTimesResult> results;
  final String message;
  final int statusCode;

  SkipTimesResponse({
    required this.found,
    required this.results,
    required this.message,
    required this.statusCode,
  });

  factory SkipTimesResponse.fromJson(Map<String, dynamic> json) {
    return SkipTimesResponse(
      found: json['found'] ?? false,
      results:
          (json['results'] as List<dynamic>?)
              ?.map((r) => SkipTimesResult.fromJson(r))
              .toList() ??
          [],
      message: json['message'] ?? '',
      statusCode: json['statusCode'] ?? 0,
    );
  }

  SkipTimes toSkipTimes() {
    Skip? op;
    Skip? ed;

    for (final result in results) {
      final start = result.interval.startTime;
      final end = result.interval.endTime;

      if (result.type == 'op') {
        op = Skip(start: start, end: end);
      } else if (result.type == 'ed') {
        ed = Skip(start: start, end: end);
      }
    }

    return SkipTimes(op: op, ed: ed);
  }
}
