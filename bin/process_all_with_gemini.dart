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
1. LECTURA COMPLETA Y REGLAS RAE: Lee el canto COMPLETO primero para entender el contexto global. Luego, aplica estrictamente las normas ortográficas y de puntuación de la Real Academia Española (RAE) para corregir tildes, comas, puntos y signos de interrogación/exclamación (¿? ¡!) donde sea necesario.
2. PUNTUACIÓN POÉTICA Y PUNTOS FINALES: PROHIBIDO poner un punto final (.) al final de cada línea de forma sistemática. Solo pon un punto final cuando la oración o estrofa realmente termine gramaticalmente. Si la idea continúa en la siguiente línea (encabalgamiento), NO pongas punto ni coma al final de esa línea.
3. PRONOMBRES Y DIACRÍTICOS (¡CRÍTICO!):
   - Referencia a DIOS: "Él", "Tú", "Mí" (Siempre con Tilde y Mayúscula).
   - Referencia a un HUMANO: "él", "tú", "mí" (Con tilde, pero en minúscula, salvo que sea la primera palabra de la línea).
   - Posesivos o Artículos: "el", "tu", "mi" (Sin tilde y en minúscula).
   - Tiempos verbales: Diferencia bien el pasado ("Él me amó", "salvó") del presente ("yo le amo", "salvo").
4. ESTRUCTURA INTACTA: Mantén la estructura de líneas y estrofas original. Si hay un "1.", "CORO:", etc., respétalo.
5. MAYÚSCULAS: La primera letra de CADA verso/línea debe ir en Mayúscula obligatoriamente, sin importar si es pronombre o palabra común. También los nombres divinos (Dios, Señor, Rey, Salvador).
6. ACORDES INTACTOS: Mantén intactas las etiquetas de acordes como [DO]. NO elimines ni alteres ningún corchete.
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
