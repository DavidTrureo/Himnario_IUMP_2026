import 'dart:convert';
import 'dart:io';

import '../lib/core/services/spanish_grammar_corrector.dart';

void main() {
  print('=== APLICANDO CORRECCIONES GRAMATICALES Y TILDES A TODAS LAS COLECCIONES ===\n');
  processFile('assets/json/special_hymns.json', 'Alabanzas Especiales');
  processFile('assets/json/coros.json', 'Coros de Avivamiento');
  processFile('assets/json/hymns.json', 'Himnos IUMP');
  print('\n¡Proceso de corrección gramatical completado con éxito!');
}

void processFile(String path, String label) {
  final file = File(path);
  if (!file.existsSync()) return;

  final List<dynamic> list = json.decode(file.readAsStringSync());
  int modifiedCount = 0;
  int totalAdjustments = 0;

  for (int i = 0; i < list.length; i++) {
    final Map<String, dynamic> item = Map<String, dynamic>.from(list[i]);
    final title = item['title']?.toString() ?? '';
    final lyrics = item['lyrics']?.toString() ?? '';

    final res = SpanishGrammarCorrector.correctText(title: title, lyrics: lyrics);
    if (res.title != title || res.lyrics != lyrics) {
      item['title'] = res.title;
      item['lyrics'] = res.lyrics;
      list[i] = item;
      modifiedCount++;
      totalAdjustments += res.correctionsCount;
    }
  }

  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(list));
  print('[$label]: $modifiedCount de ${list.length} cantos fueron acentuados y corregidos ($totalAdjustments tildes/mayúsculas aplicadas).');
}
