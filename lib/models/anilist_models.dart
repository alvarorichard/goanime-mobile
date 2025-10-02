// AniList API Models

class AniListResponse {
  final MediaData data;

  AniListResponse({required this.data});

  factory AniListResponse.fromJson(Map<String, dynamic> json) {
    return AniListResponse(
      data: MediaData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class MediaData {
  final MediaDetails media;

  MediaData({required this.media});

  factory MediaData.fromJson(Map<String, dynamic> json) {
    return MediaData(
      media: MediaDetails.fromJson(json['Media'] as Map<String, dynamic>),
    );
  }
}

class MediaDetails {
  final int id;
  final int? idMal;
  final MediaTitle title;
  final CoverImage coverImage;
  final String? bannerImage;
  final String? description;
  final int? episodes;
  final String? status;
  final String? season;
  final int? seasonYear;
  final double? averageScore;
  final int? popularity;
  final List<String> genres;
  final MediaFormat? format;

  MediaDetails({
    required this.id,
    this.idMal,
    required this.title,
    required this.coverImage,
    this.bannerImage,
    this.description,
    this.episodes,
    this.status,
    this.season,
    this.seasonYear,
    this.averageScore,
    this.popularity,
    this.genres = const [],
    this.format,
  });

  factory MediaDetails.fromJson(Map<String, dynamic> json) {
    return MediaDetails(
      id: json['id'] as int,
      idMal: json['idMal'] as int?,
      title: MediaTitle.fromJson(json['title'] as Map<String, dynamic>),
      coverImage: CoverImage.fromJson(json['coverImage'] as Map<String, dynamic>),
      bannerImage: json['bannerImage'] as String?,
      description: json['description'] as String?,
      episodes: json['episodes'] as int?,
      status: json['status'] as String?,
      season: json['season'] as String?,
      seasonYear: json['seasonYear'] as int?,
      averageScore: (json['averageScore'] as num?)?.toDouble(),
      popularity: json['popularity'] as int?,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      format: json['format'] != null 
          ? MediaFormat.fromString(json['format'] as String)
          : null,
    );
  }
}

class MediaTitle {
  final String? romaji;
  final String? english;
  final String? native;

  MediaTitle({
    this.romaji,
    this.english,
    this.native,
  });

  factory MediaTitle.fromJson(Map<String, dynamic> json) {
    return MediaTitle(
      romaji: json['romaji'] as String?,
      english: json['english'] as String?,
      native: json['native'] as String?,
    );
  }

  String get preferred => english ?? romaji ?? native ?? 'Unknown';
}

class CoverImage {
  final String? extraLarge;
  final String? large;
  final String? medium;
  final String? color;

  CoverImage({
    this.extraLarge,
    this.large,
    this.medium,
    this.color,
  });

  factory CoverImage.fromJson(Map<String, dynamic> json) {
    return CoverImage(
      extraLarge: json['extraLarge'] as String?,
      large: json['large'] as String?,
      medium: json['medium'] as String?,
      color: json['color'] as String?,
    );
  }

  String get best => extraLarge ?? large ?? medium ?? '';
}

enum MediaFormat {
  tv,
  tvShort,
  movie,
  special,
  ova,
  ona,
  music,
  manga,
  novel,
  oneShot,
  unknown;

  static MediaFormat fromString(String value) {
    switch (value.toUpperCase()) {
      case 'TV':
        return MediaFormat.tv;
      case 'TV_SHORT':
        return MediaFormat.tvShort;
      case 'MOVIE':
        return MediaFormat.movie;
      case 'SPECIAL':
        return MediaFormat.special;
      case 'OVA':
        return MediaFormat.ova;
      case 'ONA':
        return MediaFormat.ona;
      case 'MUSIC':
        return MediaFormat.music;
      case 'MANGA':
        return MediaFormat.manga;
      case 'NOVEL':
        return MediaFormat.novel;
      case 'ONE_SHOT':
        return MediaFormat.oneShot;
      default:
        return MediaFormat.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case MediaFormat.tv:
        return 'TV';
      case MediaFormat.tvShort:
        return 'TV Short';
      case MediaFormat.movie:
        return 'Movie';
      case MediaFormat.special:
        return 'Special';
      case MediaFormat.ova:
        return 'OVA';
      case MediaFormat.ona:
        return 'ONA';
      case MediaFormat.music:
        return 'Music';
      case MediaFormat.manga:
        return 'Manga';
      case MediaFormat.novel:
        return 'Novel';
      case MediaFormat.oneShot:
        return 'One Shot';
      case MediaFormat.unknown:
        return 'Unknown';
    }
  }
}

// Extended Anime model to include AniList data
class EnrichedAnime {
  final String name;
  final String url;
  final MediaDetails? aniListData;

  EnrichedAnime({
    required this.name,
    required this.url,
    this.aniListData,
  });

  String get imageUrl => aniListData?.coverImage.best ?? '';
  String get bannerUrl => aniListData?.bannerImage ?? '';
  String get description => aniListData?.description ?? '';
  int? get malId => aniListData?.idMal;
  int? get anilistId => aniListData?.id;
}
