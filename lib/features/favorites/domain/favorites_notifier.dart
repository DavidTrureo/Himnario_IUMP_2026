import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesNotifier extends Notifier<Set<String>> {
  static const _prefsKey = 'favorite_hymns_v2'; // changed key to avoid parsing errors from v1

  @override
  Set<String> build() {
    _loadFavorites();
    return {};
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedFavorites = prefs.getStringList(_prefsKey);
    if (storedFavorites != null) {
      Future.microtask(() {
        state = storedFavorites.toSet();
      });
    } else {
      // Migrate old int favorites to 'iump-id'
      final List<String>? oldFavorites = prefs.getStringList('favorite_hymns');
      if (oldFavorites != null) {
        final migrated = oldFavorites.map((e) => 'iump-$e').toSet();
        Future.microtask(() {
          state = migrated;
        });
        await prefs.setStringList(_prefsKey, migrated.toList());
      }
    }
  }

  Future<void> toggleFavorite(String idKey) async {
    final prefs = await SharedPreferences.getInstance();
    final currentFavorites = Set<String>.from(state);

    if (currentFavorites.contains(idKey)) {
      currentFavorites.remove(idKey);
    } else {
      currentFavorites.add(idKey);
    }

    state = currentFavorites;
    await prefs.setStringList(_prefsKey, currentFavorites.toList());
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(() {
  return FavoritesNotifier();
});
