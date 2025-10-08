import 'package:flutter/foundation.dart';

/// Notificador global para mudanças na watchlist
class WatchlistNotifier extends ChangeNotifier {
  static final WatchlistNotifier _instance = WatchlistNotifier._internal();

  factory WatchlistNotifier() => _instance;

  WatchlistNotifier._internal();

  /// Notifica que a watchlist foi modificada (adição ou remoção)
  void notifyWatchlistChanged() {
    notifyListeners();
  }
}
