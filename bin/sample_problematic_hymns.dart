import 'dart:convert';
import 'dart:io';

void main() {
  sampleFile('assets/json/special_hymns.json', 'Alabanzas Especiales');
  sampleFile('assets/json/coros.json', 'Coros de Avivamiento');
}

void sampleFile(String path, String label) {
  final file = File(path);
  final List<dynamic> list = json.decode(file.readAsStringSync());

  print('=== MUESTRAS DE $label ===\n');
  int count = 0;
  for (final item in list) {
    final map = item as Map<String, dynamic>;
    final title = map['title'] ?? '';
    final lyrics = map['lyrics']?.toString() ?? '';
    final lines = lyrics.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.length <= 2 || lyrics.length > 200 && lines.length <= 3) {
      print('ID: ${map['id']} | TÍTULO: $title');
      print('LETRA:\n$lyrics\n');
      print('--------------------------------------------------\n');
      count++;
      if (count >= 5) break;
    }
  }
}
