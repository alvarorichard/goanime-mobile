import 'package:flutter/foundation.dart';
import 'package:goanime/modules/continue_watching/continue_watching.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class ContinueWatchingService {
  static final ContinueWatchingService _instance =
      ContinueWatchingService._internal();
  static Database? _database;

  factory ContinueWatchingService() => _instance;

  ContinueWatchingService._internal();

  static const String _dbName = 'continue_watching.db';
  static const String _tableName = 'continue_watching';
  static const int _maxRecords = 50;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animeTitle TEXT NOT NULL,
        episodeNumber TEXT NOT NULL,
        episodeUrl TEXT NOT NULL,
        imageUrl TEXT,
        animeId TEXT,
        animeUrl TEXT,
        progressSeconds INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL,
        watchedAt TEXT NOT NULL,
        source TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_episode_url ON $_tableName(episodeUrl)
    ''');

    await db.execute('''
      CREATE INDEX idx_watched_at ON $_tableName(watchedAt DESC)
    ''');

    debugPrint('[ContinueWatchingService] Database created');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('''
          ALTER TABLE $_tableName ADD COLUMN animeUrl TEXT
        ''');
        debugPrint('[ContinueWatchingService] Added animeUrl column');
      } catch (e) {
        debugPrint(
          '[ContinueWatchingService] Column animeUrl might already exist',
        );
      }
    }
  }

  Future<void> saveProgress({
    required String animeTitle,
    required String episodeNumber,
    required String episodeUrl,
    String? imageUrl,
    String? animeId,
    String? animeUrl,
    required int progressSeconds,
    required int durationSeconds,
    String? source,
  }) async {
    try {
      final db = await database;

      final existing = await db.query(
        _tableName,
        where: 'episodeUrl = ?',
        whereArgs: [episodeUrl],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        await db.update(
          _tableName,
          {
            'progressSeconds': progressSeconds,
            'durationSeconds': durationSeconds,
            'watchedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        debugPrint(
          '[ContinueWatchingService] Updated progress: $animeTitle - Ep $episodeNumber',
        );
      } else {
        await db.insert(_tableName, {
          'animeTitle': animeTitle,
          'episodeNumber': episodeNumber,
          'episodeUrl': episodeUrl,
          'imageUrl': imageUrl,
          'animeId': animeId,
          'animeUrl': animeUrl,
          'progressSeconds': progressSeconds,
          'durationSeconds': durationSeconds,
          'watchedAt': DateTime.now().toIso8601String(),
          'source': source,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        debugPrint(
          '[ContinueWatchingService] Saved new progress: $animeTitle - Ep $episodeNumber',
        );
      }

      await _cleanOldRecords();
    } catch (e) {
      debugPrint('[ContinueWatchingService] Error saving progress: $e');
    }
  }

  Future<List<ContinueWatchingModel>> getAllProgress() async {
    try {
      final db = await database;
      final maps = await db.query(_tableName, orderBy: 'watchedAt DESC');

      return List.generate(maps.length, (i) {
        return ContinueWatchingModel.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('[ContinueWatchingService] Error fetching all progress: $e');
      return [];
    }
  }

  Future<ContinueWatchingModel?> getEpisodeProgress(String episodeUrl) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'episodeUrl = ?',
        whereArgs: [episodeUrl],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return ContinueWatchingModel.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint(
        '[ContinueWatchingService] Error fetching episode progress: $e',
      );
      return null;
    }
  }

  Future<void> removeProgress(int id) async {
    try {
      final db = await database;
      await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
      debugPrint('[ContinueWatchingService] Removed progress record: $id');
    } catch (e) {
      debugPrint('[ContinueWatchingService] Error removing progress: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      final db = await database;
      await db.delete(_tableName);
      debugPrint('[ContinueWatchingService] Cleared all progress records');
    } catch (e) {
      debugPrint('[ContinueWatchingService] Error clearing all progress: $e');
    }
  }

  Future<void> _cleanOldRecords() async {
    try {
      final db = await database;

      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName',
      );
      final count = countResult.first['count'] as int;

      if (count > _maxRecords) {
        final toDelete = count - _maxRecords;
        await db.rawQuery('''
          DELETE FROM $_tableName 
          WHERE id IN (
            SELECT id FROM $_tableName 
            ORDER BY watchedAt ASC 
            LIMIT $toDelete
          )
        ''');
        debugPrint('[ContinueWatchingService] Cleaned $toDelete old records');
      }
    } catch (e) {
      debugPrint('[ContinueWatchingService] Error cleaning old records: $e');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
