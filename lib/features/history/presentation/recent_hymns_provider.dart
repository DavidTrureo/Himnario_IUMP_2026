import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../hymns/domain/hymn.dart';
import '../../hymns/presentation/hymn_list_screen.dart';
import '../domain/recent_hymn.dart';

/// Notificador del historial inteligente de cantos entonados (100% local en SharedPreferences)
class RecentHymnsNotifier extends Notifier<List<RecentHymn>> {
  static const _prefsKey = 'recent_sung_hymns_v1';
  static const int _maxItems = 30;

  @override
  List<RecentHymn> build() {
    _loadHistory();
    return [];
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final loaded = raw.map((str) {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return RecentHymn.fromJson(map);
        }).toList();
        state = loaded;
      }
    } catch (_) {
      state = [];
    }
  }

  /// Registra un canto en el historial. Lo posiciona primero (MRU).
  Future<void> recordHymn(String key, {String? tone}) async {
    if (key.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = List<RecentHymn>.from(state);

      // Eliminar ocurrencia previa para moverlo al inicio
      current.removeWhere((item) => item.key == key);

      final normalizedTone = (tone != null && tone.isNotEmpty) ? Hymn.normalizeToneNote(tone) : null;

      // Insertar al inicio con timestamp actual
      current.insert(0, RecentHymn(
        key: key,
        timestamp: DateTime.now(),
        tone: normalizedTone,
      ));

      // Limitar a máximo 30 elementos
      if (current.length > _maxItems) {
        current.removeRange(_maxItems, current.length);
      }

      state = current;

      // Persistir
      final encoded = current.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_prefsKey, encoded);
    } catch (_) {}
  }

  /// Elimina un canto del historial
  Future<void> removeHymn(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = List<RecentHymn>.from(state)..removeWhere((item) => item.key == key);
      state = current;
      final encoded = current.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_prefsKey, encoded);
    } catch (_) {}
  }

  /// Limpia todo el historial de cantos recientes
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = [];
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }
}

final recentHymnsProvider = NotifierProvider<RecentHymnsNotifier, List<RecentHymn>>(
  RecentHymnsNotifier.new,
);

/// Proveedor de ayuda que combina los ítems recientes con los objetos Hymn cargados
final recentHymnsWithHymnProvider = Provider<List<({RecentHymn recent, Hymn hymn})>>((ref) {
  final recents = ref.watch(recentHymnsProvider);
  final allHymns = ref.watch(allHymnsGlobalProvider).value ?? [];

  if (recents.isEmpty || allHymns.isEmpty) return [];

  final result = <({RecentHymn recent, Hymn hymn})>[];
  for (final item in recents) {
    final parts = item.key.split('-');
    if (parts.length < 2) continue;
    final collection = parts[0];
    final id = int.tryParse(parts[1]);
    if (id == null) continue;

    final hymn = allHymns.where((h) => h.collection == collection && h.id == id).firstOrNull;
    if (hymn != null) {
      result.add((recent: item, hymn: hymn));
    }
  }
  return result;
});
