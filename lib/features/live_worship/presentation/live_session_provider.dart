import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/live_session.dart';


// ─────────────────────────────────────────────
// DEVICE ID PROVIDER — identificador del dispositivo
// ─────────────────────────────────────────────
final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  String deviceId = prefs.getString('device_id') ?? '';
  if (deviceId.isEmpty) {
    deviceId =
        'dev_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}';
    await prefs.setString('device_id', deviceId);
  }
  return deviceId;
});

// ─────────────────────────────────────────────
// STREAM PROVIDER — escucha la sesión en tiempo real
// ─────────────────────────────────────────────
final liveSessionStreamProvider =
    StreamProvider.family<LiveSession?, String>((ref, sessionId) {
  if (sessionId.isEmpty) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('live_sessions')
      .doc(sessionId)
      .snapshots()
      .map((snap) {
    if (!snap.exists || snap.data() == null) return null;
    return LiveSession.fromJson(snap.data()!);
  });
});

// ─────────────────────────────────────────────
// LIVE SESSION SERVICE — operaciones de Firestore
// ─────────────────────────────────────────────
class LiveSessionService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'live_sessions';

  /// Crea una sesión nueva en Firestore y devuelve el sessionId.
  static Future<String> createSession({
    required String title,
    required String date,
    required List<String> hymnIds,
    required String directorDeviceId,
  }) async {
    final sessionId =
        'live_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final session = LiveSession(
      sessionId: sessionId,
      title: title,
      date: date,
      hymnIds: hymnIds,
      currentIndex: 0,
      directorDeviceId: directorDeviceId,
      participantCount: 0,
      showChords: false,
      status: 'active',
      createdAt: DateTime.now(),
    );
    await _db.collection(_col).doc(sessionId).set(session.toJson());
    return sessionId;
  }

  /// Avanza o retrocede el himno actual.
  static Future<void> setCurrentIndex(String sessionId, int index) async {
    await _db.collection(_col).doc(sessionId).update({
      'currentIndex': index,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Activa o desactiva la visualización de acordes para todos.
  static Future<void> setShowChords(String sessionId, bool value) async {
    await _db.collection(_col).doc(sessionId).update({
      'showChords': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Actualiza el listado de himnos en vivo.
  static Future<void> updateHymnIds(
      String sessionId, List<String> hymnIds) async {
    await _db.collection(_col).doc(sessionId).update({
      'hymnIds': hymnIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Termina la sesión.
  static Future<void> endSession(String sessionId) async {
    await _db.collection(_col).doc(sessionId).update({
      'status': 'ended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Registra la presencia de un participante y devuelve su ID de presencia.
  static Future<String> joinSession(
      String sessionId, String deviceId) async {
    try {
      final presenceRef = _db
          .collection(_col)
          .doc(sessionId)
          .collection('participants')
          .doc(deviceId);

      await presenceRef.set({
        'deviceId': deviceId,
        'joinedAt': FieldValue.serverTimestamp(),
        'active': true,
      });

      // Actualizar contador
      await _db.collection(_col).doc(sessionId).update({
        'participantCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('>>> Error joining live session: $e');
    }
    return deviceId;
  }

  /// Elimina la presencia del participante al salir.
  static Future<void> leaveSession(
      String sessionId, String deviceId) async {
    try {
      await _db
          .collection(_col)
          .doc(sessionId)
          .collection('participants')
          .doc(deviceId)
          .delete();

      await _db.collection(_col).doc(sessionId).update({
        'participantCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('>>> Error leaving live session: $e');
    }
  }
}

// ─────────────────────────────────────────────
// ESTADO DE SESIÓN ACTIVA (sessionId que se está viendo)
// ─────────────────────────────────────────────
class _ActiveSessionIdNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final activeSessionIdProvider =
    NotifierProvider<_ActiveSessionIdNotifier, String>(_ActiveSessionIdNotifier.new);
