import 'dart:convert';
import 'package:flutter/material.dart';
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

  static Future<String?> showApiKeyInputDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Clave API de Gemini', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para potenciar la Inteligencia Artificial con escaneo de fotos y afinación contextual avanzada, ingresa tu API Key gratuita de Google Gemini.',
              style: GoogleFonts.nunito(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key (ej: AIzaSy...)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Omitir (Usar Motor Local)'),
          ),
          ElevatedButton(
            onPressed: () {
              final key = controller.text.trim();
              if (key.isNotEmpty) {
                saveApiKey(key);
                Navigator.pop(context, key);
              }
            },
            child: const Text('Guardar Clave'),
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
        final promptText = '''Eres un corrector ortográfico y literario experto en himnos, cantos y alabanzas cristianas en español.
Analiza y perfecciona la ortografía, tildes, vocativos y puntuación del siguiente título y letra:

TÍTULO:
$currentTitle

LETRA:
$currentLyrics

REGLAS ESTRICTAS OBLIGATORIAS:
1. ANÁLISIS DE CONTEXTO SEMÁNTICO (ACENTUACIÓN DIACRÍTICA Y TIEMPOS VERBALES):
   Distingue con rigor semántico el significado de las palabras según su entorno en la frase:
   - "amo" (del verbo amar en presente, ej: "yo te amo", "cuanto te amo") frente a "amó" (verbo amar en pasado, ej: "Él me amó", "Jesús nos amó").
   - "Él" (pronombre personal referente a Dios o Jesús, ej: "Él vive", "confío en Él") frente a "el" (artículo masculino, ej: "el camino", "el Salvador").
   - "Tú" (pronombre referente a Dios, ej: "Tú estás conmigo") frente a "tu" (posesivo, ej: "tu amor me hizo nacer").
   - "más" (adverbio de cantidad, ej: "más, más quiero sentirte") frente a "mas" (conjunción que equivale a 'pero', ej: "mas yo sé que resucitó").
   - "está" (del verbo estar, ej: "Tú estás conmigo") frente a "esta" (demostrativo, ej: "esta vida").
2. VOCATIVOS Y PUNTUACIÓN: Asegura vocativos correctos como ¡Oh, Señor!, ¡Oh, Dios! y comas/puntos de verso.
3. CONSERVA ACORDES INTACTOS: Mantiene intactas las etiquetas entre corchetes como [DO], [SOL/SI], [RE7], etc. NO elimines ni alteres ningún corchete.
4. MAYÚSCULAS: Primera letra de cada verso y nombres divinos (Dios, Jesús, Espíritu Santo, Señor) siempre en Mayúscula.
5. FORMATO JSON: Retorna estrictamente un objeto JSON con los campos "title" y "lyrics". No agregues bloques markdown ni explicaciones.

JSON esperado:
{
  "title": "$currentTitle",
  "lyrics": "Letra perfectamente acentuada y corregida"
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
        final modelsToTry = ['gemini-2.0-flash', 'gemini-1.5-flash'];

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✨ El texto ya cuenta con una ortografía y acentuación impecables.',
            style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}
