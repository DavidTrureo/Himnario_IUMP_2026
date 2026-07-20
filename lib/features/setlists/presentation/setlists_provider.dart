import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/setlist.dart';

class SetlistsNotifier extends AsyncNotifier<List<Setlist>> {
  static const _localKey = 'local_setlists';

  @override
  Future<List<Setlist>> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Intentar cargar de almacenamiento local
      final localJson = prefs.getString(_localKey);
      if (localJson != null && localJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(localJson);
        final List<Setlist> localList = decoded
            .map((item) => Setlist.fromJson(Map<String, dynamic>.from(item), ''))
            .toList();
        
        // Ordenar por fecha descendente
        localList.sort((a, b) => b.date.compareTo(a.date));
        return localList;
      }

      // --- MIGRACIÓN ÚNICA DESDE FIRESTORE (si local está vacío) ---
      String deviceId = prefs.getString('device_id') ?? '';
      if (deviceId.isEmpty) {
        deviceId = 'dev_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}';
        await prefs.setString('device_id', deviceId);
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('setlists')
          .get();

      final List<Setlist> migratedList = [];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final docDeviceId = data['deviceId'] as String?;
        
        // Reclamar si no tiene ID (antiguos del creador) o si pertenece a este dispositivo
        if (docDeviceId == null || docDeviceId.isEmpty || docDeviceId == deviceId) {
          migratedList.add(Setlist.fromJson(data, doc.id));
          
          // Borrar de Firestore para limpiar la nube de forma asíncrona
          FirebaseFirestore.instance
              .collection('setlists')
              .doc(doc.id)
              .delete()
              .catchError((e) => debugPrint('Error deleting migrated setlist from cloud: $e'));
        }
      }

      if (migratedList.isNotEmpty) {
        // Guardar localmente
        final encoded = jsonEncode(migratedList.map((s) => s.toJson()).toList());
        await prefs.setString(_localKey, encoded);
        
        migratedList.sort((a, b) => b.date.compareTo(a.date));
        return migratedList;
      }

      return [];
    } catch (e) {
      debugPrint('>>> Error al obtener repertorios locales: $e');
      return [];
    }
  }

  Future<void> _saveToLocal(List<Setlist> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((s) => s.toJson()).toList());
    await prefs.setString(_localKey, encoded);
  }

  Future<void> addSetlist(String title, String date, List<String> hymnIds) async {
    try {
      final newId = 'set_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
      final newSetlist = Setlist(id: newId, title: title, date: date, hymnIds: hymnIds);
      
      final currentList = state.value ?? [];
      final newList = [newSetlist, ...currentList];
      
      await _saveToLocal(newList);
      state = AsyncValue.data(newList);
    } catch (e, stack) {
      debugPrint('>>> Error al guardar repertorio local: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateSetlist(Setlist setlist) async {
    try {
      final currentList = state.value ?? [];
      final newList = currentList.map((s) => s.id == setlist.id ? setlist : s).toList();
      
      await _saveToLocal(newList);
      state = AsyncValue.data(newList);
    } catch (e, stack) {
      debugPrint('>>> Error al actualizar repertorio local: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteSetlist(String id) async {
    try {
      final currentList = state.value ?? [];
      final newList = currentList.where((s) => s.id != id).toList();
      
      await _saveToLocal(newList);
      state = AsyncValue.data(newList);
    } catch (e, stack) {
      debugPrint('>>> Error al eliminar repertorio local: $e');
      state = AsyncValue.error(e, stack);
    }
  }
}

final setlistsProvider = AsyncNotifierProvider<SetlistsNotifier, List<Setlist>>(() {
  return SetlistsNotifier();
});

class ActiveSetlistNotifier extends Notifier<Setlist?> {
  @override
  Setlist? build() => null;

  void setSetlist(Setlist? value) {
    state = value;
  }
}

final activeSetlistProvider = NotifierProvider<ActiveSetlistNotifier, Setlist?>(() {
  return ActiveSetlistNotifier();
});
