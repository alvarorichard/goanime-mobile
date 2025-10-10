// Modelos para Jikan API (MyAnimeList)
class JikanAnime {
  final int malId;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final String imageUrl;
  final String? largImageUrl;
  final String? synopsis;
  final double? score;
  final int? episodes;
  final String? status;
  final String? rating;
  final List<JikanGenre> genres;
  final int? year;
  final String? season;

  JikanAnime({
    required this.malId,
    required this.title,
    this.titleEnglish,
    this.titleJapanese,
    required this.imageUrl,
    this.largImageUrl,
    this.synopsis,
    this.score,
    this.episodes,
    this.status,
    this.rating,
    this.genres = const [],
    this.year,
    this.season,
  });

  factory JikanAnime.fromJson(Map<String, dynamic> json) {
    // Priorizar WebP para melhor qualidade e compressão
    final webpLarge = json['images']?['webp']?['large_image_url'];
    final jpgLarge = json['images']?['jpg']?['large_image_url'];
    final webpNormal = json['images']?['webp']?['image_url'];
    final jpgNormal = json['images']?['jpg']?['image_url'];

    // Debug: mostrar qual URL está sendo usada
    final selectedUrl = webpLarge ?? jpgLarge ?? webpNormal ?? jpgNormal;
    if (selectedUrl != null && selectedUrl.isNotEmpty) {
      print('[IMAGE DEBUG] ${json['title']}: $selectedUrl');
    }

    return JikanAnime(
      malId: json['mal_id'] ?? 0,
      title: json['title'] ?? 'Unknown',
      titleEnglish: json['title_english'],
      titleJapanese: json['title_japanese'],
      imageUrl: webpNormal ?? jpgNormal ?? '',
      largImageUrl: webpLarge ?? jpgLarge ?? webpNormal ?? jpgNormal,
      synopsis: json['synopsis'],
      score: json['score']?.toDouble(),
      episodes: json['episodes'],
      status: json['status'],
      rating: json['rating'],
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((g) => JikanGenre.fromJson(g))
              .toList() ??
          [],
      year: json['year'],
      season: json['season'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mal_id': malId,
      'title': title,
      'title_english': titleEnglish,
      'title_japanese': titleJapanese,
      'images': {
        'jpg': {'image_url': imageUrl, 'large_image_url': largImageUrl},
      },
      'synopsis': synopsis,
      'score': score,
      'episodes': episodes,
      'status': status,
      'rating': rating,
      'genres': genres.map((g) => g.toJson()).toList(),
      'year': year,
      'season': season,
    };
  }
}

class JikanGenre {
  final int malId;
  final String name;
  final String type;

  JikanGenre({required this.malId, required this.name, required this.type});

  factory JikanGenre.fromJson(Map<String, dynamic> json) {
    return JikanGenre(
      malId: json['mal_id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      type: json['type'] ?? 'anime',
    );
  }

  Map<String, dynamic> toJson() {
    return {'mal_id': malId, 'name': name, 'type': type};
  }
}

class JikanResponse<T> {
  final List<T> data;
  final JikanPagination? pagination;

  JikanResponse({required this.data, this.pagination});

  factory JikanResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return JikanResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => fromJsonT(item as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: json['pagination'] != null
          ? JikanPagination.fromJson(json['pagination'])
          : null,
    );
  }
}

class JikanPagination {
  final int lastVisiblePage;
  final bool hasNextPage;
  final int currentPage;

  JikanPagination({
    required this.lastVisiblePage,
    required this.hasNextPage,
    required this.currentPage,
  });

  factory JikanPagination.fromJson(Map<String, dynamic> json) {
    return JikanPagination(
      lastVisiblePage: json['last_visible_page'] ?? 1,
      hasNextPage: json['has_next_page'] ?? false,
      currentPage: json['current_page'] ?? 1,
    );
  }
}
