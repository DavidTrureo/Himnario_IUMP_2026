import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider global para la preferencia de notación musical de tonos y acordes.
/// Valores posibles:
/// - 'spanish' (Notación Latina por defecto: DO, RE, MI, FA, SOL, LA, SI)
/// - 'american' (Clave Americana: C, D, E, F, G, A, B)
class NotationNotifier extends Notifier<String> {
  static const _prefsKey = 'pref_chords_notation';

  @override
  String build() {
    _loadNotationPreference();
    return 'spanish';
  }

  Future<void> _loadNotationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey) ?? 'spanish';
    state = saved;
  }

  Future<void> setNotation(String notationType) async {
    if (state == notationType) return;
    state = notationType;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, notationType);
  }

  Future<void> toggleNotation() async {
    final nextMode = state == 'spanish' ? 'american' : 'spanish';
    await setNotation(nextMode);
  }
}

final notationProvider = NotifierProvider<NotationNotifier, String>(() {
  return NotationNotifier();
});
