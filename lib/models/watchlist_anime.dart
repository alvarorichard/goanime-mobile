class WatchlistAnime {
  final int? id;
  final String animeId;
  final String title;
  final String coverImage;
  final String myAnimeListUrl;
  final DateTime addedAt;

  WatchlistAnime({
    this.id,
    required this.animeId,
    required this.title,
    required this.coverImage,
    required this.myAnimeListUrl,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animeId': animeId,
      'title': title,
      'coverImage': coverImage,
      'myAnimeListUrl': myAnimeListUrl,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory WatchlistAnime.fromMap(Map<String, dynamic> map) {
    return WatchlistAnime(
      id: map['id'] as int?,
      animeId: map['animeId'] as String,
      title: map['title'] as String,
      coverImage: map['coverImage'] as String,
      myAnimeListUrl: map['myAnimeListUrl'] as String? ?? '',
      addedAt: DateTime.parse(map['addedAt'] as String),
    );
  }
}
