import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/favorites/domain/favorites_notifier.dart';
import '../../features/setlists/domain/setlist.dart';
import '../../features/setlists/presentation/setlists_provider.dart';

class HymnHistoryItem {
  final String hymnKey;
  final int id;
  final String title;
  final String collection;
  final String viewedAt;

  HymnHistoryItem({
    required this.hymnKey,
    required this.id,
    required this.title,
    required this.collection,
    required this.viewedAt,
  });

  factory HymnHistoryItem.fromJson(Map<String, dynamic> json) {
    return HymnHistoryItem(
      hymnKey: json['hymnKey'] ?? '',
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] ?? '',
      collection: json['collection'] ?? 'iump',
      viewedAt: json['viewedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hymnKey': hymnKey,
      'id': id,
      'title': title,
      'collection': collection,
      'viewedAt': viewedAt,
    };
  }
}

/// Servicio que orquesta la persistencia local y sincronización bidireccional en la Nube
/// (Firebase Firestore) para Favoritos, Repertorios de Culto (Setlists) e Historial.
class CloudUserSyncService {
  static const String _favoritesPrefsKey = 'favorite_hymns_v2';
  static const String _setlistsPrefsKey = 'local_setlists';
  static const String _historyPrefsKey = 'user_hymn_history_v1';
  static const String _syncCollection = 'user_sync';

  static StreamSubscription<DocumentSnapshot>? _syncSubscription;
  static bool _isSyncingRemote = false;

  /// Obtiene el ID único de sincronización (UID de usuario autenticado o ID de dispositivo local)
  static String? get currentSyncUid {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  /// Inicializa la sincronización cuando la app arranca o cuando cambia el estado de autenticación
  static void initialize(dynamic ref) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        debugPrint('>>> [CloudSync] Usuario conectado (${user.email} · ${user.uid}). Sincronizando datos...');
        syncWithCloud(ref);
        _listenToRemoteChanges(ref, user.uid);
      } else {
        debugPrint('>>> [CloudSync] Sesión cerrada. Cancelando escucha remota.');
        _syncSubscription?.cancel();
        _syncSubscription = null;
      }
    });
  }

  /// Escucha en tiempo real cambios desde otros dispositivos del mismo usuario
  static void _listenToRemoteChanges(dynamic ref, String uid) {
    _syncSubscription?.cancel();
    _syncSubscription = FirebaseFirestore.instance
        .collection(_syncCollection)
        .doc(uid)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || _isSyncingRemote) return;
      final data = snapshot.data();
      if (data == null) return;

      debugPrint('>>> [CloudSync] Actualización remota recibida desde Firestore.');
      await _applyRemoteData(ref, data);
    }, onError: (e) {
      debugPrint('>>> [CloudSync] Error en listener remoto: $e');
    });
  }

  /// Aplica datos remotos de Firestore a la app local
  static Future<void> _applyRemoteData(dynamic ref, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Favoritos
    if (data['favorites'] is List) {
      final remoteFavs = (data['favorites'] as List).map((e) => e.toString()).toSet();
      final localFavs = (prefs.getStringList(_favoritesPrefsKey) ?? []).toSet();
      final mergedFavs = {...localFavs, ...remoteFavs};

      await prefs.setStringList(_favoritesPrefsKey, mergedFavs.toList());
      ref.read(favoritesProvider.notifier).setFavoritesFromExternal(mergedFavs);
    }

    // 2. Setlists / Repertorios
    if (data['setlists'] is List) {
      final remoteSetlistsRaw = data['setlists'] as List;
      final remoteList = remoteSetlistsRaw
          .whereType<Map>()
          .map((m) => Setlist.fromJson(Map<String, dynamic>.from(m), ''))
          .toList();

      final localJson = prefs.getString(_setlistsPrefsKey);
      List<Setlist> localList = [];
      if (localJson != null && localJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(localJson);
          localList = decoded
              .map((item) => Setlist.fromJson(Map<String, dynamic>.from(item), ''))
              .toList();
        } catch (_) {}
      }

      // Merge sin duplicados de ID (gana el remoto si ya existe)
      final Map<String, Setlist> setlistMap = {for (final s in localList) s.id: s};
      for (final s in remoteList) {
        setlistMap[s.id] = s;
      }
      final mergedSetlists = setlistMap.values.toList();
      mergedSetlists.sort((a, b) => b.date.compareTo(a.date));

      final encoded = jsonEncode(mergedSetlists.map((s) => s.toJson()).toList());
      await prefs.setString(_setlistsPrefsKey, encoded);
      ref.read(setlistsProvider.notifier).setSetlistsFromExternal(mergedSetlists);
    }

    // 3. Historial
    if (data['history'] is List) {
      final remoteHistory = (data['history'] as List)
          .whereType<Map>()
          .map((m) => HymnHistoryItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      final localHistory = await getLocalHistory();
      final Map<String, HymnHistoryItem> historyMap = {for (final h in localHistory) h.hymnKey: h};
      for (final h in remoteHistory) {
        historyMap[h.hymnKey] = h;
      }
      final mergedHistory = historyMap.values.toList();
      mergedHistory.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
      await _saveLocalHistory(mergedHistory.take(50).toList());
    }
  }

  /// Sincronización completa (bajada y subida fusionada)
  static Future<void> syncWithCloud(dynamic ref) async {
    final uid = currentSyncUid;
    if (uid == null) return;

    try {
      _isSyncingRemote = true;
      final docRef = FirebaseFirestore.instance.collection(_syncCollection).doc(uid);
      final docSnap = await docRef.get();
      final prefs = await SharedPreferences.getInstance();

      // Cargar local
      final localFavs = (prefs.getStringList(_favoritesPrefsKey) ?? []).toSet();
      
      final localJson = prefs.getString(_setlistsPrefsKey);
      List<Setlist> localSetlists = [];
      if (localJson != null && localJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(localJson);
          localSetlists = decoded
              .map((item) => Setlist.fromJson(Map<String, dynamic>.from(item), ''))
              .toList();
        } catch (_) {}
      }

      final localHistory = await getLocalHistory();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        await _applyRemoteData(ref, data);
      }

      // Ahora subir el estado fusionado para asegurar que Firestore tenga todo
      final finalFavs = (prefs.getStringList(_favoritesPrefsKey) ?? []).toSet();
      final finalSetlistsJson = prefs.getString(_setlistsPrefsKey);
      List<Setlist> finalSetlists = [];
      if (finalSetlistsJson != null && finalSetlistsJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(finalSetlistsJson);
          finalSetlists = decoded
              .map((item) => Setlist.fromJson(Map<String, dynamic>.from(item), ''))
              .toList();
        } catch (_) {}
      }
      final finalHistory = await getLocalHistory();

      await docRef.set({
        'favorites': finalFavs.toList(),
        'setlists': finalSetlists.map((s) => s.toJson()).toList(),
        'history': finalHistory.map((h) => h.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
        'devicePlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      }, SetOptions(merge: true));

      debugPrint('>>> [CloudSync] Sincronización bidireccional exitosa para UID: $uid');
    } catch (e) {
      debugPrint('>>> [CloudSync] Error al sincronizar con la nube: $e');
    } finally {
      _isSyncingRemote = false;
    }
  }

  /// Guarda y sube favoritos a la nube
  static Future<void> uploadFavorites(Set<String> favorites) async {
    final uid = currentSyncUid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection(_syncCollection).doc(uid).set({
        'favorites': favorites.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('>>> [CloudSync] Error al subir favoritos: $e');
    }
  }

  /// Guarda y sube repertorios a la nube
  static Future<void> uploadSetlists(List<Setlist> setlists) async {
    final uid = currentSyncUid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection(_syncCollection).doc(uid).set({
        'setlists': setlists.map((s) => s.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('>>> [CloudSync] Error al subir repertorios: $e');
    }
  }

  /// Registra un canto en el historial de visualizaciones
  static Future<void> recordHymnHistory({
    required String hymnKey,
    required int id,
    required String title,
    required String collection,
  }) async {
    try {
      final history = await getLocalHistory();
      final newItem = HymnHistoryItem(
        hymnKey: hymnKey,
        id: id,
        title: title,
        collection: collection,
        viewedAt: DateTime.now().toIso8601String(),
      );

      // Quitar si ya existía para ponerlo de primero
      history.removeWhere((item) => item.hymnKey == hymnKey);
      history.insert(0, newItem);

      // Limitar a los 50 más recientes
      final trimmed = history.take(50).toList();
      await _saveLocalHistory(trimmed);

      final uid = currentSyncUid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection(_syncCollection).doc(uid).set({
          'history': trimmed.map((h) => h.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('>>> [CloudSync] Error al registrar historial: $e');
    }
  }

  /// Obtiene el historial local
  static Future<List<HymnHistoryItem>> getLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyPrefsKey);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((m) => HymnHistoryItem.fromJson(Map<String, dynamic>.from(m))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveLocalHistory(List<HymnHistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString(_historyPrefsKey, encoded);
  }
}

/// Provider para observar el historial de cantos recientes
final hymnHistoryProvider = FutureProvider<List<HymnHistoryItem>>((ref) async {
  return await CloudUserSyncService.getLocalHistory();
});
