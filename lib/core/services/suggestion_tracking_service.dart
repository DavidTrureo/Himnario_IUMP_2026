import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/hymns/domain/hymn.dart';

/// Resultado de la comparación interna Antes (sugerencia original) vs. Después (versión oficial publicada).
class SuggestionEditDiff {
  final bool wasEdited;
  final String? summary;
  final bool titleChanged;
  final bool lyricsChanged;
  final bool structureChanged;
  final bool chordsAdded;
  final bool keyChanged;
  final bool collectionChanged;

  const SuggestionEditDiff({
    required this.wasEdited,
    this.summary,
    this.titleChanged = false,
    this.lyricsChanged = false,
    this.structureChanged = false,
    this.chordsAdded = false,
    this.keyChanged = false,
    this.collectionChanged = false,
  });
}

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
  final String source; // 'manual', 'scanner_ia'
  final int? targetHymnId;
  final String? targetTitle;
  final String? reason;
  final String status; // 'pending', 'approved', 'rejected'
  final int? publishedId;
  final String? publishedCollection;
  final String? publishedTitle;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final bool editedByAdmin;
  final String? adminEditSummary;

  SubmittedSuggestion({
    required this.docId,
    required this.title,
    required this.collection,
    required this.requesterName,
    required this.requesterChurch,
    required this.date,
    this.type = 'new',
    this.source = 'manual',
    this.targetHymnId,
    this.targetTitle,
    this.reason,
    this.status = 'pending',
    this.publishedId,
    this.publishedCollection,
    this.publishedTitle,
    this.rejectionReason,
    this.reviewedAt,
    this.editedByAdmin = false,
    this.adminEditSummary,
  });

  Map<String, dynamic> toJson() => {
    'docId': docId,
    'title': title,
    'collection': collection,
    'requesterName': requesterName,
    'requesterChurch': requesterChurch,
    'date': date.toIso8601String(),
    'type': type,
    'source': source,
    'targetHymnId': targetHymnId,
    'targetTitle': targetTitle,
    'reason': reason,
    'status': status,
    'publishedId': publishedId,
    'publishedCollection': publishedCollection,
    'publishedTitle': publishedTitle,
    'rejectionReason': rejectionReason,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'editedByAdmin': editedByAdmin,
    'adminEditSummary': adminEditSummary,
  };

  factory SubmittedSuggestion.fromJson(Map<String, dynamic> json) => SubmittedSuggestion(
    docId: json['docId']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    collection: json['collection']?.toString() ?? 'especiales',
    requesterName: json['requesterName']?.toString() ?? '',
    requesterChurch: json['requesterChurch']?.toString() ?? '',
    date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    type: json['type']?.toString() ?? 'new',
    source: json['source']?.toString() ?? 'manual',
    targetHymnId: json['targetHymnId'] != null ? int.tryParse(json['targetHymnId'].toString()) : null,
    targetTitle: json['targetTitle']?.toString(),
    reason: json['reason']?.toString(),
    status: json['status']?.toString() ?? 'pending',
    publishedId: json['publishedId'] != null ? int.tryParse(json['publishedId'].toString()) : null,
    publishedCollection: json['publishedCollection']?.toString(),
    publishedTitle: json['publishedTitle']?.toString(),
    rejectionReason: json['rejectionReason']?.toString(),
    reviewedAt: json['reviewedAt'] != null ? DateTime.tryParse(json['reviewedAt'].toString()) : null,
    editedByAdmin: json['editedByAdmin'] == true,
    adminEditSummary: json['adminEditSummary']?.toString(),
  );

  SubmittedSuggestion copyWith({
    String? status,
    int? publishedId,
    String? publishedCollection,
    String? publishedTitle,
    String? rejectionReason,
    DateTime? reviewedAt,
    bool? editedByAdmin,
    String? adminEditSummary,
  }) => SubmittedSuggestion(
    docId: docId,
    title: title,
    collection: collection,
    requesterName: requesterName,
    requesterChurch: requesterChurch,
    date: date,
    type: type,
    source: source,
    targetHymnId: targetHymnId,
    targetTitle: targetTitle,
    reason: reason,
    status: status ?? this.status,
    publishedId: publishedId ?? this.publishedId,
    publishedCollection: publishedCollection ?? this.publishedCollection,
    publishedTitle: publishedTitle ?? this.publishedTitle,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    editedByAdmin: editedByAdmin ?? this.editedByAdmin,
    adminEditSummary: adminEditSummary ?? this.adminEditSummary,
  );
}

class SuggestionSyncResult {
  final List<SubmittedSuggestion> suggestions;
  final Set<String> newlyApprovedCollections;

  const SuggestionSyncResult({
    required this.suggestions,
    required this.newlyApprovedCollections,
  });
}

class SuggestionTrackingService {
  static const String _keyHistory = 'my_submitted_suggestions_v1';
  static const String _keyRequesterName = 'last_requester_name_v1';
  static const String _keyRequesterChurch = 'last_requester_church_v1';

  static String _normalizeForDiff(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trimRight())
        .join('\n')
        .trim();
  }

  static bool _hasChords(String text) {
    return RegExp(
      r'\[[A-G][#b]?[^\]]*\]|\[(?:DO|RE|MI|FA|SOL|LA|SI)[^\]]*\]',
      caseSensitive: false,
    ).hasMatch(text);
  }

  /// Compara internamente la versión original enviada por el usuario (Antes)
  /// contra la versión final o actualmente publicada en el catálogo oficial (Después).
  /// Solo marca `wasEdited: true` cuando existen cambios reales en letra, orden, acordes,
  /// título, tonalidad o colección (ignorando diferencias invisibles de saltos de línea).
  static SuggestionEditDiff compareBeforeAfter({
    required String originalTitle,
    required String originalLyrics,
    required String originalCollection,
    required String originalKey,
    required String finalTitle,
    required String finalLyrics,
    required String finalCollection,
    required String finalKey,
  }) {
    final normOrigTitle = originalTitle.trim();
    final normFinalTitle = finalTitle.trim();
    final titleChanged = normOrigTitle.isNotEmpty &&
        normFinalTitle.isNotEmpty &&
        normOrigTitle.toUpperCase() != normFinalTitle.toUpperCase();

    final normOrigLyrics = _normalizeForDiff(originalLyrics);
    final normFinalLyrics = _normalizeForDiff(finalLyrics);
    final lyricsChanged = normOrigLyrics.isNotEmpty &&
        normFinalLyrics.isNotEmpty &&
        normOrigLyrics != normFinalLyrics;

    final chordsAdded =
        lyricsChanged && !_hasChords(normOrigLyrics) && _hasChords(normFinalLyrics);

    final origBlocks = normOrigLyrics
        .split(RegExp(r'\n\s*\n'))
        .where((b) => b.trim().isNotEmpty)
        .length;
    final finalBlocks = normFinalLyrics
        .split(RegExp(r'\n\s*\n'))
        .where((b) => b.trim().isNotEmpty)
        .length;
    final structureRegex = RegExp(
      r'(?:^|\n)\s*(?:\[?(?:CORO|ESTROFA|PUENTE|INTRO|FINAL|VERSO|PRE-?CORO)\]?|[IVX]{1,4}\.?\s*$|\d+\.)',
      caseSensitive: false,
    );
    final origStructCount = structureRegex.allMatches(normOrigLyrics).length;
    final finalStructCount = structureRegex.allMatches(normFinalLyrics).length;
    final structureChanged =
        lyricsChanged && (origBlocks != finalBlocks || origStructCount != finalStructCount);

    final collectionChanged = originalCollection.trim().isNotEmpty &&
        finalCollection.trim().isNotEmpty &&
        originalCollection.trim() != finalCollection.trim();

    final normOrigKey = originalKey.trim().toLowerCase();
    final normFinalKey = finalKey.trim().toLowerCase();
    final keyChanged = normFinalKey.isNotEmpty && normOrigKey != normFinalKey;

    final wasEdited = titleChanged || lyricsChanged || collectionChanged || keyChanged;
    if (!wasEdited) {
      return const SuggestionEditDiff(wasEdited: false);
    }

    final parts = <String>[];
    if (lyricsChanged) {
      if (structureChanged) {
        parts.add('orden, ortografía y formato');
      } else {
        parts.add('ortografía y formato');
      }
    }
    if (chordsAdded) parts.add('acordes');
    if (titleChanged) parts.add('título');
    if (keyChanged) parts.add('tonalidad');
    if (collectionChanged) parts.add('colección');

    String summary;
    if (parts.isEmpty) {
      summary = 'ajustes de formato';
    } else if (parts.length == 1) {
      summary = 'ajustes de ${parts.first}';
    } else {
      final last = parts.removeLast();
      summary = 'ajustes de ${parts.join(', ')} y $last';
    }

    return SuggestionEditDiff(
      wasEdited: true,
      summary: summary,
      titleChanged: titleChanged,
      lyricsChanged: lyricsChanged,
      structureChanged: structureChanged,
      chordsAdded: chordsAdded,
      keyChanged: keyChanged,
      collectionChanged: collectionChanged,
    );
  }

  /// Guarda los datos del hermano/a para autocompletarlos en futuros envíos (+ o Escáner IA)
  static Future<void> saveRequesterProfile({
    required String name,
    required String church,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name.trim().isNotEmpty) {
        await prefs.setString(_keyRequesterName, name.trim());
      }
      if (church.trim().isNotEmpty) {
        await prefs.setString(_keyRequesterChurch, church.trim());
      }
    } catch (_) {}
  }

  /// Recupera los últimos datos de nombre e iglesia usados por el usuario
  static Future<({String name, String church})> getRequesterProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        name: prefs.getString(_keyRequesterName) ?? '',
        church: prefs.getString(_keyRequesterChurch) ?? '',
      );
    } catch (_) {
      return (name: '', church: '');
    }
  }

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

  /// Elimina una sugerencia del historial local del dispositivo
  static Future<void> removeSubmittedSuggestion(String docId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getSubmittedSuggestions();
      list.removeWhere((item) => item.docId == docId);
      final encoded = list.map((e) => e.toJson()).toList();
      await prefs.setString(_keyHistory, jsonEncode(encoded));
    } catch (_) {}
  }

  /// Actualiza el estado local de una sugerencia (ej: cuando se detecta que ya fue aprobada o rechazada)
  static Future<void> updateSuggestionStatus(
    String docId, {
    required String status,
    int? publishedId,
    String? publishedCollection,
    String? publishedTitle,
    String? rejectionReason,
    DateTime? reviewedAt,
    bool? editedByAdmin,
    String? adminEditSummary,
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
          publishedTitle: publishedTitle,
          rejectionReason: rejectionReason,
          reviewedAt: reviewedAt,
          editedByAdmin: editedByAdmin,
          adminEditSummary: adminEditSummary,
        );
        final encoded = list.map((e) => e.toJson()).toList();
        await prefs.setString(_keyHistory, jsonEncode(encoded));
      }
    } catch (_) {}
  }

  static DateTime? _parseFirestoreTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// Consulta directamente en Cloud Firestore el estado real de cada sugerencia enviada por este dispositivo,
  /// y realiza comparación interna Antes vs. Después contra el catálogo oficial para reflejar con precisión
  /// si el canto fue modificado/ordenado por el administrador (incluso tras ediciones posteriores).
  static Future<SuggestionSyncResult> syncStatusesFromCloud({
    List<Hymn> officialHymns = const [],
  }) async {
    final list = await getSubmittedSuggestions();
    if (list.isEmpty) {
      return const SuggestionSyncResult(
        suggestions: [],
        newlyApprovedCollections: {},
      );
    }

    final firestore = FirebaseFirestore.instance;
    final updatedList = List<SubmittedSuggestion>.from(list);
    final newlyApprovedCollections = <String>{};
    bool hasChanges = false;

    await Future.wait(
      List.generate(updatedList.length, (i) async {
        final item = updatedList[i];
        if (item.docId.isEmpty) return;

        // Si ya fue rechazada con fecha registrada, no es necesario volver a consultar
        if (item.status == 'rejected' && item.reviewedAt != null) {
          return;
        }

        try {
          DocumentSnapshot<Map<String, dynamic>> snap;
          try {
            snap = await firestore
                .collection('cantos_sugeridos')
                .doc(item.docId)
                .get(const GetOptions(source: Source.server));
          } catch (_) {
            // Si no hay conexión, intentar leer desde caché local de Firestore
            snap = await firestore
                .collection('cantos_sugeridos')
                .doc(item.docId)
                .get();
          }

          if (snap.exists && snap.data() != null) {
            final data = snap.data()!;
            final remoteStatus = data['status']?.toString() ?? 'pending';
            final remotePubId = data['publishedId'] != null
                ? int.tryParse(data['publishedId'].toString())
                : null;
            final remotePubCol = data['publishedCollection']?.toString();
            String? remotePubTitle = data['publishedTitle']?.toString();
            final remoteRejectionReason = data['rejectionReason']?.toString();
            final remoteReviewedAt = _parseFirestoreTimestamp(
              data['approvedAt'] ?? data['reviewedAt'],
            );
            bool remoteEditedByAdmin = data['editedByAdmin'] == true;
            String? remoteAdminEditSummary = data['adminEditSummary']?.toString();

            // Comparación interna Antes vs. Después contra el canto oficial en catálogo
            if (remoteStatus == 'approved' && remotePubId != null) {
              final effectiveCol = remotePubCol ?? item.collection;
              final publishedHymn = officialHymns
                  .where((h) => !h.isLocalOnly && h.collection == effectiveCol && h.id == remotePubId)
                  .firstOrNull;
              if (publishedHymn != null) {
                remotePubTitle = publishedHymn.title;
                final diff = compareBeforeAfter(
                  originalTitle: (data['title'] ?? item.title).toString(),
                  originalLyrics: (data['lyrics'] ?? '').toString(),
                  originalCollection: (data['collection'] ?? item.collection).toString(),
                  originalKey: (data['key'] ?? '').toString(),
                  finalTitle: publishedHymn.title,
                  finalLyrics: publishedHymn.lyrics,
                  finalCollection: publishedHymn.collection,
                  finalKey: publishedHymn.toneNote,
                );
                if (diff.wasEdited) {
                  remoteEditedByAdmin = true;
                  remoteAdminEditSummary = diff.summary ?? remoteAdminEditSummary;
                }
              }
            }

            if (remoteStatus != item.status ||
                remotePubId != item.publishedId ||
                remotePubCol != item.publishedCollection ||
                remotePubTitle != item.publishedTitle ||
                remoteRejectionReason != item.rejectionReason ||
                remoteReviewedAt != item.reviewedAt ||
                remoteEditedByAdmin != item.editedByAdmin ||
                remoteAdminEditSummary != item.adminEditSummary) {
              if (remoteStatus == 'approved' && item.status != 'approved') {
                newlyApprovedCollections.add(remotePubCol ?? item.collection);
              }
              updatedList[i] = item.copyWith(
                status: remoteStatus,
                publishedId: remotePubId,
                publishedCollection: remotePubCol,
                publishedTitle: remotePubTitle,
                rejectionReason: remoteRejectionReason,
                reviewedAt: remoteReviewedAt,
                editedByAdmin: remoteEditedByAdmin,
                adminEditSummary: remoteAdminEditSummary,
              );
              hasChanges = true;
            }
          } else if (!snap.exists && item.status == 'pending') {
            updatedList[i] = item.copyWith(status: 'rejected');
            hasChanges = true;
          }
        } catch (_) {
          // Mantener el estado local actual si ocurre un error transitorio de red o permisos
        }
      }),
    );

    if (hasChanges) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final encoded = updatedList.map((e) => e.toJson()).toList();
        await prefs.setString(_keyHistory, jsonEncode(encoded));
      } catch (_) {}
    }

    return SuggestionSyncResult(
      suggestions: updatedList,
      newlyApprovedCollections: newlyApprovedCollections,
    );
  }
}
