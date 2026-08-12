import 'dart:convert';
import 'dart:io';

void main() {
  checkFile('assets/json/special_hymns.json', 'Especiales');
  checkFile('assets/json/coros.json', 'Coros');
}

void checkFile(String path, String label) {
  final list = json.decode(File(path).readAsStringSync()) as List;
  print('=== $label ===');
  for (final item in list) {
    final lyrics = (item['lyrics'] ?? '').toString().trim();
    if (lyrics.isNotEmpty && !lyrics.contains('\n')) {
      print('ID: ${item['id']} | TÍTULO: ${item['title']}');
      print('LETRA: $lyrics\n');
    }
  }
}
