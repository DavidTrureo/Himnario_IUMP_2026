import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class SetlistBackupService {
  static const String _backupVersion = '1.0.0';

  /// Exporta una copia de seguridad en JSON de todos los repertorios y ajustes
  static Future<void> exportBackupJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final setlistsRaw = prefs.getString('setlists_data') ?? '[]';
      final chordsCacheRaw = prefs.getString('local_hymn_chords_cache') ?? '{}';
      final favoritesRaw = prefs.getStringList('favorites_hymns') ?? [];
      final analyticsRaw = prefs.getString('hymn_usage_analytics_v1') ?? '{}';

      final Map<String, dynamic> backupPayload = {
        'version': _backupVersion,
        'appName': 'Himnario IUMP 2026',
        'exportDate': DateTime.now().toIso8601String(),
        'setlists': jsonDecode(setlistsRaw),
        'chordsCache': jsonDecode(chordsCacheRaw),
        'favorites': favoritesRaw,
        'analytics': jsonDecode(analyticsRaw),
      };

      final jsonText = const JsonEncoder.withIndent('  ').convert(backupPayload);

      await Share.share(
        jsonText,
        subject: 'Copia de Seguridad - Himnario IUMP 2026',
      );
    } catch (_) {}
  }

  /// Restaura una copia de seguridad a partir de un JSON formateado
  static Future<bool> restoreBackupJson(String jsonText) async {
    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonText);
      if (!decoded.containsKey('setlists')) return false;

      final prefs = await SharedPreferences.getInstance();

      if (decoded['setlists'] != null) {
        await prefs.setString('setlists_data', jsonEncode(decoded['setlists']));
      }

      if (decoded['chordsCache'] != null) {
        await prefs.setString('local_hymn_chords_cache', jsonEncode(decoded['chordsCache']));
      }

      if (decoded['favorites'] != null && decoded['favorites'] is List) {
        final List<String> favs = List<String>.from(decoded['favorites']);
        await prefs.setStringList('favorites_hymns', favs);
      }

      if (decoded['analytics'] != null) {
        await prefs.setString('hymn_usage_analytics_v1', jsonEncode(decoded['analytics']));
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
