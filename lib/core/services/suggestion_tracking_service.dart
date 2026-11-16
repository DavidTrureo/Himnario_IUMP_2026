import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo ligero para guardar y rastrear en el dispositivo del usuario
/// las sugerencias y propuestas que ha enviado al catálogo oficial.
class SubmittedSuggestion {
  final String docId;
  final String title;
  final String collection;
  final String requesterName;
  final String requesterChurch;
  final DateTime date;
  final String type; // 'new', 'correction', 'medley'
  final int? targetHymnId;
  final String? targetTitle;
  final String? reason;
  final String status; // 'pending', 'approved', 'rejected'
  final int? publishedId;
  final String? publishedCollection;

  SubmittedSuggestion({
    required this.docId,
    required this.title,
    required this.collection,
    required this.requesterName,
    required this.requesterChurch,
    required this.date,
    this.type = 'new',
    this.targetHymnId,
    this.targetTitle,
    this.reason,
    this.status = 'pending',
    this.publishedId,
    this.publishedCollection,
  });

  Map<String, dynamic> toJson() => {
    'docId': docId,
    'title': title,
    'collection': collection,
    'requesterName': requesterName,
    'requesterChurch': requesterChurch,
    'date': date.toIso8601String(),
    'type': type,
    'targetHymnId': targetHymnId,
    'targetTitle': targetTitle,
    'reason': reason,
    'status': status,
    'publishedId': publishedId,
    'publishedCollection': publishedCollection,
  };

  factory SubmittedSuggestion.fromJson(Map<String, dynamic> json) => SubmittedSuggestion(
    docId: json['docId']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    collection: json['collection']?.toString() ?? 'especiales',
    requesterName: json['requesterName']?.toString() ?? '',
    requesterChurch: json['requesterChurch']?.toString() ?? '',
    date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    type: json['type']?.toString() ?? 'new',
    targetHymnId: json['targetHymnId'] != null ? int.tryParse(json['targetHymnId'].toString()) : null,
    targetTitle: json['targetTitle']?.toString(),
    reason: json['reason']?.toString(),
    status: json['status']?.toString() ?? 'pending',
    publishedId: json['publishedId'] != null ? int.tryParse(json['publishedId'].toString()) : null,
    publishedCollection: json['publishedCollection']?.toString(),
  );

  SubmittedSuggestion copyWith({
    String? status,
    int? publishedId,
    String? publishedCollection,
  }) => SubmittedSuggestion(
    docId: docId,
    title: title,
    collection: collection,
    requesterName: requesterName,
    requesterChurch: requesterChurch,
    date: date,
    type: type,
    targetHymnId: targetHymnId,
    targetTitle: targetTitle,
    reason: reason,
    status: status ?? this.status,
    publishedId: publishedId ?? this.publishedId,
    publishedCollection: publishedCollection ?? this.publishedCollection,
  );
}

class SuggestionTrackingService {
  static const String _keyHistory = 'my_submitted_suggestions_v1';

  /// Guarda una nueva sugerencia enviada por el usuario en su memoria local
  static Future<void> saveSubmittedSuggestion(SubmittedSuggestion suggestion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getSubmittedSuggestions();

      // Evitar duplicados por docId
      list.removeWhere((item) => item.docId == suggestion.docId);
      list.insert(0, suggestion);

      // Guardar hasta un máximo de 50 sugerencias
      final trimmed = list.take(50).map((e) => e.toJson()).toList();
      await prefs.setString(_keyHistory, jsonEncode(trimmed));
    } catch (_) {}
  }

  /// Recupera todas las sugerencias guardadas localmente
  static Future<List<SubmittedSuggestion>> getSubmittedSuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyHistory);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => SubmittedSuggestion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Actualiza el estado local de una sugerencia (ej: cuando se detecta que ya fue aprobada)
  static Future<void> updateSuggestionStatus(
    String docId, {
    required String status,
    int? publishedId,
    String? publishedCollection,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getSubmittedSuggestions();
      final idx = list.indexWhere((e) => e.docId == docId);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(
          status: status,
          publishedId: publishedId,
          publishedCollection: publishedCollection,
        );
        final encoded = list.map((e) => e.toJson()).toList();
        await prefs.setString(_keyHistory, jsonEncode(encoded));
      }
    } catch (_) {}
  }
}
