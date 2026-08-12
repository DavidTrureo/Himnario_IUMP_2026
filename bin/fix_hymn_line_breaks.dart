import 'dart:convert';
import 'dart:io';

void main() {
  print('=== RESTRUCTURANDO LINE BREAKS EN COLECCIONES ===\n');
  processFile('assets/json/special_hymns.json', 'Alabanzas Especiales');
  processFile('assets/json/coros.json', 'Coros de Avivamiento');
  processFile('assets/json/hymns.json', 'Himnos IUMP');
  print('\n¡Proceso de reestructuración completado con éxito!');
}

void processFile(String path, String label) {
  final file = File(path);
  if (!file.existsSync()) return;

  final List<dynamic> list = json.decode(file.readAsStringSync());
  int fixedCount = 0;

  for (int i = 0; i < list.length; i++) {
    final Map<String, dynamic> item = Map<String, dynamic>.from(list[i]);
    final String lyrics = item['lyrics']?.toString() ?? '';
    final String cleaned = cleanAndStructureLyrics(lyrics);

    if (cleaned != lyrics) {
      item['lyrics'] = cleaned;
      list[i] = item;
      fixedCount++;
    }
  }

  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(list));
  print('[$label]: $fixedCount de ${list.length} cantos fueron reestructurados y corregidos.');
}

String cleanAndStructureLyrics(String raw) {
  if (raw.trim().isEmpty) return raw;

  String text = raw.replaceAll('\u00A0', ' ');

  // 1. Normalizar saltos de línea Windows / Mac
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // 2. Normalizar encabezados comunes de Secciones y Coros
  text = text.replaceAll(RegExp(r'\(coro\):?', caseSensitive: false), '\n\nCORO:\n');
  text = text.replaceAll(RegExp(r'coro:', caseSensitive: false), '\n\nCORO:\n');
  text = text.replaceAll(RegExp(r'final:', caseSensitive: false), '\n\nFINAL:\n');
  text = text.replaceAll(RegExp(r'introducci[oó]n:?', caseSensitive: false), '\n\n(Introducción)\n');

  // 3. Separar palabras pegadas por minúscula + Mayúscula (CamelCase pegado)
  // Ej: "soledadVagando" -> "soledad\nVagando", "imborrableDel" -> "imborrable\nDel"
  text = text.replaceAllMapped(
    RegExp(r'([a-záéíóúñ])([A-ZÁÉÍÓÚÑ])'),
    (m) => '${m[1]}\n${m[2]}',
  );

  // 4. Separar signos de puntuación pegados a la siguiente palabra en Mayúscula
  // Ej: "amor divino Huella" -> "amor divino\nHuella", "Nazareno marcando"
  text = text.replaceAllMapped(
    RegExp(r'([,\.\!\?\)])\s*([A-ZÁÉÍÓÚÑ]|//|\d+\.|\[)'),
    (m) => '${m[1]}\n${m[2]}',
  );

  // 5. Separar barras de repetición '//'
  text = text.replaceAllMapped(
    RegExp(r'([^\n])(//)'),
    (m) => '${m[1]}\n//',
  );
  text = text.replaceAllMapped(
    RegExp(r'(//)([^\n/])'),
    (m) => '//\n${m[2]}',
  );

  // 6. Separar números de estrofa pegados (ej: "1.En" -> "1. En", "2.Sobre" -> "\n2. Sobre")
  text = text.replaceAllMapped(
    RegExp(r'(\d+\.)([A-ZÁÉÍÓÚÑa-záéíóúñ\[])'),
    (m) => '${m[1]} ${m[2]}',
  );
  text = text.replaceAllMapped(
    RegExp(r'([^\n])(\d+\.\s*)'),
    (m) => '${m[1]}\n${m[2]}',
  );

  // 7. Dividir líneas excesivamente largas por pausas lógicas si superan 70 caracteres
  final rawLines = text.split('\n');
  final List<String> formattedLines = [];

  for (String line in rawLines) {
    line = line.trim();
    if (line.isEmpty) {
      if (formattedLines.isNotEmpty && formattedLines.last.isNotEmpty) {
        formattedLines.add('');
      }
      continue;
    }

    if (line.length > 70) {
      // Intentar dividir por conectores o palabras clave si no hay puntuación
      final sublines = splitLongLine(line);
      formattedLines.addAll(sublines);
    } else {
      formattedLines.add(line);
    }
  }

  // Clean extra blank lines
  final result = formattedLines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return result;
}

List<String> splitLongLine(String line) {
  if (line.length <= 70) return [line];

  // Si la línea contiene acordes [DO], partir antes de cada acorde si la sublínea acumulada es larga
  final List<String> result = [];
  final words = line.split(' ');
  String current = '';

  for (int i = 0; i < words.length; i++) {
    final word = words[i];

    if (current.isNotEmpty && (current.length + word.length + 1) > 55) {
      // Si la palabra empieza con mayúscula, acorde o número, cortar aquí
      if (word.startsWith('[') || word.startsWith('//') || (word.isNotEmpty && word[0] == word[0].toUpperCase() && word[0] != word[0].toLowerCase())) {
        result.add(current.trim());
        current = word;
        continue;
      }
    }

    if (current.isEmpty) {
      current = word;
    } else {
      current += ' $word';
    }
  }

  if (current.isNotEmpty) {
    result.add(current.trim());
  }

  return result.isNotEmpty ? result : [line];
}
