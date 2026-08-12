import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/hymns/domain/hymn.dart';

class HymnAnalyticsService {
  static const String _keyAnalytics = 'hymn_usage_analytics_v1';

  /// Incrementa el contador de cantado/visto para un himno
  static Future<void> recordHymnUsage(String collection, int hymnId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyAnalytics);
      final Map<String, int> counts = raw != null && raw.isNotEmpty
          ? Map<String, int>.from(jsonDecode(raw))
          : {};

      final key = '$collection-$hymnId';
      counts[key] = (counts[key] ?? 0) + 1;

      await prefs.setString(_keyAnalytics, jsonEncode(counts));
    } catch (_) {}
  }

  /// Obtiene los cantos más entonados ordenados por frecuencia
  static Future<List<HymnUsageCount>> getTopHymns(List<Hymn> allHymns, {int limit = 10}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyAnalytics);
      if (raw == null || raw.isEmpty) return [];

      final Map<String, dynamic> decoded = jsonDecode(raw);
      final List<HymnUsageCount> result = [];

      decoded.forEach((key, val) {
        final parts = key.split('-');
        if (parts.length >= 2) {
          final col = parts[0];
          final idNum = int.tryParse(parts.sublist(1).join('-')) ?? 0;
          final count = (val is int) ? val : int.tryParse(val.toString()) ?? 0;

          final matching = allHymns.firstWhere(
            (h) => h.collection == col && h.id == idNum,
            orElse: () => const Hymn(id: 0, title: '', toneNote: '', beats: '', timeSignature: '', lyrics: '', collection: ''),
          );

          if (matching.id != 0 && count > 0) {
            result.add(HymnUsageCount(hymn: matching, count: count));
          }
        }
      });

      result.sort((a, b) => b.count.compareTo(a.count));
      return result.take(limit).toList();
    } catch (_) {
      return [];
    }
  }
}

class HymnUsageCount {
  final Hymn hymn;
  final int count;

  const HymnUsageCount({required this.hymn, required this.count});
}
