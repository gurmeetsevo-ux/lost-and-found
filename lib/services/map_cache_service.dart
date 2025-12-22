// lib/services/map_cache_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MapCacheService {
  static const String _cacheKey = 'map_items_cache';
  static const int _cacheDurationHours = 1;

  static Future<void> cacheMapItems(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'items': items,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString(_cacheKey, jsonEncode(cacheData));
  }

  static Future<List<Map<String, dynamic>>?> getCachedMapItems() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheString = prefs.getString(_cacheKey);

    if (cacheString == null) return null;

    final cacheData = jsonDecode(cacheString);
    final timestamp = cacheData['timestamp'] as int;

    // Check if cache is still valid (1 hour)
    if (DateTime.now().millisecondsSinceEpoch - timestamp >
        _cacheDurationHours * 60 * 60 * 1000) {
      return null;
    }

    return List<Map<String, dynamic>>.from(cacheData['items']);
  }
}
