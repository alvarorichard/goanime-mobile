import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/watchlist_anime.dart';

class WatchlistService {
  static Database? _database;
  static const String tableName = 'watchlist';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'watchlist.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            animeId TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            coverImage TEXT NOT NULL,
            myAnimeListUrl TEXT NOT NULL,
            addedAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Adicionar anime à watchlist
  Future<bool> addToWatchlist(WatchlistAnime anime) async {
    try {
      final db = await database;
      await db.insert(
        tableName,
        anime.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
      return false;
    }
  }

  // Remover anime da watchlist
  Future<bool> removeFromWatchlist(String animeId) async {
    try {
      final db = await database;
      await db.delete(tableName, where: 'animeId = ?', whereArgs: [animeId]);
      return true;
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      return false;
    }
  }

  // Verificar se anime está na watchlist
  Future<bool> isInWatchlist(String animeId) async {
    try {
      final db = await database;
      final result = await db.query(
        tableName,
        where: 'animeId = ?',
        whereArgs: [animeId],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking watchlist: $e');
      return false;
    }
  }

  // Obter todos os animes da watchlist
  Future<List<WatchlistAnime>> getWatchlist() async {
    try {
      final db = await database;
      final result = await db.query(tableName, orderBy: 'addedAt DESC');
      return result.map((map) => WatchlistAnime.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting watchlist: $e');
      return [];
    }
  }

  // Limpar toda a watchlist
  Future<bool> clearWatchlist() async {
    try {
      final db = await database;
      await db.delete(tableName);
      return true;
    } catch (e) {
      debugPrint('Error clearing watchlist: $e');
      return false;
    }
  }

  // Obter contagem de itens na watchlist
  Future<int> getWatchlistCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) FROM $tableName');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Error getting watchlist count: $e');
      return 0;
    }
  }
}
