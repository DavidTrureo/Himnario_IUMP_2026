import 'dart:convert';
import 'dart:io';

Map<String, String> parseToneComponents(String rawTone) {
  String clean = rawTone.replaceAll(RegExp(r'^TONO:\s*', caseSensitive: false), '').trim();
  if (clean.isEmpty) return {'toneNote': '', 'beats': '', 'timeSignature': ''};

  String timeSignature = '';
  String beats = '';
  String toneNote = '';

  // 1. Métrica entre paréntesis (ej: "(2/4)") o libre (ej: "2/4")
  final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(clean);
  if (parenMatch != null) {
    timeSignature = parenMatch.group(1)!.trim();
    clean = clean.replaceFirst(parenMatch.group(0)!, '').trim();
  } else {
    final tsMatch = RegExp(r'(\d+\s*/\s*\d+)').firstMatch(clean);
    if (tsMatch != null) {
      timeSignature = tsMatch.group(1)!.replaceAll(' ', '');
      clean = clean.replaceFirst(tsMatch.group(0)!, '').trim();
    }
  }

  // 2. Tiempos (ej: "2 TIEMPOS", "2 Tiempos", "2T")
  final timesMatch = RegExp(r'(\d+)\s*(?:TIEMPOS|TIEMPO|T)?', caseSensitive: false).firstMatch(clean);
  if (timesMatch != null) {
    final possibleBeats = timesMatch.group(1)!;
    if (RegExp(r'TIEMPOS?|T\b', caseSensitive: false).hasMatch(clean)) {
      beats = possibleBeats;
      clean = clean.replaceFirst(RegExp(r'(\d+)\s*(?:TIEMPOS|TIEMPO|T)?', caseSensitive: false), '').trim();
    }
  }

  // 3. Tono (lo que queda limpiando barras, guiones, la palabra "TIEMPOS", etc.)
  toneNote = clean
      .replaceAll('|', '')
      .replaceAll('/', '')
      .replaceAll(RegExp(r'\bTIEMPOS?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (beats.isEmpty && timesMatch != null) {
    final possible = timesMatch.group(1)!;
    if (toneNote.contains(possible)) {
      final toneWithoutDigits = toneNote.replaceAll(RegExp(r'\d+'), '').trim();
      if (toneWithoutDigits.isNotEmpty) {
        beats = possible;
        toneNote = toneWithoutDigits;
      }
    }
  }

  return {
    'toneNote': toneNote.toUpperCase(),
    'beats': beats,
    'timeSignature': timeSignature,
  };
}

String buildToneString({required String toneNote, required String beats, required String timeSignature}) {
  final cleanTone = toneNote.trim();
  final cleanBeats = beats.trim();
  final cleanSignature = timeSignature.trim();

  if (cleanTone.isEmpty && cleanBeats.isEmpty && cleanSignature.isEmpty) return '';

  final buffer = StringBuffer();
  if (cleanTone.isNotEmpty) buffer.write(cleanTone);

  if (cleanBeats.isNotEmpty) {
    if (buffer.isNotEmpty) buffer.write(' | ');
    buffer.write('$cleanBeats TIEMPOS');
  }

  if (cleanSignature.isNotEmpty) {
    if (buffer.isNotEmpty) {
      if (cleanBeats.isNotEmpty) {
        buffer.write(' ($cleanSignature)');
      } else {
        buffer.write(' | $cleanSignature');
      }
    } else {
      buffer.write(cleanSignature);
    }
  }

  return buffer.toString();
}

void processFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return;

  final content = file.readAsStringSync();
  final List<dynamic> jsonList = jsonDecode(content);

  int updatedCount = 0;
  for (var item in jsonList) {
    if (item is Map<String, dynamic>) {
      final rawTone = item['tone']?.toString() ?? '';
      final parsed = parseToneComponents(rawTone);
      
      item['toneNote'] = parsed['toneNote'];
      item['beats'] = parsed['beats'];
      item['timeSignature'] = parsed['timeSignature'];
      item['tone'] = buildToneString(
        toneNote: parsed['toneNote']!,
        beats: parsed['beats']!,
        timeSignature: parsed['timeSignature']!,
      );
      updatedCount++;
    }
  }

  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(jsonList));
  print('Updated $updatedCount items in $path');
}

void main() {
  processFile('assets/json/hymns.json');
  processFile('assets/json/coros.json');
  processFile('assets/json/special_hymns.json');
  print('Migration completed successfully!');
}
