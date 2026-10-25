import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'spanish_grammar_corrector.dart';
import '../../features/hymns/domain/hymn.dart';

class GeminiAiService {
  static const String _keyPref = 'gemini_api_key';

  /// Clave oficial del servidor para que los usuarios no tengan que configurar nada
  static const String defaultServerApiKey =
      'AQ.Ab8RN6LMJy9J1QN_8lmyiI0Sq57kavrWWN8O2ST8b07Qbf1eKQ';

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = prefs.getString(_keyPref)?.trim() ?? '';
    if (customKey.isNotEmpty) {
      return customKey;
    }
    return defaultServerApiKey;
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

    String apiKey = (await getApiKey()).trim();
    if (apiKey.isEmpty && context.mounted) {
      final inputKey = await showApiKeyInputDialog(
        context,
        reason:
            'Para corregir tildes, comas, puntuación y mayúsculas con los modelos más avanzados de IA (Gemini 2.5 / 2.0), ingresa tu API Key gratuita de Google Studio:',
      );
      if (inputKey != null && inputKey.trim().isNotEmpty) {
        apiKey = inputKey.trim();
        await saveApiKey(apiKey);
      }
    }

    bool isAiAssisted = false;
    bool geminiFailed = false;
    bool isProgressShown = false;

    // Si hay clave API, consultar Gemini para perfeccionamiento contextual adicional
    if (apiKey.isNotEmpty) {
      if (context.mounted) {
        isProgressShown = true;
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

      try {
        // 1. Intentar primero mediante Cloud Function (resuelve 100% de CORS en Web y usa Gemini 2.5/2.0 en el backend)
        bool remoteSuccess = false;
        try {
        final callable = FirebaseFunctions.instance.httpsCallable('correctGrammarWithAi');
        final cfRes = await callable.call({
          'title': currentTitle,
          'lyrics': currentLyrics,
          'apiKey': apiKey,
        }).timeout(const Duration(seconds: 30));

        final data = cfRes.data;
        if (data is Map && data['success'] == true) {
          final aiTitle = data['title']?.toString().trim() ?? currentTitle;
          final aiLyrics = data['lyrics']?.toString().trim() ?? currentLyrics;
          if (aiTitle.isNotEmpty) currentTitle = aiTitle.toUpperCase();
          if (aiLyrics.isNotEmpty) currentLyrics = aiLyrics;
          isAiAssisted = true;
          remoteSuccess = true;
          debugPrint('>>> Corrección IA completada con éxito vía Cloud Function (${data['modelUsed']})');
        }
      } catch (cfError) {
        debugPrint('Cloud Function no respondió o falló: $cfError. Procediendo a HTTP directo...');
      }

      // 2. Si no respondió la Cloud Function, consultar directamente la API de Google con los modelos más modernos
      if (!remoteSuccess) {
        final promptText = '''Actúa como un corrector de estilo y editor lingüístico experto, aplicando estrictamente las normas ortográficas, gramaticales y de puntuación de la Real Academia Española (RAE). 

Tu tarea es revisar, corregir y formatear la letra de un canto cristiano respetando las siguientes reglas de manera obligatoria:

TÍTULO ORIGINAL:
$currentTitle

LETRA ORIGINAL:
$currentLyrics

REGLAS OBLIGATORIAS:
1. Mayúscula al inicio de cada línea:
   - Toda línea o verso DEBE iniciar siempre con letra mayúscula, sin importar el signo de puntuación de la línea anterior (estilo de versificación).
   - El resto de las palabras de la línea deben ir en minúsculas, salvo las excepciones indicadas en la regla 2.

2. Mayúsculas de respeto y nombres propios:
   - Nombres propios: Nombres de personas, ciudades, países, montes o regiones geográficas siempre inician con mayúscula (ej.: Jonás, Nínive, Jerusalén, Sinaí).
   - Nombres de la Deidad: Todas las personas de la Trinidad y sus nombres propios llevan mayúscula inicial (Dios, Jehová, Yahvé, Señor, Padre, Hijo, Jesús, Cristo, Redentor, Salvador, Espíritu Santo, Consolador).
   - Mayúscula reverencial y pronombres referidos a la Deidad: Escribe con mayúscula los pronombres o adjetivos cuando aludan directamente a Dios o a Cristo (Él, Tú, Tuyo, Santo, Creador, Omnipotente). Excepción estricta: Los pronombres posesivos de tercera persona (su, suyo, suya, sus, suyos) DEBEN ir siempre en minúscula (ej: "su amor", no "Su amor").

3. Acentuación y tildes según contexto (RAE):
   - Analiza el contexto de cada verso para colocar las tildes diacríticas obligatorias (ej.: distinguir «él/el», «tú/tu», «mí/mi», «sí/si», «más/mas», «sé/se», «dé/de»).
   - Elimina tildes innecesarias o desaconsejadas por la RAE (ej.: «solo» y los pronombres demostrativos «este, ese, aquel» van siempre sin tilde; «fe», «dio», «vio», «fue», «fui» no llevan tilde por ser monosílabos).
   - Corrige tiempos verbales conjugados en pasado o futuro (ej.: olvidó, quemó, perdonó, destruyó, costó, cantaré). ESTO ES VITAL.

4. Signos de puntuación (PUNTUACIÓN LIGERA, POÉTICA Y CONTEXTUAL):
   - PRIMERO, lee el canto completo, analiza su contexto y entiende la fluidez de las ideas. Con esa información, gestiona cuidadosamente las puntuaciones (comas, puntos y comas, dos puntos, puntos seguidos).
   - Añade signos de puntuación respetando estrictamente el estilo poético y el sentido de la letra.
   - NO pongas punto final al terminar cada verso a menos que la idea u oración gramatical realmente termine ahí. Es vital dejar el verso sin puntuación al final si la idea continúa en el siguiente verso (encabalgamiento).
   - Usa los puntos (seguidos o finales) PRINCIPALMENTE para separar ideas completas o al terminar una estrofa o coro.
   - Usa comas, puntos y comas, o dos puntos para pausas lógicas breves que den verdadero sentido y fluidez a la lectura.
   - Aplica los signos de interrogación o exclamación (¡!, ¿?) donde correspondan para dar expresividad.
   - Corrige preposiciones incorrectas (ej: "inspirándose a Jehová" -> "inspirándose en Jehová").

5. Estructura y Etiquetas (¡INTOCABLES!):
   - DEBES conservar EXACTAMENTE TODAS las etiquetas estructurales como "CORO:", "FINAL:", "PUENTE:", "1.", "2.", etc.
   - NO las elimines, no las traduzcas, no las modifiques, ni las fusiones con el texto. Mantenlas en su propia línea, con sus saltos de línea originales.

6. Formato de salida (¡MUY IMPORTANTE!):
   - NO incluyas viñetas ni explicaciones.
   - Devuelve ÚNICAMENTE y ESTRICTAMENTE un objeto JSON válido con dos campos: "title" y "lyrics". No agregues bloques markdown ni texto adicional.

JSON esperado:
{
  "title": "El título corregido (mantenlo en mayúsculas)",
  "lyrics": "La letra corregida aplicando todas las reglas anteriores. Conserva los saltos de línea (\n)."
}
''';

        final requestBody = jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': promptText}
              ]
            }
          ],
          'generationConfig': {
            'response_mime_type': 'application/json',
            'temperature': 0.3
          }
        });

        http.Response? response;
        final modelsToTry = [
          {'model': 'gemini-2.5-flash', 'api': 'v1beta'},
          {'model': 'gemini-2.5-flash-lite', 'api': 'v1beta'},
          {'model': 'gemini-2.0-flash', 'api': 'v1beta'},
          {'model': 'gemini-2.5-pro', 'api': 'v1beta'},
          {'model': 'gemini-2.0-flash-lite', 'api': 'v1beta'},
        ];

        List<String> modelErrors = [];
        for (final item in modelsToTry) {
          final model = item['model']!;
          final api = item['api']!;
          try {
            final url = Uri.parse(
                'https://generativelanguage.googleapis.com/$api/models/$model:generateContent?key=$apiKey');
            final res = await http.post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: requestBody,
            ).timeout(const Duration(seconds: 18));

            if (res.statusCode == 200) {
              response = res;
              break;
            } else {
              debugPrint('Gemini corrector intent [$model ($api)]: status ${res.statusCode}');
              modelErrors.add('$model ($api) status ${res.statusCode}');
            }
          } catch (e) {
            debugPrint('Gemini corrector exception [$model ($api)]: $e');
            modelErrors.add('$model ($api) exc: $e');
          }
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
                isAiAssisted = true;
              }
            }
          }
        } else {
          geminiFailed = true;
          debugPrint('>>> Consulta remota Gemini falló: ${modelErrors.join(' | ')}. Se aplicó la corrección ortográfica local.');
        }
      }
      } catch (e) {
        geminiFailed = true;
        debugPrint('>>> Error en consulta remota Gemini: $e. Se aplicó la corrección ortográfica local.');
        // NUNCA inyectar strings de error técnico en las letras de los cantos
      } finally {
        if (isProgressShown && context.mounted) {
          Navigator.pop(context);
        }
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

    // 2. Abrir el Modal de Resumen de Cambios (Antes vs Después)
    if (!context.mounted) return null;
    return showGrammarReviewDialog(
      context: context,
      originalTitle: title,
      originalLyrics: lyrics,
      suggestedTitle: currentTitle,
      suggestedLyrics: currentLyrics,
      correctionsCount: totalCorrections,
      isAiAssisted: isAiAssisted,
      geminiFailed: geminiFailed,
      noApiKey: apiKey.isEmpty,
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
    bool isAiAssisted = false,
    bool geminiFailed = false,
    bool noApiKey = false,
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
              Icon(
                isAiAssisted ? Icons.auto_awesome_rounded : Icons.spellcheck_rounded,
                color: isAiAssisted ? Colors.amber : Colors.teal,
                size: 28,
              ),
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
                      isAiAssisted
                          ? 'Mejora con IA Gemini y Motor RAE ($correctionsCount ajustes)'
                          : 'Corrección Ortográfica RAE ($correctionsCount ajustes)',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: isAiAssisted ? Colors.amber[800] : Colors.teal[700],
                        fontWeight: FontWeight.w600,
                      ),
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
                  if (geminiFailed) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Se aplicó la corrección ortográfica local. La IA de Google no respondió (revisa tu clave de API).',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.amber[200]
                                    : Colors.amber[900],
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () async {
                              Navigator.pop(dialogContext, null);
                              final newKey = await showApiKeyInputDialog(
                                context,
                                reason: 'Actualiza tu Clave API de Google AI Studio:',
                              );
                              if (newKey != null && newKey.isNotEmpty && context.mounted) {
                                correctHymnGrammar(
                                  context: context,
                                  title: originalTitle,
                                  lyrics: originalLyrics,
                                );
                              }
                            },
                            child: const Text('Cambiar Key', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ] else if (noApiKey) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: Colors.teal, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Corrector ortográfico local aplicado (tildes, mayúsculas, vocativos).',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.teal[200]
                                    : Colors.teal[900],
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () async {
                              Navigator.pop(dialogContext, null);
                              final newKey = await showApiKeyInputDialog(
                                context,
                                reason: 'Ingresa tu Clave API de Gemini para habilitar puntuación avanzada con IA:',
                              );
                              if (newKey != null && newKey.isNotEmpty && context.mounted) {
                                correctHymnGrammar(
                                  context: context,
                                  title: originalTitle,
                                  lyrics: originalLyrics,
                                );
                              }
                            },
                            child: const Text('+ Activar IA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    'Compara cómo estaba antes y cómo quedará después:',
                    style: GoogleFonts.nunito(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                  const SizedBox(height: 14),

                  // 1. Comparación de Título
                  if (originalTitle != suggestedTitle) ...[
                    Text('TÍTULO SUGERIDO:', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
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
                          labelColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2DD4BF)
                              : Colors.teal[800],
                          unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
                          indicatorColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2DD4BF)
                              : Colors.teal[700],
                          tabs: [
                            Tab(text: isAiAssisted ? 'Propuesta con IA ✨' : 'Propuesta Corregida 🛡️'),
                            const Tab(text: 'Texto Original'),
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
                                  color: Colors.teal.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    suggestedLyrics,
                                    style: GoogleFonts.nunito(fontSize: 13, height: 1.4, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ),
                              // Vista Texto Original
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    originalLyrics,
                                    style: GoogleFonts.nunito(fontSize: 13, height: 1.4, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[800]),
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

  /// Analiza una imagen (fotografía de cancionero o letra escrita) y extrae el texto limpio del canto
  static Future<Map<String, dynamic>?> transcribeSheetMusic(String base64Image, {String mimeType = 'image/jpeg'}) async {
    String apiKey = await getApiKey();

    // 1. Intentar primero a través de Cloud Function
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('scanHymnWithAi');
      final cfRes = await callable.call({
        'base64Image': base64Image,
        'mimeType': mimeType,
        'apiKey': apiKey,
      }).timeout(const Duration(seconds: 35));

      final cfData = cfRes.data;
      if (cfData is Map && cfData['success'] == true) {
        return {
          'title': cfData['title']?.toString() ?? '',
          'key': cfData['key']?.toString() ?? '',
          'timeSignature': cfData['timeSignature']?.toString() ?? '',
          'lyrics': cfData['lyrics']?.toString() ?? '',
        };
      }
    } catch (cfErr) {
      debugPrint('Cloud Function scanHymnWithAi falló o sin conexión: $cfErr. Probando llamada directa...');
    }

    if (apiKey.isEmpty) return null;

    final promptText = '''Eres un experto transcriptor de cantos e himnos cristianos. Analiza la imagen adjunta, que contiene la letra de un canto (puede tener acordes escritos arriba o entremedio).
Extrae la información y devuélvela ESTRICTAMENTE en formato JSON:
1. "title": Título de la canción (o "Título Desconocido").
2. "key": Tonalidad si está indicada (ej: "Sol Mayor", "La menor", "D", "Desconocida").
3. "timeSignature": Métrica si está indicada (ej: "4/4", "3/4", "Desconocida").
4. "lyrics": Extrae ÚNICAMENTE LA LETRA LIMPIA del canto. IGNORA COMPLETAMENTE TODOS LOS ACORDES que aparezcan arriba o entre las palabras (por ejemplo C, D, Em, LAm, DO, RE, SOL, etc.). Devuelve un texto limpio, ordenado prolijamente en estrofas y coros cantables.

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
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Image
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.2,
      }
    });

    final modelsToTry = [
      {'model': 'gemini-2.5-flash', 'api': 'v1beta'},
      {'model': 'gemini-2.5-flash-lite', 'api': 'v1beta'},
      {'model': 'gemini-2.0-flash', 'api': 'v1beta'},
      {'model': 'gemini-2.5-pro', 'api': 'v1beta'},
      {'model': 'gemini-2.0-flash-lite', 'api': 'v1beta'},
    ];
    
    List<String> errors = [];

    for (final item in modelsToTry) {
      final model = item['model']!;
      final api = item['api']!;
      final url = Uri.parse('https://generativelanguage.googleapis.com/$api/models/$model:generateContent?key=$apiKey');

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        ).timeout(const Duration(seconds: 22));

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
          errors.add('$model ($api) status ${response.statusCode}');
        }
      } catch (e) {
        errors.add('$model ($api) exc: $e');
      }
    }
    
    throw Exception('No se pudo transcribir la imagen. Errores: ${errors.join(', ')}');
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
      final modelsToTry = [
        {'model': 'gemini-2.5-flash', 'api': 'v1beta'},
        {'model': 'gemini-2.5-flash-lite', 'api': 'v1beta'},
        {'model': 'gemini-2.0-flash', 'api': 'v1beta'},
        {'model': 'gemini-2.5-pro', 'api': 'v1beta'},
        {'model': 'gemini-2.0-flash-lite', 'api': 'v1beta'},
      ];

      for (final item in modelsToTry) {
        if (response != null && response.statusCode == 200) break;
        final model = item['model']!;
        final endpoint = item['api']!;
        try {
          final url = Uri.parse('https://generativelanguage.googleapis.com/$endpoint/models/$model:generateContent?key=$apiKey');
          final res = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          ).timeout(const Duration(seconds: 25));
          
          if (res.statusCode == 200) {
            response = res;
            break;
          }
        } catch (_) {}
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
      debugPrint('Error en generateText: $e');
      return null;
    }
  }

  /// Realiza una búsqueda semántica y conceptual en el catálogo de cantos utilizando Gemini IA.
  /// Conecta con Gemini para permitir búsquedas conceptuales como:
  /// "Himnos que hablen del mar tempestuoso o de la armadura de Dios"
  /// cuando el usuario no recuerda el número ni el título exacto.
  static Future<Map<String, dynamic>> searchHymnsSemantically({
    required BuildContext context,
    required String query,
    required List<Hymn> catalog,
    Set<String>? allowedCollections,
    String searchMode = 'biblical', // 'biblical' o 'conceptual'
  }) async {
    // 1. Obtener la clave API de Gemini
    String apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      if (!context.mounted) {
        throw Exception('API Key de Gemini no configurada');
      }
      final enteredKey = await showApiKeyInputDialog(
        context,
        reason:
            'Para acceder al Asistente Bíblico e Inteligencia Artificial necesitas ingresar tu API Key de Google Gemini.',
      );
      if (enteredKey == null || enteredKey.trim().isEmpty) {
        throw Exception('Se requiere una clave API de Gemini para el Asistente Bíblico.');
      }
      apiKey = enteredKey.trim();
    }

    final filteredCatalog = allowedCollections == null || allowedCollections.isEmpty
        ? catalog
        : catalog
            .where((h) => allowedCollections.contains(h.collection))
            .toList();

    if (filteredCatalog.isEmpty) {
      return {
        'summary': 'No hay cantos en las colecciones seleccionadas.',
        'biblicalContext': null,
        'spiritualTone': null,
        'matches': <Map<String, dynamic>>[],
        'keywords': <String>[],
      };
    }

    // 2. Construir índice resumido y compacto de los cantos para contexto en el prompt
    final buffer = StringBuffer();
    for (final h in filteredCatalog) {
      buffer.writeln('${h.id}|${h.collection}|${h.title}');
    }

    final catalogIndex = buffer.toString();

    // 3. Intentar primero a través de Cloud Function (aprovecha la caché inteligente en Firestore)
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('searchHymnsWithAi');
      final cfRes = await callable.call({
        'query': query,
        'searchMode': searchMode,
        'catalogIndex': catalogIndex,
        'apiKey': apiKey,
      }).timeout(const Duration(seconds: 25));

      final cfData = cfRes.data;
      if (cfData is Map && cfData['success'] == true) {
        final rawResults = (cfData['results'] as List?) ?? [];
        final summary = cfData['summary']?.toString() ??
            'Resultados identificados por el Asistente Bíblico';
        final biblicalPassage = cfData['biblicalPassage']?.toString();
        final biblicalContext = cfData['biblicalContext']?.toString();
        final spiritualTone = cfData['spiritualTone']?.toString();
        final keywords = (cfData['keywords'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final matches = _mapRawResultsToHymns(rawResults, filteredCatalog);
        if (matches.isNotEmpty) {
          return {
            'summary': summary,
            'biblicalPassage': biblicalPassage,
            'biblicalContext': biblicalContext,
            'spiritualTone': spiritualTone,
            'matches': matches,
            'keywords': keywords,
          };
        }
      }
    } catch (cfError) {
      debugPrint('Cloud Function searchHymnsWithAi falló o sin red directa: $cfError. Intentando HTTP directo...');
    }

    final modeGuidance = searchMode == 'biblical'
        ? '''
MODO: ASISTENTE BÍBLICO Y HERMENÉUTICA DE PREDICACIÓN / SERMÓN
Misión: Actuar como un erudito teólogo bíblico, pastor e himnólogo cristiano con profundo conocimiento de las Sagradas Escrituras (Biblia Reina-Valera 1960) y de la himnología evangélica pentecostal (Himnario Oficial IUMP, Alabanzas Especiales y Coros Pentecostales).

REGLA DE ORO FUNDAMENTAL:
QUEDA ESTRICTAMENTE PROHIBIDO buscar por simple coincidencia superficial de palabras textuales aisladas (ejemplo: si el usuario escribe "pastor", NO debes limitarte a buscar cantos que contengan la palabra literal "pastor").
Tu función como IA Bíblica Avanzada es comprender el fondo teológico y espiritual:

1. LOCALIZACIÓN E IDENTIFICACIÓN BÍBLICA:
   - A partir de cualquier fragmento de versículo recordado a medias (ej: "aunque pase por aguas profundas no me ahogaré", "valle de sombra de muerte", "el profeta Elías cansado en el desierto"), cita bíblica o resumen de la predicación:
   - Identifica con precisión qué pasaje sagrado es (Libro, Capítulo y Versículos) y regístralo en "biblicalPassage" (ej: "Isaías 43:1-3", "Salmo 23:1-6", "1 Reyes 19:4-8", "Efesios 6:10-18", "Lucas 15:11-32").

2. EXÉGESIS Y CONTEXTO ESPIRITUAL REAL:
   - En "biblicalContext", analiza en 2-3 oraciones el sentido espiritual profundo: el trasfondo histórico-doctrinal, qué necesidad del alma atiende (consuelo en aflicción, desánimo espiritual, llamado a la santidad, etc.) y las promesas de Dios.
   - En "spiritualTone", define la atmósfera espiritual (ej: "Consagración", "Fe en la Prueba", "Guerra Espiritual", "Consuelo y Esperanza", "Gracia y Perdón", "Adoración y Alabanza").

3. HERMENÉUTICA CON EL CATÁLOGO DE CANTOS:
   - Selecciona entre 4 y 7 cantos del catálogo proporcionado cuyo mensaje teológico y espiritual de fondo abrace y ministre esta palabra, AUNQUE EL CANTO NO CONTENGA LAS PALABRAS LITERALES DEL PASAJE.
   - Para cada canto:
     * "worshipMoment": Momento litúrgico idóneo ("Sellar la Predicación", "Llamado al Altar / Consagración", "Oración de Fe / Afligidos", "Alabanza Congregacional").
     * "relevanceReason": Explica con claridad pastoral qué verdad teológica o estrofa del canto sella espiritualmente la enseñanza de la Palabra de Dios.
'''
        : '''
MODO: BÚSQUEDA CONCEPTUAL Y METAFÓRICA DE CANTOS
Misión: Ayudar a encontrar cantos a partir de un recuerdo difuso, metáfora, frase o historia:
1. Analiza el sentido poético y espiritual de la consulta (ej: "mar tempestuoso", "armadura de Dios", "el alfarero que rompe el vaso").
2. Identifica los cantos del catálogo que abordan directa o metafóricamente estas ideas. Si se mencionan múltiples temas, incluye los mejores para cada uno.
3. En "relevanceReason", detalla por qué coincide y qué estrofa o idea aborda.
4. En "worshipMoment", sugiere el momento del culto adecuado.
''';

    final prompt = '''
$modeGuidance

CONSULTA DEL MINISTRO O CONGREGANTE:
"$query"

CATÁLOGO OFICIAL DE CANTOS DISPONIBLES EN LA APP [ID|COLECCIÓN|TÍTULO]:
$catalogIndex

RESPONDE EXCLUSIVAMENTE CON UN OBJETO JSON VÁLIDO (sin bloques de código markdown ```json, sin texto adicional):
{
  "summary": "Breve resumen del mensaje o concepto (1 frase)",
  "biblicalPassage": "Libro Capítulo:Versículos identificados (ej: Isaías 43:1-3, Salmo 23:1-6)",
  "biblicalContext": "Análisis exegético del pasaje bíblico o trasfondo doctrinal del sermón (2-3 oraciones claras)",
  "spiritualTone": "Consagración | Fe en la Prueba | Consuelo y Esperanza | Guerra Espiritual | Gracia y Perdón | Adoración",
  "results": [
    {
      "id": 123,
      "collection": "iump",
      "title": "TÍTULO DEL CANTO",
      "relevanceReason": "Conexión pastoral/doctrinal explicando qué estrofa o verdad teológica abraza la palabra...",
      "worshipMoment": "Sellar la Predicación | Llamado al Altar | Oración de Fe | Congregacional"
    }
  ],
  "keywords": ["tema1", "tema2"]
}
''';

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.2,
      }
    });

    final modelsToTry = [
      {'model': 'gemini-2.5-flash', 'api': 'v1beta'},
      {'model': 'gemini-2.5-flash-lite', 'api': 'v1beta'},
      {'model': 'gemini-2.0-flash', 'api': 'v1beta'},
      {'model': 'gemini-2.5-pro', 'api': 'v1beta'},
      {'model': 'gemini-2.0-flash-lite', 'api': 'v1beta'},
    ];

    http.Response? response;
    List<String> errors = [];

    for (final item in modelsToTry) {
      final model = item['model']!;
      final api = item['api']!;
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/$api/models/$model:generateContent?key=$apiKey',
      );

      try {
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        ).timeout(const Duration(seconds: 22));

        if (res.statusCode == 200) {
          response = res;
          break;
        } else {
          errors.add('$model ($api): ${res.statusCode}');
        }
      } catch (e) {
        errors.add('$model ($api) exc: $e');
      }
    }

    if (response == null || response.statusCode != 200) {
      final localMatches = _findLocalThematicMatches(query, filteredCatalog);
      if (localMatches.isNotEmpty) {
        return {
          'summary': 'Coincidencias temáticas locales (Modo sin conexión)',
          'biblicalPassage': null,
          'biblicalContext': 'Modo sin conexión a internet: Se aplicó coincidencia temática local directa sobre el catálogo.',
          'spiritualTone': 'Alabanza y Fe',
          'matches': localMatches,
          'keywords': <String>[],
        };
      }
      throw Exception('No se pudo conectar con Gemini IA. Detalle: ${errors.join(', ')}');
    }

    final data = jsonDecode(response.body);
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

    String cleanText = text.trim();
    if (cleanText.startsWith('```json')) {
      cleanText = cleanText.substring(7);
    } else if (cleanText.startsWith('```')) {
      cleanText = cleanText.substring(3);
    }
    if (cleanText.endsWith('```')) {
      cleanText = cleanText.substring(0, cleanText.length - 3);
    }

    final parsed = jsonDecode(cleanText.trim()) as Map<String, dynamic>;
    final rawResults = (parsed['results'] as List?) ?? [];
    final summary = parsed['summary']?.toString() ??
        'Resultados conceptuales encontrados por Gemini IA';
    final biblicalPassage = parsed['biblicalPassage']?.toString();
    final biblicalContext = parsed['biblicalContext']?.toString();
    final spiritualTone = parsed['spiritualTone']?.toString();
    final keywords = (parsed['keywords'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final finalMatches = _mapRawResultsToHymns(rawResults, filteredCatalog);

    return {
      'summary': summary,
      'biblicalPassage': biblicalPassage,
      'biblicalContext': biblicalContext,
      'spiritualTone': spiritualTone,
      'matches': finalMatches,
      'keywords': keywords,
    };
  }

  static List<Map<String, dynamic>> _mapRawResultsToHymns(
    List rawResults,
    List<Hymn> filteredCatalog,
  ) {
    final List<Map<String, dynamic>> finalMatches = [];
    final catalogMap = {
      for (var h in filteredCatalog) '${h.collection}-${h.id}': h
    };

    for (final item in rawResults) {
      final col = item['collection']?.toString().toLowerCase().trim() ?? 'iump';
      final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
      final title = item['title']?.toString() ?? '';
      final reason =
          item['relevanceReason']?.toString() ?? 'Coincidencia conceptual';
      final moment = item['worshipMoment']?.toString() ?? 'Sellar la Predicación';

      Hymn? matchedHymn = catalogMap['$col-$id'];

      // Fallback por si la colección o ID varían levemente
      if (matchedHymn == null) {
        final normTitle = Hymn.normalizeString(title);
        matchedHymn = filteredCatalog.cast<Hymn?>().firstWhere(
          (h) => h != null && h.normalizedTitle == normTitle,
          orElse: () => null,
        );
      }

      if (matchedHymn != null) {
        finalMatches.add({
          'hymn': matchedHymn,
          'relevanceReason': reason,
          'worshipMoment': moment,
        });
      }
    }
    return finalMatches;
  }


  static List<Map<String, dynamic>> _findLocalThematicMatches(
    String query,
    List<Hymn> catalog,
  ) {
    final normQuery = Hymn.normalizeString(query);
    final rawWords =
        normQuery.split(' ').where((w) => w.length >= 4).toList();
    if (rawWords.isEmpty) return [];

    final scored = <Map<String, dynamic>>[];
    for (final h in catalog) {
      int score = 0;
      final matchedTerms = <String>[];
      for (final w in rawWords) {
        if (h.normalizedTitle.contains(w)) {
          score += 30;
          matchedTerms.add(w);
        } else if (h.normalizedSearchableText.contains(w)) {
          score += 10;
          matchedTerms.add(w);
        }
      }
      if (score > 0) {
        scored.add({
          'hymn': h,
          'relevanceReason':
              'Coincidencia con los términos: ${matchedTerms.join(', ')}',
          'score': score,
        });
      }
    }
    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scored.take(6).toList();
  }
}