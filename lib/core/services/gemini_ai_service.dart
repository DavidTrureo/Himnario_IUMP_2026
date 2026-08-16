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
        final promptText = '''Eres un corrector ortográfico y literario experto en poesía y métrica de himnos cristianos.
DEBES ANALIZAR LA TOTALIDAD DE CADA ESTROFA para entender el contexto semántico completo ANTES de aplicar cualquier corrección. No trates cada línea de forma aislada.

TÍTULO:
$currentTitle

LETRA:
$currentLyrics

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
}
