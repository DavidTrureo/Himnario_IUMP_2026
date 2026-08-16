import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Por favor, proporciona tu API KEY de Gemini como argumento:');
    print('Ejemplo: dart run bin/process_all_with_gemini.dart TU_API_KEY');
    return;
  }

  final apiKey = args.first;
  final files = [
    'assets/json/special_hymns.json',
    'assets/json/coros.json',
    'assets/json/hymns.json'
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;

    print('\nProcesando $path...');
    final List<dynamic> list = json.decode(file.readAsStringSync());
    bool updated = false;

    for (int i = 0; i < list.length; i++) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(list[i]);
      final title = item['title']?.toString() ?? '';
      final lyrics = item['lyrics']?.toString() ?? '';

      print('Analizando: $title (${i + 1}/${list.length})');

      try {
        final result = await _callGemini(apiKey, title, lyrics);
        if (result != null && (result['title'] != title || result['lyrics'] != lyrics)) {
          item['title'] = result['title'];
          item['lyrics'] = result['lyrics'];
          list[i] = item;
          updated = true;
          print('  -> Corregido.');
          
          // Guardar cada 5 correcciones para no perder el progreso
          if (updated) {
            file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(list));
          }
        } else {
          print('  -> Sin cambios.');
        }
      } catch (e) {
        print('  -> Error: $e');
      }

      // Evitar límite de 15 RPM de la capa gratuita de Gemini (1 petición cada 4 segundos)
      await Future.delayed(const Duration(milliseconds: 4100));
    }

    if (updated) {
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(list));
      print('Archivo $path guardado.');
    }
  }
  print('\nProceso completo.');
}

Future<Map<String, String>?> _callGemini(String apiKey, String title, String lyrics) async {
  final promptText = '''Eres un corrector ortográfico y literario experto en poesía y métrica de himnos cristianos.
DEBES ANALIZAR LA TOTALIDAD DE CADA ESTROFA para entender el contexto semántico completo ANTES de aplicar cualquier corrección. No trates cada línea de forma aislada.

TÍTULO:
$title

LETRA:
$lyrics

REGLAS ESTRICTAS OBLIGATORIAS:
1. PUNTUACIÓN POÉTICA LÓGICA: DEBES ELIMINAR los puntos finales (.) y comas al final de los versos si la idea continúa en el siguiente verso (encabalgamiento poético). Solo deja o agrega puntos finales cuando termine verdaderamente la idea o la estrofa. BAJO NINGÚN MOTIVO dejes un punto final al final de cada línea de forma sistemática.
2. ANÁLISIS DE CONTEXTO SEMÁNTICO (ACENTUACIÓN DIACRÍTICA Y TIEMPOS VERBALES):
   - "amo" (presente, ej: "yo te amo") vs "amó" (pasado, ej: "Él me amó"). Revisa si la frase habla de la historia de Jesús en la cruz o del sentir actual del creyente.
   - "Él" / "Tú" / "Mí" (pronombre referente a Dios) siempre con tilde y mayúscula frente a "el" / "tu" / "mi" (posesivos/artículos).
   - "más" (cantidad) frente a "mas" (conjunción "pero").
3. ESTRUCTURA INTACTA: Mantén la estructura de líneas y estrofas original. Si hay un "1.", "CORO:", etc., respétalo.
4. MAYÚSCULAS: La primera letra de cada verso debe ir en Mayúscula obligatoriamente, al igual que los nombres divinos (Dios, Señor, Rey, Salvador).
5. ACORDES INTACTOS: Mantén intactas las etiquetas de acordes como [DO]. NO elimines ni alteres ningún corchete.
6. ORTOGRAFÍA Y SIGNOS INTERNOS: Corrige y agrega las tildes (´), signos de interrogación (¿?) y exclamación (¡!) correspondientes. Si dentro de un verso hace falta una coma (,), o si en lugar de un punto corresponde un punto y coma (;), cámbialo.
7. FORMATO JSON: Retorna estrictamente un objeto JSON con los campos "title" y "lyrics". No agregues bloques markdown ni explicaciones.

JSON esperado:
{
  "title": "$title",
  "lyrics": "Letra corregida contextualmente"
}''';

  final requestBody = jsonEncode({
    'contents': [{'parts': [{'text': promptText}]}],
    'generationConfig': {'responseMimeType': 'application/json'}
  });

  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');
  
  final res = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: requestBody,
  );

  if (res.statusCode == 200) {
    final data = jsonDecode(res.body);
    final text = data['candidates'][0]['content']['parts'][0]['text'];
    var cleanText = text.trim();
    if (cleanText.startsWith('```json')) cleanText = cleanText.substring(7);
    else if (cleanText.startsWith('```')) cleanText = cleanText.substring(3);
    if (cleanText.endsWith('```')) cleanText = cleanText.substring(0, cleanText.length - 3);
    final parsed = jsonDecode(cleanText.trim());
    return {
      'title': parsed['title']?.toString() ?? title,
      'lyrics': parsed['lyrics']?.toString() ?? lyrics,
    };
  }
  return null;
}
