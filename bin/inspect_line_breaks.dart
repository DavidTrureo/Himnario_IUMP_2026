import 'dart:convert';
import 'dart:io';

void main() {
  inspectFile('assets/json/special_hymns.json', 'Alabanzas Especiales');
  inspectFile('assets/json/coros.json', 'Coros de Avivamiento');
  inspectFile('assets/json/hymns.json', 'Himnos IUMP');
}

void inspectFile(String path, String label) {
  final file = File(path);
  if (!file.existsSync()) {
    print('Archivo no encontrado: $path');
    return;
  }

  final content = file.readAsStringSync();
  final List<dynamic> list = json.decode(content);

  int longLineCount = 0;
  int singleLineLyricsCount = 0;
  int total = list.length;

  for (final item in list) {
    final Map<String, dynamic> map = item as Map<String, dynamic>;
    final lyrics = map['lyrics']?.toString() ?? '';
    final lines = lyrics.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.length <= 1) {
      singleLineLyricsCount++;
    }

    bool hasLongLine = false;
    for (final line in lines) {
      if (line.length > 80) {
        hasLongLine = true;
        break;
      }
    }
    if (hasLongLine) {
      longLineCount++;
    }
  }

  print('=== $label ($path) ===');
  print('Total cantos: $total');
  print('Cantos con 1 sola línea (sin saltos): $singleLineLyricsCount');
  print('Cantos con líneas muy largas (>80 caracteres): $longLineCount\n');
}
