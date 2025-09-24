import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

// Logo Widget Helper
class LogoWidget extends StatelessWidget {
  final double size;
  final Color? color;

  const LogoWidget({super.key, this.size = 80, this.color});

  @override
  Widget build(BuildContext context) {
    // Try to load the custom logo, fallback to icon
    return Container(
      height: size,
      child: Image.asset(
        'assets/images/logo goanime.png',
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to icon if image fails to load or doesn't exist
          return Icon(
            Icons.play_circle_filled,
            size: size,
            color: color ?? Colors.white70,
            shadows: const [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Colors.black26,
              ),
            ],
          );
        },
      ),
    );
  }
}

// Theme Provider
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true; // Dark theme by default

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

// Models
class Episode {
  final String number;
  final String url;

  Episode({required this.number, required this.url});

  @override
  String toString() => number;
}

class Anime {
  final String name;
  final String url;

  Anime({required this.name, required this.url});

  @override
  String toString() => name;
}

class VideoData {
  final String src;
  final String label;

  VideoData({required this.src, required this.label});

  factory VideoData.fromJson(Map<String, dynamic> json) {
    return VideoData(src: json['src'] ?? '', label: json['label'] ?? '');
  }
}

class VideoResponse {
  final List<VideoData> data;
  final Map<String, dynamic> resposta;

  VideoResponse({required this.data, required this.resposta});

  factory VideoResponse.fromJson(Map<String, dynamic> json) {
    var dataList = json['data'] as List? ?? [];
    List<VideoData> videoDataList = dataList
        .map((item) => VideoData.fromJson(item))
        .toList();

    return VideoResponse(data: videoDataList, resposta: json['resposta'] ?? {});
  }
}

// Database Helper
class DatabaseHelper {
  static Database? _database;
  static const String dbName = 'anime.db';
  static const String animeTable = 'anime';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), dbName);
    return await openDatabase(path, version: 1, onCreate: _createDb);
  }

  static Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $animeTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');
  }

  static Future<void> addAnimeNames(List<String> animeNames) async {
    final db = await database;
    for (String name in animeNames) {
      await db.insert(animeTable, {'name': name});
    }
  }

  static Future<List<String>> getAnimeNames() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(animeTable);
    return List.generate(maps.length, (i) => maps[i]['name']);
  }
}

// API Service
class AnimeService {
  static const String baseSiteUrl = 'https://animefire.plus';

  static Future<List<Anime>> searchAnime(String animeName) async {
    final String searchUrl =
        '$baseSiteUrl/pesquisar/${_treatAnimeName(animeName)}';

    try {
      final response = await http.get(Uri.parse(searchUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to search anime: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);
      final animeElements = document.querySelectorAll('.row.ml-1.mr-1 a');

      List<Anime> animes = [];
      for (var element in animeElements) {
        final name = element.text.trim();
        final url = element.attributes['href'] ?? '';
        if (name.isNotEmpty && url.isNotEmpty) {
          animes.add(Anime(name: name, url: url));
        }
      }

      return animes;
    } catch (e) {
      throw Exception('Error searching anime: $e');
    }
  }

  static Future<List<Episode>> getAnimeEpisodes(String animeUrl) async {
    try {
      final response = await http.get(Uri.parse(animeUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to get episodes: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);
      final episodeElements = document.querySelectorAll(
        'a.lEp.epT.divNumEp.smallbox.px-2.mx-1.text-left.d-flex',
      );

      List<Episode> episodes = [];
      for (var element in episodeElements) {
        final number = element.text.trim();
        final url = element.attributes['href'] ?? '';
        if (number.isNotEmpty && url.isNotEmpty) {
          episodes.add(Episode(number: number, url: url));
        }
      }

      return episodes;
    } catch (e) {
      throw Exception('Error getting episodes: $e');
    }
  }

  static Future<String> extractVideoURL(String episodeUrl) async {
    try {
      final response = await http.get(Uri.parse(episodeUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to get video page: ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);

      // Try to find video element with data-video-src
      var videoElement = document.querySelector('video[data-video-src]');
      if (videoElement != null) {
        return videoElement.attributes['data-video-src'] ?? '';
      }

      // Try to find div with data-video-src
      var divElement = document.querySelector('div[data-video-src]');
      if (divElement != null) {
        return divElement.attributes['data-video-src'] ?? '';
      }

      throw Exception('Video source not found');
    } catch (e) {
      throw Exception('Error extracting video URL: $e');
    }
  }

  static Future<String> extractActualVideoURL(String videoSrc) async {
    try {
      final response = await http.get(Uri.parse(videoSrc));
      if (response.statusCode != 200) {
        throw Exception('Failed to get video data: ${response.statusCode}');
      }

      final jsonData = json.decode(response.body);
      final videoResponse = VideoResponse.fromJson(jsonData);

      if (videoResponse.data.isEmpty) {
        throw Exception('No video data found');
      }

      return videoResponse.data[0].src;
    } catch (e) {
      throw Exception('Error extracting actual video URL: $e');
    }
  }

  static String _treatAnimeName(String animeName) {
    return animeName.toLowerCase().replaceAll(' ', '-');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'GoAnime',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
          themeMode: _themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: AnimeSearchScreen(themeProvider: _themeProvider),
        );
      },
    );
  }
}

// Search Screen
class AnimeSearchScreen extends StatefulWidget {
  final ThemeProvider themeProvider;

  const AnimeSearchScreen({super.key, required this.themeProvider});

  @override
  State<AnimeSearchScreen> createState() => _AnimeSearchScreenState();
}

class _AnimeSearchScreenState extends State<AnimeSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Anime> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _searchAnime() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await AnimeService.searchAnime(
        _searchController.text.trim(),
      );
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });

      // Add anime names to database
      final animeNames = results.map((anime) => anime.name).toList();
      await DatabaseHelper.addAnimeNames(animeNames);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 60),
              title: const Text(
                'GoAnime',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3.0,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF04c6c5), const Color(0xFF03a5a4)],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  widget.themeProvider.isDarkMode
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: () {
                  widget.themeProvider.toggleTheme();
                  HapticFeedback.lightImpact();
                },
                tooltip: widget.themeProvider.isDarkMode
                    ? 'Tema claro'
                    : 'Tema escuro',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Search Section
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Digite o nome do anime',
                        hintText: 'Ex: Naruto, One Piece, Attack on Titan...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.send_rounded),
                                onPressed: _isLoading ? null : _searchAnime,
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      onSubmitted: (_) => _searchAnime(),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Results Section
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Erro: $_errorMessage',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _searchAnime,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  else if (_searchResults.isEmpty && !_isLoading)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.movie_rounded, size: 80),
                          const SizedBox(height: 24),
                          const Text(
                            'Encontre seu anime favorito',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Digite o nome do anime no campo acima para começar sua busca',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  else if (_searchResults.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            '${_searchResults.length} resultado${_searchResults.length != 1 ? 's' : ''} encontrado${_searchResults.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final anime = _searchResults[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(anime.name),
                                subtitle: const Text(
                                  'Toque para ver episódios',
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EpisodeListScreen(anime: anime),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Episode List Screen
class EpisodeListScreen extends StatefulWidget {
  final Anime anime;

  const EpisodeListScreen({super.key, required this.anime});

  @override
  State<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends State<EpisodeListScreen> {
  List<Episode> _episodes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final episodes = await AnimeService.getAnimeEpisodes(widget.anime.url);
      setState(() {
        _episodes = episodes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.anime.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3.0,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.tv_rounded,
                    size: 60,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(50.0),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Carregando episódios...'),
                        ],
                      ),
                    ),
                  )
                : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade400,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Erro ao carregar episódios',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _loadEpisodes,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar novamente'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _episodes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(50.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.tv_off, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Nenhum episódio encontrado',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_episodes.length} episódio${_episodes.length != 1 ? 's' : ''} disponível${_episodes.length != 1 ? 'eis' : ''}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
          ),
          if (_episodes.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final episode = _episodes[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      VideoPlayerScreen(
                                        episode: episode,
                                        animeTitle: widget.anime.name,
                                      ),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    return SlideTransition(
                                      position: animation.drive(
                                        Tween(
                                          begin: const Offset(1.0, 0.0),
                                          end: Offset.zero,
                                        ),
                                      ),
                                      child: child,
                                    );
                                  },
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Episódio ${episode.number}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Toque para assistir',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.6),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }, childCount: _episodes.length),
              ),
            ),
        ],
      ),
    );
  }
}

// Video Player Screen
class VideoPlayerScreen extends StatefulWidget {
  final Episode episode;
  final String animeTitle;

  const VideoPlayerScreen({
    super.key,
    required this.episode,
    required this.animeTitle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentVideoUrl;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Cleanup previous controllers
      await _cleanupControllers();

      // Extract video URL from episode page
      final videoSrc = await AnimeService.extractVideoURL(widget.episode.url);
      if (videoSrc.isEmpty) {
        throw Exception('URL do vídeo não encontrada na página');
      }

      // Extract actual video URL from API
      final actualVideoUrl = await AnimeService.extractActualVideoURL(videoSrc);
      if (actualVideoUrl.isEmpty) {
        throw Exception('URL do vídeo não pôde ser extraída da API');
      }

      _currentVideoUrl = actualVideoUrl;

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(actualVideoUrl),
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36',
          'Referer': 'https://animefire.plus/',
        },
      );

      // Add error listener
      _videoPlayerController!.addListener(_videoPlayerListener);

      await _videoPlayerController!.initialize();

      if (!mounted) return;

      // Check if initialization was successful
      if (_videoPlayerController!.value.hasError) {
        throw Exception(
          'Erro ao inicializar: ${_videoPlayerController!.value.errorDescription}',
        );
      }

      // Create Chewie controller with safe values
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        aspectRatio: _calculateAspectRatio(),
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget('Erro do player: $errorMessage');
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _videoPlayerListener() {
    if (_videoPlayerController?.value.hasError == true) {
      final error = _videoPlayerController!.value.errorDescription;
      debugPrint('Video player error: $error');
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro no player: $error';
          _isLoading = false;
        });
      }
    }
  }

  double _calculateAspectRatio() {
    if (_videoPlayerController?.value.isInitialized == true) {
      final size = _videoPlayerController!.value.size;
      if (size.width > 0 && size.height > 0) {
        return size.width / size.height;
      }
    }
    return 16 / 9; // fallback
  }

  Future<void> _cleanupControllers() async {
    _videoPlayerController?.removeListener(_videoPlayerListener);
    await _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
  }

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade400,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ops! Algo deu errado',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializeVideoPlayer,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cleanupControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${widget.animeTitle} - Ep ${widget.episode.number}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3.0,
                color: Colors.black26,
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _initializeVideoPlayer,
              tooltip: 'Recarregar',
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).shadowColor.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Carregando vídeo...',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Extraindo URL do vídeo...',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
              ? Center(child: _buildErrorWidget(_errorMessage!))
              : _chewieController != null &&
                    _videoPlayerController?.value.isInitialized == true
              ? Column(
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).shadowColor.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Chewie(controller: _chewieController!),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).shadowColor.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.play_circle_filled,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.animeTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Episódio ${widget.episode.number}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_currentVideoUrl != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.source,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Fonte: ${Uri.parse(_currentVideoUrl!).host}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                )
              : Center(
                  child: _buildErrorWidget('Falha ao inicializar o player'),
                ),
        ),
      ),
    );
  }
}
