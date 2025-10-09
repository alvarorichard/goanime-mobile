import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../main.dart' show AnimeService;

/// Download status enum
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Download quality enum
enum DownloadQuality {
  auto,
  low, // 480p
  medium, // 720p
  high, // 1080p
}

/// Download item model
class DownloadItem {
  final String id;
  final String animeId;
  final String animeName;
  final String episodeNumber;
  final String episodeTitle;
  final String videoUrl;
  final String thumbnailUrl;
  final DownloadQuality quality;
  DownloadStatus status;
  double progress;
  int bytesDownloaded;
  int totalBytes;
  String? filePath;
  String? error;
  DateTime createdAt;
  DateTime? completedAt;

  DownloadItem({
    required this.id,
    required this.animeId,
    required this.animeName,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.quality = DownloadQuality.auto,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.filePath,
    this.error,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animeId': animeId,
      'animeName': animeName,
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'quality': quality.index,
      'status': status.index,
      'progress': progress,
      'bytesDownloaded': bytesDownloaded,
      'totalBytes': totalBytes,
      'filePath': filePath,
      'error': error,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory DownloadItem.fromMap(Map<String, dynamic> map) {
    return DownloadItem(
      id: map['id'],
      animeId: map['animeId'],
      animeName: map['animeName'],
      episodeNumber: map['episodeNumber'],
      episodeTitle: map['episodeTitle'],
      videoUrl: map['videoUrl'],
      thumbnailUrl: map['thumbnailUrl'],
      quality: DownloadQuality.values[map['quality']],
      status: DownloadStatus.values[map['status']],
      progress: map['progress'],
      bytesDownloaded: map['bytesDownloaded'],
      totalBytes: map['totalBytes'],
      filePath: map['filePath'],
      error: map['error'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
    );
  }

  DownloadItem copyWith({
    DownloadStatus? status,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    String? filePath,
    String? error,
    DateTime? completedAt,
  }) {
    return DownloadItem(
      id: id,
      animeId: animeId,
      animeName: animeName,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      quality: quality,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Download service - manages all download operations
class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  Database? _database;
  final Map<String, DownloadItem> _downloads = {};
  final Map<String, StreamSubscription> _activeDownloads = {};
  final Map<String, http.Client> _downloadClients = {};
  int _maxConcurrentDownloads = 3;
  int _activeDownloadCount = 0;

  List<DownloadItem> get downloads => _downloads.values.toList();
  List<DownloadItem> get activeDownloads => _downloads.values
      .where(
        (d) =>
            d.status == DownloadStatus.downloading ||
            d.status == DownloadStatus.queued,
      )
      .toList();
  List<DownloadItem> get completedDownloads => _downloads.values
      .where((d) => d.status == DownloadStatus.completed)
      .toList();

  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  set maxConcurrentDownloads(int value) {
    _maxConcurrentDownloads = value.clamp(1, 5);
    notifyListeners();
  }

  /// Initialize the download service
  Future<void> initialize() async {
    _database = await _initDatabase();
    await _loadDownloads();
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDirectory.path, 'downloads.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            animeId TEXT NOT NULL,
            animeName TEXT NOT NULL,
            episodeNumber TEXT NOT NULL,
            episodeTitle TEXT NOT NULL,
            videoUrl TEXT NOT NULL,
            thumbnailUrl TEXT NOT NULL,
            quality INTEGER NOT NULL,
            status INTEGER NOT NULL,
            progress REAL NOT NULL,
            bytesDownloaded INTEGER NOT NULL,
            totalBytes INTEGER NOT NULL,
            filePath TEXT,
            error TEXT,
            createdAt INTEGER NOT NULL,
            completedAt INTEGER
          )
        ''');
      },
    );
  }

  /// Load downloads from database
  Future<void> _loadDownloads() async {
    if (_database == null) {
      return;
    }

    final List<Map<String, dynamic>> maps = await _database!.query('downloads');
    _downloads.clear();

    for (var map in maps) {
      final download = DownloadItem.fromMap(map);
      _downloads[download.id] = download;

      // Reset downloading status to queued on app restart
      if (download.status == DownloadStatus.downloading) {
        _downloads[download.id] = download.copyWith(
          status: DownloadStatus.queued,
        );
      }
    }

    notifyListeners();
  }

  /// Add a download to the queue
  Future<String> addDownload({
    required String animeId,
    required String animeName,
    required String episodeNumber,
    required String episodeTitle,
    required String videoUrl,
    required String thumbnailUrl,
    DownloadQuality quality = DownloadQuality.auto,
  }) async {
    final id = '${animeId}_$episodeNumber';

    // Check if already exists
    if (_downloads.containsKey(id)) {
      final existing = _downloads[id]!;
      if (existing.status == DownloadStatus.completed) {
        throw Exception('Episode already downloaded');
      }
      if (existing.status == DownloadStatus.downloading ||
          existing.status == DownloadStatus.queued) {
        throw Exception('Episode is already in download queue');
      }
      // If failed or cancelled, allow re-download
      await deleteDownload(id);
    }

    final download = DownloadItem(
      id: id,
      animeId: animeId,
      animeName: animeName,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      quality: quality,
    );

    _downloads[id] = download;
    await _saveDownload(download);

    notifyListeners();
    _processQueue();

    return id;
  }

  /// Add multiple downloads (batch download)
  Future<List<String>> addBatchDownloads({
    required String animeId,
    required String animeName,
    required List<Map<String, String>> episodes,
    required String thumbnailUrl,
    DownloadQuality quality = DownloadQuality.auto,
  }) async {
    final List<String> downloadIds = [];

    for (var episode in episodes) {
      try {
        final id = await addDownload(
          animeId: animeId,
          animeName: animeName,
          episodeNumber: episode['number']!,
          episodeTitle: episode['title'] ?? 'Episode ${episode['number']}',
          videoUrl: episode['url']!,
          thumbnailUrl: thumbnailUrl,
          quality: quality,
        );
        downloadIds.add(id);
      } catch (e) {
        debugPrint('Failed to add episode ${episode['number']}: $e');
      }
    }

    return downloadIds;
  }

  /// Process the download queue
  void _processQueue() {
    if (_activeDownloadCount >= _maxConcurrentDownloads) {
      return;
    }

    final queuedDownloads =
        _downloads.values
            .where((d) => d.status == DownloadStatus.queued)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (var download in queuedDownloads) {
      if (_activeDownloadCount >= _maxConcurrentDownloads) break;
      _startDownload(download.id);
    }
  }

  /// Start a download
  Future<void> _startDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    _activeDownloadCount++;
    _downloads[id] = download.copyWith(status: DownloadStatus.downloading);
    await _saveDownload(_downloads[id]!);
    notifyListeners();

    try {
      // Validate URL
      final Uri uri;
      try {
        uri = Uri.parse(download.videoUrl);
        if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
          throw Exception('Invalid URL scheme');
        }
        if (uri.host.isEmpty) {
          throw Exception('No host specified in URL');
        }
      } catch (e) {
        throw Exception('Invalid video URL: ${download.videoUrl}');
      }

      // Determine if URL is HLS/m3u8 or direct video
      final isHls =
          download.videoUrl.contains('.m3u8') ||
          download.videoUrl.contains('master.m3u8') ||
          download.videoUrl.contains('wixmp.com') ||
          download.videoUrl.contains('blogger.com') ||
          download.videoUrl.contains('allanime');

      if (isHls) {
        // For HLS streams, we'd need a proper HLS downloader
        // For now, throw error as HLS download requires external tools
        throw Exception(
          'HLS/streaming downloads not yet supported. Only AnimeFire downloads work currently.',
        );
      } else {
        // Direct HTTP download
        await _downloadHttp(id);
      }
    } catch (e) {
      debugPrint('Download error for $id: $e');
      _downloads[id] = download.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
      );
      await _saveDownload(_downloads[id]!);
    } finally {
      _activeDownloadCount--;
      _activeDownloads.remove(id);
      _downloadClients.remove(id);
      notifyListeners();
      _processQueue();
    }
  }

  /// Download via HTTP
  Future<void> _downloadHttp(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    debugPrint('[Download] Starting download for $id');
    debugPrint('[Download] Episode URL: ${download.videoUrl}');

    // Resolve the actual video URL (extract from page and get direct link)
    String actualVideoUrl;
    try {
      debugPrint('[Download] Resolving video URL...');

      // Step 1: Extract video source from episode page
      final videoSrc = await AnimeService.extractVideoURL(download.videoUrl);
      debugPrint('[Download] Extracted video source: $videoSrc');

      // Step 2: Get the actual video URL
      final videoResult = await AnimeService.extractActualVideoURL(videoSrc);
      actualVideoUrl = videoResult.url;
      debugPrint('[Download] Resolved video URL: $actualVideoUrl');
    } catch (e) {
      debugPrint('[Download] Failed to resolve video URL: $e');
      throw Exception('Failed to get video URL: $e');
    }

    // Create download directory
    final downloadDir = await _getDownloadDirectory();
    final safeAnimeName = _sanitizeFileName(download.animeName);
    final animeDir = Directory(path.join(downloadDir.path, safeAnimeName));
    await animeDir.create(recursive: true);

    final fileName = 'Episode_${download.episodeNumber}.mp4';
    final filePath = path.join(animeDir.path, fileName);
    debugPrint('[Download] Saving to: $filePath');

    // Create HTTP client
    final client = http.Client();
    _downloadClients[id] = client;

    try {
      // Get content length first
      debugPrint('[Download] Getting content length...');
      final headResponse = await client.head(Uri.parse(actualVideoUrl));
      final totalBytes =
          int.tryParse(headResponse.headers['content-length'] ?? '0') ?? 0;
      debugPrint(
        '[Download] Total size: ${totalBytes} bytes (${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB)',
      );

      // Start streaming download
      debugPrint('[Download] Starting stream...');
      final request = http.Request('GET', Uri.parse(actualVideoUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final file = File(filePath);
      final sink = file.openWrite();
      int bytesDownloaded = 0;

      await for (var chunk in response.stream) {
        // Check if download was cancelled
        if (!_downloads.containsKey(id) ||
            _downloads[id]!.status == DownloadStatus.cancelled) {
          await sink.close();
          await file.delete();
          return;
        }

        // Check if download was paused
        if (_downloads[id]!.status == DownloadStatus.paused) {
          await sink.close();
          return;
        }

        sink.add(chunk);
        bytesDownloaded += chunk.length;

        // Update progress
        final progress = totalBytes > 0 ? bytesDownloaded / totalBytes : 0.0;
        _downloads[id] = _downloads[id]!.copyWith(
          progress: progress,
          bytesDownloaded: bytesDownloaded,
          totalBytes: totalBytes > 0 ? totalBytes : bytesDownloaded,
        );

        // Save to DB and log every 1% or every 1MB, whichever is less frequent
        final shouldSave = totalBytes > 0
            ? (totalBytes >= 100 && bytesDownloaded % (totalBytes ~/ 100) == 0)
            : (bytesDownloaded % (1024 * 1024) == 0); // Every 1MB

        if (shouldSave) {
          debugPrint(
            '[Download] Progress: ${(progress * 100).toStringAsFixed(1)}% (${(bytesDownloaded / 1024 / 1024).toStringAsFixed(2)} MB)',
          );
          await _saveDownload(_downloads[id]!);
        }

        // Notify UI more frequently - every 256KB
        if (bytesDownloaded % (256 * 1024) == 0) {
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();

      debugPrint('[Download] Download completed: $id');
      debugPrint('[Download] File saved to: $filePath');

      // Download completed
      _downloads[id] = _downloads[id]!.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        filePath: filePath,
        completedAt: DateTime.now(),
      );
      await _saveDownload(_downloads[id]!);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Pause a download
  Future<void> pauseDownload(String id) async {
    final download = _downloads[id];
    if (download == null || download.status != DownloadStatus.downloading) {
      return;
    }

    _downloads[id] = download.copyWith(status: DownloadStatus.paused);
    await _saveDownload(_downloads[id]!);
    notifyListeners();
  }

  /// Resume a download
  Future<void> resumeDownload(String id) async {
    final download = _downloads[id];
    if (download == null || download.status != DownloadStatus.paused) {
      return;
    }

    _downloads[id] = download.copyWith(status: DownloadStatus.queued);
    await _saveDownload(_downloads[id]!);
    notifyListeners();
    _processQueue();
  }

  /// Cancel a download
  Future<void> cancelDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    _downloads[id] = download.copyWith(status: DownloadStatus.cancelled);
    _downloadClients[id]?.close();
    await _saveDownload(_downloads[id]!);

    // Delete partial file
    if (download.filePath != null) {
      final file = File(download.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    notifyListeners();
  }

  /// Retry a failed download
  Future<void> retryDownload(String id) async {
    final download = _downloads[id];
    if (download == null || download.status != DownloadStatus.failed) {
      return;
    }

    _downloads[id] = download.copyWith(
      status: DownloadStatus.queued,
      error: null,
      progress: 0,
      bytesDownloaded: 0,
    );
    await _saveDownload(_downloads[id]!);
    notifyListeners();
    _processQueue();
  }

  /// Delete a download
  Future<void> deleteDownload(String id) async {
    final download = _downloads[id];
    if (download == null) {
      return;
    }

    // Cancel if active
    if (download.status == DownloadStatus.downloading) {
      await cancelDownload(id);
    }

    // Delete file
    if (download.filePath != null) {
      final file = File(download.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Remove from database
    await _database?.delete('downloads', where: 'id = ?', whereArgs: [id]);
    _downloads.remove(id);
    notifyListeners();
  }

  /// Clear all completed downloads
  Future<void> clearCompleted() async {
    final completed = _downloads.values
        .where((d) => d.status == DownloadStatus.completed)
        .toList();

    for (var download in completed) {
      await deleteDownload(download.id);
    }
  }

  /// Get download by ID
  DownloadItem? getDownload(String id) => _downloads[id];

  /// Get downloads for an anime
  List<DownloadItem> getAnimeDownloads(String animeId) {
    return _downloads.values.where((d) => d.animeId == animeId).toList()
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  }

  /// Save download to database
  Future<void> _saveDownload(DownloadItem download) async {
    await _database?.insert(
      'downloads',
      download.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get download directory
  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      return Directory(path.join(directory!.path, 'GoAnime', 'Downloads'));
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return Directory(path.join(directory.path, 'Downloads'));
    }
  }

  /// Sanitize file name
  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Get total download size
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Dispose resources
  @override
  void dispose() {
    for (var client in _downloadClients.values) {
      client.close();
    }
    _downloadClients.clear();
    _activeDownloads.clear();
    super.dispose();
  }
}
