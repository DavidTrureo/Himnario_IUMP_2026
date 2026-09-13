import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/hymns/presentation/add_hymn_screen.dart', 'r') as f:
    content = f.read()

target = """                        IconButton(
                          icon: const Icon(Icons.document_scanner),
                          tooltip: 'Escanear con OCR',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          onPressed: _scanText,
                        ),
                      ],
                    ),"""

replacement = """                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                              tooltip: 'Mejorar Ortografía y Puntuación con IA',
                              onPressed: () async {
                                if (_lyricsController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ingresa la letra antes de pulir con IA')),
                                  );
                                  return;
                                }
                                final result = await GeminiAiService.correctHymnGrammar(
                                  context: context,
                                  title: _titleController.text.trim(),
                                  lyrics: _lyricsController.text.trim(),
                                );
                                if (result != null) {
                                  _titleController.text = result['title']!;
                                  _lyricsController.text = result['lyrics']!;
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.document_scanner),
                              tooltip: 'Escanear con OCR',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              onPressed: _scanText,
                            ),
                          ],
                        ),
                      ],
                    ),"""

if target in content:
    content = content.replace(target, replacement)
    with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/hymns/presentation/add_hymn_screen.dart', 'w') as f:
        f.write(content)
    print("Success updating add_hymn_screen.dart")
else:
    print("Target not found in add_hymn_screen.dart")

