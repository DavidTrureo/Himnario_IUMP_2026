import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/hymns/presentation/admin_suggestions_screen.dart', 'r') as f:
    content = f.read()

# Add import if missing
if "import 'package:himnario_iump/core/services/gemini_ai_service.dart';" not in content:
    content = content.replace("import 'package:himnario_iump/features/hymns/domain/models/hymn.dart';", "import 'package:himnario_iump/features/hymns/domain/models/hymn.dart';\nimport 'package:himnario_iump/core/services/gemini_ai_service.dart';")

target = """                    const SizedBox(height: 12),
                    TextField(
                      controller: lyricsCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(labelText: 'Letra', border: OutlineInputBorder()),
                    ),"""

replacement = """                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Letra', style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                          tooltip: 'Mejorar Ortografía y Puntuación con IA',
                          onPressed: () async {
                            if (lyricsCtrl.text.trim().isEmpty) return;
                            final result = await GeminiAiService.correctHymnGrammar(
                              context: context,
                              title: titleCtrl.text.trim(),
                              lyrics: lyricsCtrl.text.trim(),
                            );
                            if (result != null) {
                              titleCtrl.text = result['title']!;
                              lyricsCtrl.text = result['lyrics']!;
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: lyricsCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),"""

if target in content:
    content = content.replace(target, replacement)
    with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/hymns/presentation/admin_suggestions_screen.dart', 'w') as f:
        f.write(content)
    print("Success updating admin_suggestions_screen.dart")
else:
    print("Target not found in admin_suggestions_screen.dart")

