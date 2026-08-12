import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveWorshipSyncState {
  final String roomCode;
  final String activeHymnId;
  final String setlistTitle;
  final int activeSlideIndex;
  final String updatedBy;

  const LiveWorshipSyncState({
    required this.roomCode,
    required this.activeHymnId,
    required this.setlistTitle,
    required this.activeSlideIndex,
    required this.updatedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'activeHymnId': activeHymnId,
      'setlistTitle': setlistTitle,
      'activeSlideIndex': activeSlideIndex,
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory LiveWorshipSyncState.fromMap(Map<String, dynamic> map) {
    return LiveWorshipSyncState(
      roomCode: map['roomCode'] ?? '',
      activeHymnId: map['activeHymnId'] ?? '',
      setlistTitle: map['setlistTitle'] ?? '',
      activeSlideIndex: map['activeSlideIndex'] ?? 0,
      updatedBy: map['updatedBy'] ?? '',
    );
  }
}

class LiveWorshipSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Inicia o actualiza una sala de transmisión en vivo de alabanza
  static Future<void> publishLiveSync({
    required String roomCode,
    required String activeHymnId,
    required String setlistTitle,
    required int activeSlideIndex,
    String leaderName = 'Director',
  }) async {
    try {
      final docRef = _firestore.collection('live_worship_rooms').doc(roomCode.toUpperCase());
      final state = LiveWorshipSyncState(
        roomCode: roomCode.toUpperCase(),
        activeHymnId: activeHymnId,
        setlistTitle: setlistTitle,
        activeSlideIndex: activeSlideIndex,
        updatedBy: leaderName,
      );
      await docRef.set(state.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  /// Escucha en tiempo real la sala de alabanza activa
  static Stream<LiveWorshipSyncState?> listenToRoom(String roomCode) {
    return _firestore
        .collection('live_worship_rooms')
        .doc(roomCode.toUpperCase())
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return LiveWorshipSyncState.fromMap(snapshot.data()!);
    });
  }
}
