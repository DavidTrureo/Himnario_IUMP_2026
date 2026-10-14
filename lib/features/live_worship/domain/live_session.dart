import 'package:cloud_firestore/cloud_firestore.dart';

class LiveSession {
  final String sessionId;
  final String title;
  final String date;
  final List<String> hymnIds;
  final int currentIndex;
  final String directorDeviceId;
  final int participantCount;
  final bool showChords;
  final String status; // 'active' | 'ended'
  final DateTime createdAt;

  const LiveSession({
    required this.sessionId,
    required this.title,
    required this.date,
    required this.hymnIds,
    required this.currentIndex,
    required this.directorDeviceId,
    required this.participantCount,
    required this.showChords,
    required this.status,
    required this.createdAt,
  });

  bool get isActive => status == 'active';

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    return LiveSession(
      sessionId: json['sessionId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      hymnIds: List<String>.from(json['hymnIds'] as List? ?? []),
      currentIndex: json['currentIndex'] as int? ?? 0,
      directorDeviceId: json['directorDeviceId'] as String? ?? '',
      participantCount: json['participantCount'] as int? ?? 0,
      showChords: json['showChords'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'title': title,
      'date': date,
      'hymnIds': hymnIds,
      'currentIndex': currentIndex,
      'directorDeviceId': directorDeviceId,
      'participantCount': participantCount,
      'showChords': showChords,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  LiveSession copyWith({
    String? sessionId,
    String? title,
    String? date,
    List<String>? hymnIds,
    int? currentIndex,
    String? directorDeviceId,
    int? participantCount,
    bool? showChords,
    String? status,
    DateTime? createdAt,
  }) {
    return LiveSession(
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      date: date ?? this.date,
      hymnIds: hymnIds ?? this.hymnIds,
      currentIndex: currentIndex ?? this.currentIndex,
      directorDeviceId: directorDeviceId ?? this.directorDeviceId,
      participantCount: participantCount ?? this.participantCount,
      showChords: showChords ?? this.showChords,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
