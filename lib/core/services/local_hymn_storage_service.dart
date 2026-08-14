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

  // =========================================================================
  // NUEVOS CANTOS LOCALES (Añadidos por el usuario)
  // =========================================================================
  static const String _keyLocalCustomHymns = 'local_custom_hymns_v1';

  /// Guarda un nuevo canto local. Retorna el ID asignado (basado en timestamp).
  static Future<int> saveCustomHymn(String title, String lyrics, String collection) async {
    final prefs = await SharedPreferences.getInstance();
    final customHymns = await _getCustomHymnsRaw();

    // Generar un ID único basado en el tiempo
    final id = DateTime.now().millisecondsSinceEpoch % 1000000; 

    customHymns.add({
      'id': id,
      'title': title,
      'lyrics': lyrics,
      'collection': collection,
      'isLocalOnly': true,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_keyLocalCustomHymns, jsonEncode(customHymns));
    return id;
  }

  /// Obtiene todos los cantos creados localmente por el usuario
  static Future<List<Map<String, dynamic>>> getCustomHymns() async {
    return await _getCustomHymnsRaw();
  }

  /// Elimina un canto local
  static Future<void> removeCustomHymn(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final customHymns = await _getCustomHymnsRaw();

    customHymns.removeWhere((hymn) => hymn['id'] == id);

    await prefs.setString(_keyLocalCustomHymns, jsonEncode(customHymns));
  }

  static Future<List<Map<String, dynamic>>> _getCustomHymnsRaw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_keyLocalCustomHymns);
      if (rawJson == null || rawJson.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(rawJson);
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }
}
