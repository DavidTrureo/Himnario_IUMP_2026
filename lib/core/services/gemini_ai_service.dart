import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'hymn_semantic_retriever.dart';
import 'spanish_grammar_corrector.dart';
import '../../features/hymns/domain/hymn.dart';

class GeminiAiService {
  static const String _keyPref = 'gemini_api_key';

  /// Clave de respaldo opcional inyectada solo en compilación (--dart-define=GEMINI_API_KEY=...).
  /// En producción las Cloud Functions de Himnario usan exclusivamente su propia clave separada en servidor.
  static String get defaultServerApiKey =>
      const String.fromEnvironment('GEMINI_API_KEY');

  static const List<String> _activeModels = [
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
    'gemini-3.1-flash-lite',
    'gemini-flash-lite-latest',
  ];

  static bool _isRetiredSharedKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.contains('AQ.Ab8RN6LMJy9J1QN') ||
        trimmed.contains('AQ.Ab8RN6ORMW') ||
        (trimmed.startsWith('AQ.Ab8RN6JP') && trimmed.endsWith('2F31A'));
  }

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = prefs.getString(_keyPref)?.trim() ?? '';
    // Si el usuario tiene guardada una clave obsoleta o la antigua clave compartida, purgarla
    if (_isRetiredSharedKey(customKey) ||
        (customKey.isNotEmpty && customKey.length < 20)) {
      debugPrint('Purgando clave obsoleta/compartida guardada en dispositivo. Usando Cloud Function oficial.');
      await prefs.remove(_keyPref);
      return defaultServerApiKey;
    }
    if (customKey.isNotEmpty) {
      return customKey;
    }
    return defaultServerApiKey;
  }

  static Future<void> resetToDefaultApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPref);
  }

  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, apiKey.trim());
  }

  static Future<String?> showApiKeyInputDialog(BuildContext context, {String? reason}) async {
    final currentKey = await getApiKey();
    final controller = TextEditingController(text: currentKey);
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
                label: const Text('Obtener API Key (Gratis en AI Studio)'),
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
                  labelText: 'API Key personal de Gemini (Opcional)',
                  hintText: 'Deja vacío para usar el servidor oficial',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await resetToDefaultApiKey();
              if (context.mounted) Navigator.pop(context, defaultServerApiKey);
            },
            child: const Text('Usar Servidor Oficial'),
          ),
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

    bool isAiAssisted = false;
    bool geminiFailed = false;
    bool isProgressShown = false;

    // Consultar primero vía Cloud Function oficial (sin requerir clave en el cliente)
    {
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
          if (apiKey.isNotEmpty) 'apiKey': apiKey,
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
        debugPrint('Cloud Function no respondió o falló: $cfError.');
      }

      if (!remoteSuccess && apiKey.isEmpty) {
        geminiFailed = true;
      }

      // 2. Si hay clave personalizada/compilada y falló la Cloud Function, intentar vía REST directo
      if (!remoteSuccess && apiKey.isNotEmpty) {
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

        List<String> modelErrors = [];
        Future<http.Response?> callModels(String keyToUse) async {
          for (final model in _activeModels) {
            const api = 'v1beta';
            try {
              final url = Uri.parse(
                  'https://generativelanguage.googleapis.com/$api/models/$model:generateContent');
              final res = await http.post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'x-goog-api-key': keyToUse,
                },
                body: requestBody,
              ).timeout(const Duration(seconds: 18));

              if (res.statusCode == 200) {
                return res;
              } else {
                debugPrint('Gemini corrector intent [$model ($api)]: status ${res.statusCode}');
                modelErrors.add('$model ($api) status ${res.statusCode}');
                if (res.statusCode == 400 || res.statusCode == 403) return null;
              }
            } catch (e) {
              debugPrint('Gemini corrector exception [$model ($api)]: $e');
              modelErrors.add('$model ($api) exc: $e');
            }
          }
          return null;
        }

        response = await callModels(apiKey);
        if ((response == null || response.statusCode != 200) && apiKey != defaultServerApiKey) {
          debugPrint('>>> Corrector: clave personalizada falló. Reintentando con defaultServerApiKey...');
          await resetToDefaultApiKey();
          apiKey = defaultServerApiKey;
          response = await callModels(apiKey);
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
        if (apiKey.isNotEmpty) 'apiKey': apiKey,
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

    List<String> errors = [];
    Future<Map<String, dynamic>?> tryModels(String keyToUse) async {
      for (final model in _activeModels) {
        const api = 'v1beta';
        final url = Uri.parse('https://generativelanguage.googleapis.com/$api/models/$model:generateContent');

        try {
          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': keyToUse,
            },
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
            if (response.statusCode == 400 || response.statusCode == 403) return null;
          }
        } catch (e) {
          errors.add('$model ($api) exc: $e');
        }
      }
      return null;
    }

    var result = await tryModels(apiKey);
    if (result == null && apiKey != defaultServerApiKey) {
      await resetToDefaultApiKey();
      apiKey = defaultServerApiKey;
      result = await tryModels(apiKey);
    }
    if (result != null) return result;
    
    throw Exception('No se pudo transcribir la imagen. Errores: ${errors.join(', ')}');
  }

  static Future<String?> generateText(String prompt) async {
    try {
      var apiKey = await getApiKey();
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

      Future<http.Response?> callModels(String keyToUse) async {
        for (final model in _activeModels) {
          const endpoint = 'v1beta';
          try {
            final url = Uri.parse('https://generativelanguage.googleapis.com/$endpoint/models/$model:generateContent');
            final res = await http.post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': keyToUse,
              },
              body: requestBody,
            ).timeout(const Duration(seconds: 25));
            
            if (res.statusCode == 200) {
              return res;
            } else if (res.statusCode == 400 || res.statusCode == 403) {
              return null;
            }
          } catch (_) {}
        }
        return null;
      }

      response = await callModels(apiKey);
      if ((response == null || response.statusCode != 200) && apiKey != defaultServerApiKey) {
        await resetToDefaultApiKey();
        apiKey = defaultServerApiKey;
        response = await callModels(apiKey);
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

  /// Obtiene vector de consulta vía `gemini-embedding-001` cuando hay clave API local opcional.
  static Future<List<double>?> _embedQueryDirect(String query, String apiKey) async {
    if (apiKey.trim().isEmpty || !HymnSemanticRetriever.hasEmbeddingsLoaded) {
      return null;
    }
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent',
      );
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey.trim(),
        },
        body: jsonEncode({
          'model': 'models/gemini-embedding-001',
          'content': {
            'parts': [
              {'text': query}
            ]
          },
          'taskType': 'RETRIEVAL_QUERY',
          'outputDimensionality': 256,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final values = decoded['embedding']?['values'] as List?;
        if (values != null && values.length == 256) {
          return values.map((e) => (e as num).toDouble()).toList();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Realiza una búsqueda semántica y conceptual en toda la base de datos utilizando
  /// recuperación híbrida (letras completas + embeddings) + curaduría estricta por colección,
  /// devolviendo hasta 10 cantos más acertados por colección (`iump`, `especiales`, `coros`).
  static Future<Map<String, dynamic>> searchHymnsSemantically({
    required BuildContext context,
    required String query,
    required List<Hymn> catalog,
    Set<String>? allowedCollections,
    String searchMode = 'biblical', // 'biblical' o 'conceptual'
  }) async {
    await HymnSemanticRetriever.ensureEmbeddingsLoaded();

    final effectiveAllowed = (allowedCollections == null || allowedCollections.isEmpty)
        ? HymnSemanticRetriever.collectionOrder.toSet()
        : allowedCollections;
    final orderedCols = HymnSemanticRetriever.collectionOrder
        .where(effectiveAllowed.contains)
        .toList();

    final filteredCatalog = catalog
        .where((h) => effectiveAllowed.contains(h.collection))
        .toList();

    if (filteredCatalog.isEmpty) {
      final emptyCollections = <String, Map<String, dynamic>>{
        for (final col in orderedCols)
          col: {
            'matches': <Map<String, dynamic>>[],
            'noMoreReason': HymnSemanticRetriever.buildDefaultNoMoreReason(
              collection: col,
              foundCount: 0,
            ),
          }
      };
      return {
        'summary': 'No hay cantos en las colecciones seleccionadas.',
        'biblicalPassage': null,
        'biblicalContext': null,
        'spiritualTone': null,
        'collections': emptyCollections,
        'matches': <Map<String, dynamic>>[],
        'keywords': <String>[],
        'fromCache': false,
        'isLocalFallback': true,
        'quotaReached': false,
      };
    }

    // 1. Clave personal opcional del usuario (las Cloud Functions usan su clave oficial separada)
    String apiKey = (await getApiKey()).trim();
    final List<double>? clientQueryVec = await _embedQueryDirect(query, apiKey);

    // 2. Preseleccionar en el dispositivo los mejores candidatos por colección leyendo letras completas
    final lexicalCandidates = HymnSemanticRetriever.buildCandidatePool(
      query: query,
      catalog: filteredCatalog,
      allowedCollections: effectiveAllowed,
      queryVector: clientQueryVec,
      perCollectionLimit: orderedCols.length == 1 ? 30 : 22,
    );
    final catalogSignature = HymnSemanticRetriever.computeCatalogSignature(
      filteredCatalog,
      effectiveAllowed,
    );

    bool isQuotaError = false;

    // 3. Intentar primero a través de Cloud Function v2 (caché compartida + vectores servidor + clave aislada)
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('searchHymnsWithAi');
      final cfRes = await callable.call({
        'schemaVersion': 2,
        'query': query,
        'searchMode': searchMode,
        'allowedCollections': orderedCols,
        'catalogSignature': catalogSignature,
        'lexicalCandidates': lexicalCandidates,
        if (apiKey.isNotEmpty) 'apiKey': apiKey,
      }).timeout(const Duration(seconds: 45));

      final cfData = cfRes.data;
      if (cfData is Map && cfData['success'] == true) {
        return _mapV2PayloadToResult(
          rawPayload: cfData,
          filteredCatalog: filteredCatalog,
          orderedCols: orderedCols,
          fromCache: cfData['fromCache'] == true,
        );
      }
    } catch (cfError) {
      final errStr = cfError.toString().toLowerCase();
      if (errStr.contains('resource-exhausted') || errStr.contains('429')) {
        isQuotaError = true;
      }
      debugPrint('Cloud Function searchHymnsWithAi v2 falló ($cfError).');
    }

    // 4. Si el usuario configuró su propia clave REST (o --dart-define), intentar REST directo con candidatos prefiltrados
    if (apiKey.isNotEmpty && !isQuotaError) {
      final restResult = await _tryDirectRestSearchV2(
        query: query,
        searchMode: searchMode,
        orderedCols: orderedCols,
        lexicalCandidates: lexicalCandidates,
        filteredCatalog: filteredCatalog,
        apiKey: apiKey,
      );
      if (restResult != null) {
        return restResult;
      }
    }

    // 5. Respaldo local de alta precisión (10+10+10 leyendo letras completas, nunca pantalla vacía ni error)
    return HymnSemanticRetriever.searchLocally(
      query: query,
      catalog: filteredCatalog,
      allowedCollections: effectiveAllowed,
      searchMode: searchMode,
      queryVector: clientQueryVec,
      quotaFallback: isQuotaError,
    );
  }

  static Future<Map<String, dynamic>?> _tryDirectRestSearchV2({
    required String query,
    required String searchMode,
    required List<String> orderedCols,
    required Map<String, List<Map<String, dynamic>>> lexicalCandidates,
    required List<Hymn> filteredCatalog,
    required String apiKey,
  }) async {
    final candidateBlocks = <String>[];
    for (final col in orderedCols) {
      final list = lexicalCandidates[col] ?? const [];
      final lines = list
          .map((e) => '${e['id']}|${e['title']}|${(e['digest'] ?? '').toString().replaceAll('\n', ' ')}')
          .join('\n');
      candidateBlocks.add(
        '=== COLECCIÓN "$col" (${HymnSemanticRetriever.collectionDisplayName(col)}) [ID|TÍTULO|LETRA_COMPACTA] ===\n'
        '${lines.isNotEmpty ? lines : "(Sin candidatos)"}',
      );
    }

    final collectionsShape = orderedCols.map((col) => '''    "$col": {
      "matches": [
        {
          "id": 123,
          "collection": "$col",
          "title": "TÍTULO EXACTO DEL CANTO",
          "relevanceLevel": "alta",
          "relevanceReason": "1-2 frases concretas citando la estrofa o verdad espiritual que conecta",
          "worshipMoment": "Sellar la Predicación | Llamado al Altar | Oración de Fe | Alabanza Congregacional"
        }
      ],
      "noMoreReason": "Explicación pastoral breve si hay menos de 10 o 0 cantos en esta colección"
    }''').join(',\n');

    final prompt = '''
MODO: ${searchMode == 'biblical' ? 'ASISTENTE BÍBLICO DE PREDICACIÓN / SERMÓN' : 'BÚSQUEDA TEMÁTICA Y METAFÓRICA'}
Evalúa por separado cada colección (${orderedCols.join(', ')}) leyendo sus títulos y LETRAS COMPACTAS reales.
Para CADA colección, devuelve hasta 10 cantos más acertados (ordenados de mayor a menor acierto).
REGLA ANTI-RELLENO OBLIGATORIA: Nunca incluyas cantos forzados para llegar a 10; si hay 0, 3 o 6 genuinos, devuelve solo esos y explica brevemente en "noMoreReason".

CONSULTA:
"$query"

CANDIDATOS:
${candidateBlocks.join('\n\n')}

RESPONDE EXCLUSIVAMENTE CON JSON VÁLIDO:
{
  "summary": "Resumen en 1 frase",
  "biblicalPassage": "Cita bíblica principal si aplica",
  "biblicalContext": "Análisis espiritual/exegético breve (2 oraciones)",
  "spiritualTone": "Consagración | Fe en la Prueba | Consuelo y Esperanza | Guerra Espiritual | Gracia y Perdón | Adoración",
  "keywords": ["tema1", "tema2", "tema3"],
  "collections": {
$collectionsShape
  }
}''';

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
        'temperature': 0.15,
        'maxOutputTokens': 8192,
      }
    });

    for (final model in _activeModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
        );
        final res = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: requestBody,
        ).timeout(const Duration(seconds: 35));

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          var text = (decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '').toString().trim();
          if (text.startsWith('```json')) text = text.substring(7);
          if (text.startsWith('```')) text = text.substring(3);
          if (text.endsWith('```')) text = text.substring(0, text.length - 3);
          final parsed = jsonDecode(text.trim()) as Map;
          return _mapV2PayloadToResult(
            rawPayload: parsed,
            filteredCatalog: filteredCatalog,
            orderedCols: orderedCols,
            fromCache: false,
          );
        } else if (res.statusCode == 400 || res.statusCode == 403) {
          return null;
        }
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic> _mapV2PayloadToResult({
    required Map rawPayload,
    required List<Hymn> filteredCatalog,
    required List<String> orderedCols,
    required bool fromCache,
  }) {
    final summary = rawPayload['summary']?.toString() ??
        'Resultados identificados por el Asistente Bíblico';
    final biblicalPassage = rawPayload['biblicalPassage']?.toString();
    final biblicalContext = rawPayload['biblicalContext']?.toString();
    final spiritualTone = rawPayload['spiritualTone']?.toString();
    final keywords = (rawPayload['keywords'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final catalogByColAndId = <String, Hymn>{
      for (final h in filteredCatalog) '${h.collection}-${h.id}': h,
    };

    final rawCollections = rawPayload['collections'];
    final mappedCollections = <String, Map<String, dynamic>>{};
    final flatMatches = <Map<String, dynamic>>[];

    if (rawCollections is Map) {
      for (final col in orderedCols) {
        final colRaw = rawCollections[col];
        final rawMatches = (colRaw is Map && colRaw['matches'] is List)
            ? colRaw['matches'] as List
            : const [];
        final resolved = _resolveMatchesForCollection(
          rawList: rawMatches,
          targetCollection: col,
          catalogByColAndId: catalogByColAndId,
          filteredCatalog: filteredCatalog,
        );

        final aiReason = (colRaw is Map ? colRaw['noMoreReason']?.toString().trim() : null) ?? '';
        final noMoreReason = resolved.length >= HymnSemanticRetriever.maxResultsPerCollection
            ? HymnSemanticRetriever.buildDefaultNoMoreReason(
                collection: col,
                foundCount: resolved.length,
              )
            : (aiReason.length >= 12
                ? aiReason
                : HymnSemanticRetriever.buildDefaultNoMoreReason(
                    collection: col,
                    foundCount: resolved.length,
                  ));

        mappedCollections[col] = {
          'matches': resolved,
          'noMoreReason': noMoreReason,
        };
        flatMatches.addAll(resolved);
      }
    } else {
      final rawFlat = (rawPayload['results'] as List?) ?? const [];
      for (final col in orderedCols) {
        final filteredRaw = rawFlat
            .where((item) =>
                item is Map &&
                item['collection']?.toString().toLowerCase().trim() == col)
            .toList();
        final resolved = _resolveMatchesForCollection(
          rawList: filteredRaw,
          targetCollection: col,
          catalogByColAndId: catalogByColAndId,
          filteredCatalog: filteredCatalog,
        );
        mappedCollections[col] = {
          'matches': resolved,
          'noMoreReason': HymnSemanticRetriever.buildDefaultNoMoreReason(
            collection: col,
            foundCount: resolved.length,
          ),
        };
        flatMatches.addAll(resolved);
      }
    }

    return {
      'summary': summary,
      'biblicalPassage': biblicalPassage,
      'biblicalContext': biblicalContext,
      'spiritualTone': spiritualTone,
      'keywords': keywords,
      'collections': mappedCollections,
      'matches': flatMatches,
      'fromCache': fromCache,
      'isLocalFallback': false,
      'quotaReached': false,
    };
  }

  static List<Map<String, dynamic>> _resolveMatchesForCollection({
    required List rawList,
    required String targetCollection,
    required Map<String, Hymn> catalogByColAndId,
    required List<Hymn> filteredCatalog,
  }) {
    final out = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    for (final item in rawList) {
      if (item is! Map) continue;
      final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
      final title = item['title']?.toString() ?? '';
      final reason =
          item['relevanceReason']?.toString().trim() ?? 'Coincidencia espiritual con la búsqueda.';
      final moment = item['worshipMoment']?.toString().trim() ?? 'Sellar la Predicación';
      final level = item['relevanceLevel']?.toString().toLowerCase().trim() ?? 'alta';

      Hymn? matchedHymn = catalogByColAndId['$targetCollection-$id'];
      if (matchedHymn == null && title.isNotEmpty) {
        final normTitle = Hymn.normalizeString(title);
        matchedHymn = filteredCatalog.cast<Hymn?>().firstWhere(
          (h) => h != null && h.collection == targetCollection && h.normalizedTitle == normTitle,
          orElse: () => null,
        );
      }

      if (matchedHymn != null && seenKeys.add('${matchedHymn.collection}-${matchedHymn.id}')) {
        out.add({
          'hymn': matchedHymn,
          'relevanceReason': reason,
          'worshipMoment': moment,
          'relevanceLevel': level,
        });
        if (out.length >= HymnSemanticRetriever.maxResultsPerCollection) break;
      }
    }

    return out;
  }
}
