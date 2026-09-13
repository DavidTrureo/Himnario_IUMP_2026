import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'spanish_grammar_corrector.dart';

class GeminiAiService {
  static const String _keyPref = 'gemini_api_key';

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPref) ?? '';
  }

  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, apiKey.trim());
  }

  static Future<String?> showApiKeyInputDialog(BuildContext context, {String? reason}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text('Clave API de Gemini', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reason ?? 'Esta app utiliza Inteligencia Artificial (Gemini API). Ingresa tu API Key para continuar.',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Obtener API Key (Gratis)'),
                onPressed: () async {
                  final url = Uri.parse('https://aistudio.google.com/app/apikey');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint('Error launching url: $e');
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'API Key (ej: AIzaSy...)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isNotEmpty) {
                await saveApiKey(key);
                if (context.mounted) Navigator.pop(context, key);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Analiza y auto-corrige la ortografía, acentuación (tildes), comas, puntos y mayúsculas
  /// mediante el Motor Gramatical Local + Asistencia de IA Gemini y abre un Resumen de Comparación.
  static Future<Map<String, String>?> correctHymnGrammar({
    required BuildContext context,
    required String title,
    required String lyrics,
  }) async {
    // 1. Ejecutar de inmediato el Motor Gramatical Español Determinístico
    final localResult = SpanishGrammarCorrector.correctText(
      title: title,
      lyrics: lyrics,
    );

    String currentTitle = localResult.title;
    String currentLyrics = localResult.lyrics;
    int totalCorrections = localResult.correctionsCount;

    String apiKey = await getApiKey();

    // Mostrar modal con indicador de progreso
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              const CircularProgressIndicator(color: Colors.amber),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Puliendo Ortografía y Tildes...',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aplicando tildes obligatorias, vocativos (¡Oh, Señor!), comas y acordes intactos.',
                      style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Si hay clave API, consultar Gemini para perfeccionamiento contextual adicional
    if (apiKey.isNotEmpty) {
      try {
        final promptText = '''Eres un corrector ortográfico y literario experto en poesía y métrica de himnos cristianos.
DEBES ANALIZAR LA TOTALIDAD DE CADA ESTROFA para entender el contexto semántico completo ANTES de aplicar cualquier corrección. No trates cada línea de forma aislada.

TÍTULO:
$currentTitle

LETRA:
$currentLyrics

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
  "title": "$currentTitle",
  "lyrics": "Letra corregida contextualmente"
}
''';

        final requestBody = jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': promptText}
              ]
            }
          ]
        });

        http.Response? response;
        final modelsToTry = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-2.0-flash-exp', 'gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-pro-vision'];

        for (final model in modelsToTry) {
          try {
            final url = Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
            final res = await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            ).timeout(const Duration(seconds: 10));

            if (res.statusCode == 200) {
              response = res;
              break;
            }
          } catch (_) {}
        }

        if (response != null && response.statusCode == 200) {
          final jsonRes = jsonDecode(response.body);
          final candidates = jsonRes['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              String rawText = parts[0]['text']?.toString() ?? '';
              rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();

              final parsed = jsonDecode(rawText);
              if (parsed is Map) {
                final aiTitle = parsed['title']?.toString().trim() ?? currentTitle;
                final aiLyrics = parsed['lyrics']?.toString().trim() ?? currentLyrics;
                if (aiTitle.isNotEmpty) currentTitle = aiTitle.toUpperCase();
                if (aiLyrics.isNotEmpty) currentLyrics = aiLyrics;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('>>> Error en consulta remota Gemini: $e');
      }
    }

    // Pasar el resultado final por el corrector local para asegurar 100% de tildes
    final doubleCheck = SpanishGrammarCorrector.correctText(
      title: currentTitle,
      lyrics: currentLyrics,
    );

    currentTitle = doubleCheck.title;
    currentLyrics = doubleCheck.lyrics;
    totalCorrections += doubleCheck.correctionsCount;

    // Cerrar modal de carga
    if (context.mounted) {
      Navigator.pop(context);
    }

    // 2. Abrir el Modal de Resumen de Cambios (Antes vs Después)
    return showGrammarReviewDialog(
      context: context,
      originalTitle: title,
      originalLyrics: lyrics,
      suggestedTitle: currentTitle,
      suggestedLyrics: currentLyrics,
      correctionsCount: totalCorrections,
    );
  }

  /// Muestra un modal interactivo con la comparación "Antes vs Después (Sugerido)"
  static Future<Map<String, String>?> showGrammarReviewDialog({
    required BuildContext context,
    required String originalTitle,
    required String originalLyrics,
    required String suggestedTitle,
    required String suggestedLyrics,
    required int correctionsCount,
  }) async {
    if (!context.mounted) return null;

    final bool hasChanges = originalTitle != suggestedTitle || originalLyrics != suggestedLyrics;

    if (!hasChanges) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(child: Text('Ortografía Impecable', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(
            'El texto ya cuenta con una excelente ortografía y puntuación según las reglas establecidas. No se requiere ninguna corrección adicional.',
            style: GoogleFonts.nunito(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return null;
    }

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen de Cambios',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'Se detectaron sugerencias de mejora ($correctionsCount ajustes)',
                      style: GoogleFonts.nunito(fontSize: 12, color: Colors.teal[700], fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compara cómo estaba antes y cómo quedará después:',
                    style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 14),

                  // 1. Comparación de Título
                  if (originalTitle != suggestedTitle) ...[
                    Text('TÍTULO SUGERIDO:', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: Text(
                        suggestedTitle,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.teal[900]),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 2. Tarjetas Comparativas (Original vs Propuesta)
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TabBar(
                          labelColor: Theme.of(context).primaryColor,
                          unselectedLabelColor: Colors.grey[600],
                          indicatorColor: Theme.of(context).primaryColor,
                          tabs: const [
                            Tab(text: 'Propuesta Corregida ✨'),
                            Tab(text: 'Texto Original'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 240,
                          child: TabBarView(
                            children: [
                              // Vista Propuesta Corregida
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    suggestedLyrics,
                                    style: GoogleFonts.nunito(fontSize: 13, height: 1.4, color: Colors.black87),
                                  ),
                                ),
                              ),
                              // Vista Texto Original
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    originalLyrics,
                                    style: GoogleFonts.nunito(fontSize: 13, height: 1.4, color: Colors.grey[800]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text(
                'Descartar',
                style: GoogleFonts.nunito(color: Colors.grey[700], fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                'Aplicar Correcciones',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.pop(dialogContext, {
                  'title': suggestedTitle,
                  'lyrics': suggestedLyrics,
                });
              },
            ),
          ],
        );
      },
    );
  }

  /// Analiza una imagen (fotografía de partitura o guía de acordes) y extrae la información musical
  static Future<Map<String, dynamic>?> transcribeSheetMusic(String base64Image, {String mimeType = 'image/jpeg'}) async {
    String apiKey = await getApiKey();
    if (apiKey.isEmpty) return null;

    final promptText = '''Eres un experto transcriptor. Analiza la imagen adjunta, que contiene la letra de un canto, probablemente con acordes escritos arriba de las palabras.
Extrae la información y devuélvela ESTRICTAMENTE en formato JSON:
1. "title": Título de la canción (o "Título Desconocido").
2. "key": Tonalidad (ej: "G Mayor", "Am", "Desconocida").
3. "timeSignature": Métrica (ej: "4/4", "Desconocida").
4. "lyrics": Extrae ÚNICAMENTE LA LETRA del canto. IGNORA COMPLETAMENTE TODOS LOS ACORDES que aparezcan arriba de las palabras (por ejemplo, ignora letras sueltas como C, D, Em, LAm, DO, RE, SOL, etc. que estén solas en una línea superior). Tu objetivo es devolver un texto limpio, ordenado en estrofas, que contenga solo el texto cantable. No incluyas ningún corchete ni acorde en el resultado.

JSON esperado:
{
  "title": "...",
  "key": "...",
  "timeSignature": "...",
  "lyrics": "..."
}''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': promptText},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
      }
    });

    final modelsToTry = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-2.0-flash-exp', 'gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-pro-vision'];
    
    List<String> errors = [];

    for (final model in modelsToTry) {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'];
          
          var cleanText = text.toString().trim();
          if (cleanText.startsWith('```json')) {
            cleanText = cleanText.substring(7);
          } else if (cleanText.startsWith('```')) {
            cleanText = cleanText.substring(3);
          }
          if (cleanText.endsWith('```')) {
            cleanText = cleanText.substring(0, cleanText.length - 3);
          }
          
          final parsed = jsonDecode(cleanText.trim());
          return {
            'title': parsed['title']?.toString() ?? '',
            'key': parsed['key']?.toString() ?? '',
            'timeSignature': parsed['timeSignature']?.toString() ?? '',
            'lyrics': parsed['lyrics']?.toString() ?? '',
          };
        } else {
          errors.add('$model failed: ${response.body}');
        }
      } catch (e) {
        errors.add('$model exception: $e');
      }
    }
    
    String availableModels = "No se pudieron obtener";
    try {
      final modelsUrl = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
      final modelsRes = await http.get(modelsUrl);
      if (modelsRes.statusCode == 200) {
        final data = jsonDecode(modelsRes.body);
        final models = data['models'] as List?;
        if (models != null) {
          availableModels = models.map((m) => m['name']).join(', ');
        }
      } else {
        availableModels = "Error ${modelsRes.statusCode}: ${modelsRes.body}";
      }
    } catch (_) {}
    
    throw Exception('Fallaron todos los modelos. \nModelos disponibles para tu Clave API: $availableModels\n\nErrores:\n' + errors.join('\n'));
  }

  static Future<String?> generateText(String prompt) async {
    try {
      final apiKey = await getApiKey();
      if (apiKey.isEmpty) throw Exception('API Key no configurada');

      final requestBody = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      });

      http.Response? response;
      final modelsToTry = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-2.0-flash-exp', 'gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-pro'];

      for (final model in modelsToTry) {
        if (response != null && response.statusCode == 200) break;
        final endpoints = ['v1beta', 'v1'];
        for (final endpoint in endpoints) {
          try {
            final url = Uri.parse('https://generativelanguage.googleapis.com/$endpoint/models/$model:generateContent?key=$apiKey');
            final res = await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            ).timeout(const Duration(seconds: 15));
            
            if (res.statusCode == 200) {
              response = res;
              break;
            }
          } catch (_) {}
        }
      }

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String?;
          }
        }
      }
      return null;
    } catch (e) {
      print('Error en generateText: $e');
      return null;
    }
  }

}