import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalHymnStorageService {
  static const String _keyLocalEdits = 'local_hymn_edits_cache_v1';

  /// Guarda o actualiza los acordes/letra de un canto en la memoria del dispositivo
  static Future<void> saveLocalHymnEdit(String collection, int hymnId, String lyrics) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, String> currentCache = await getLocalHymnEdits();

    final key = '$collection-$hymnId';
    currentCache[key] = lyrics;

    await prefs.setString(_keyLocalEdits, jsonEncode(currentCache));
  }

  /// Obtiene todos los cantos editados localmente
  static Future<Map<String, String>> getLocalHymnEdits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_keyLocalEdits);
      if (rawJson == null || rawJson.isEmpty) return {};

      final Map<String, dynamic> decoded = jsonDecode(rawJson);
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  /// Borra la caché local de un canto específico
  static Future<void> removeLocalHymnEdit(String collection, int hymnId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCache = await getLocalHymnEdits();

    final key = '$collection-$hymnId';
    currentCache.remove(key);

    await prefs.setString(_keyLocalEdits, jsonEncode(currentCache));
  }

  /// Limpia todos los respaldos locales de cantos
  static Future<void> clearAllLocalEdits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLocalEdits);
  }
}
