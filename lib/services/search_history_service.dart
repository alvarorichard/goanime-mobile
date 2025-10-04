import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _historyKey = 'search_history';
  static const int _maxHistoryItems = 20;

  /// Salva uma busca no histórico
  static Future<void> saveSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final history = await getSearchHistory();
    
    // Remove duplicatas e adiciona no início
    history.remove(query.trim());
    history.insert(0, query.trim());
    
    // Limita o tamanho do histórico
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }
    
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  /// Obtém o histórico de buscas
  static Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      print('Error loading search history: $e');
      return [];
    }
  }

  /// Remove um item do histórico
  static Future<void> removeSearchItem(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getSearchHistory();
    
    history.remove(query);
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  /// Limpa todo o histórico
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  /// Obtém sugestões baseadas no histórico
  static Future<List<String>> getSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    
    final history = await getSearchHistory();
    final lowerQuery = query.toLowerCase();
    
    return history
        .where((item) => item.toLowerCase().contains(lowerQuery))
        .take(5)
        .toList();
  }
}
