import 'package:flutter/material.dart';
import 'package:goanime/modules/continue_watching/continue_watching.dart';

class ContinueWatchingController extends ChangeNotifier {
  final ContinueWatchingService _service = ContinueWatchingService();
  List<ContinueWatchingModel> _items = [];
  bool _isLoading = false;

  List<ContinueWatchingModel> get items => _items;
  bool get isLoading => _isLoading;
  bool get isEmpty => _items.isEmpty && !_isLoading;

  Future<void> loadContinueWatching() async {
    try {
      _isLoading = true;
      notifyListeners();

      final oldCount = _items.length;
      _items = await _service.getAllProgress();

      debugPrint(
        '[ContinueWatchingController] 📊 Loaded ${_items.length} items (was: $oldCount)',
      );

      // Log the first item's progress for debugging
      if (_items.isNotEmpty) {
        final first = _items.first;
        debugPrint(
          '[ContinueWatchingController] 📍 First item: ${first.animeTitle} - Progress: ${first.formattedProgress}/${first.formattedDuration}',
        );
      }
    } catch (e) {
      debugPrint('[ContinueWatchingController] ❌ Error loading: $e');
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeProgress(int? id) async {
    if (id == null) return;

    try {
      await _service.removeProgress(id);
      _items.removeWhere((item) => item.id == id);
      notifyListeners();

      debugPrint('[ContinueWatchingController] ✅ Removed item $id');
    } catch (e) {
      debugPrint('[ContinueWatchingController] ❌ Error removing: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      await _service.clearAll();
      _items.clear();
      notifyListeners();

      debugPrint('[ContinueWatchingController] ✅ Cleared all items');
    } catch (e) {
      debugPrint('[ContinueWatchingController] ❌ Error clearing: $e');
    }
  }

  /// Atualiza dados quando app volta do background
  Future<void> refresh() async {
    debugPrint('[ContinueWatchingController] 🔄 Manual refresh requested...');
    await loadContinueWatching();
    debugPrint('[ContinueWatchingController] ✅ Manual refresh completed');
  }
}
