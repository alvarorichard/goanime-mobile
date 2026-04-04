class ContinueWatchingModel {
  final int? id;
  final String animeTitle;
  final String episodeNumber;
  final String episodeUrl;
  final String? imageUrl;
  final String? animeId;
  final String? animeUrl;
  final int progressSeconds;
  final int durationSeconds;
  final DateTime watchedAt;
  final String? source;

  ContinueWatchingModel({
    this.id,
    required this.animeTitle,
    required this.episodeNumber,
    required this.episodeUrl,
    this.imageUrl,
    this.animeId,
    this.animeUrl,
    required this.progressSeconds,
    required this.durationSeconds,
    DateTime? watchedAt,
    this.source,
  }) : watchedAt = watchedAt ?? DateTime.now();

  // Calcula porcentagem assistida
  double get progressPercentage {
    if (durationSeconds <= 0) return 0.0;
    return (progressSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  // Retorna tempo formatado (ex: "12:34")
  String get formattedProgress {
    final minutes = progressSeconds ~/ 60;
    final seconds = progressSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Verifica se já assistiu mais de 90%
  bool get isAlmostFinished => progressPercentage >= 0.9;

  // Verifica se é do mesmo episódio
  bool isSameEpisode(ContinueWatchingModel other) {
    return episodeUrl == other.episodeUrl;
  }

  // Converte para Map para salvar no banco
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animeTitle': animeTitle,
      'episodeNumber': episodeNumber,
      'episodeUrl': episodeUrl,
      'imageUrl': imageUrl,
      'animeId': animeId,
      'animeUrl': animeUrl,
      'progressSeconds': progressSeconds,
      'durationSeconds': durationSeconds,
      'watchedAt': watchedAt.toIso8601String(),
      'source': source,
    };
  }

  // Cria objeto do Map
  factory ContinueWatchingModel.fromMap(Map<String, dynamic> map) {
    return ContinueWatchingModel(
      id: map['id'],
      animeTitle: map['animeTitle'],
      episodeNumber: map['episodeNumber'],
      episodeUrl: map['episodeUrl'],
      imageUrl: map['imageUrl'],
      animeId: map['animeId'],
      animeUrl: map['animeUrl'],
      progressSeconds: map['progressSeconds'],
      durationSeconds: map['durationSeconds'],
      watchedAt: DateTime.parse(map['watchedAt']),
      source: map['source'],
    );
  }

  // Cria uma cópia com campos atualizados
  ContinueWatchingModel copyWith({
    int? id,
    String? animeTitle,
    String? episodeNumber,
    String? episodeUrl,
    String? imageUrl,
    String? animeId,
    String? animeUrl,
    int? progressSeconds,
    int? durationSeconds,
    DateTime? watchedAt,
    String? source,
  }) {
    return ContinueWatchingModel(
      id: id ?? this.id,
      animeTitle: animeTitle ?? this.animeTitle,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeUrl: episodeUrl ?? this.episodeUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      animeId: animeId ?? this.animeId,
      animeUrl: animeUrl ?? this.animeUrl,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      watchedAt: watchedAt ?? this.watchedAt,
      source: source ?? this.source,
    );
  }

  @override
  String toString() {
    return 'ContinueWatchingModel($animeTitle - Ep $episodeNumber, $formattedProgress/$formattedDuration)';
  }
}
