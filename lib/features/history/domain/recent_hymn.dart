import 'dart:convert';

/// Representa un canto entonado registrado en el historial inteligente local.
class RecentHymn {
  final String key; // Identificador canónico: ej. 'iump-1', 'especiales-45'
  final DateTime timestamp;
  final String? tone;

  const RecentHymn({
    required this.key,
    required this.timestamp,
    this.tone,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'timestamp': timestamp.toIso8601String(),
    if (tone != null && tone!.isNotEmpty) 'tone': tone,
  };

  factory RecentHymn.fromJson(Map<String, dynamic> json) => RecentHymn(
    key: json['key'] as String? ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    tone: json['tone'] as String?,
  );

  String get collection {
    final parts = key.split('-');
    return parts.isNotEmpty ? parts[0] : 'iump';
  }

  int get id {
    final parts = key.split('-');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  }
}

