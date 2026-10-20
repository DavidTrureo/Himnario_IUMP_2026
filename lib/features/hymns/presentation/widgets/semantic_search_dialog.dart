import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/gemini_ai_service.dart';
import '../../domain/hymn.dart';
import '../hymn_list_screen.dart';

class SemanticSearchDialog extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SemanticSearchDialog({super.key, this.initialQuery});

  @override
  ConsumerState<SemanticSearchDialog> createState() => _SemanticSearchDialogState();
}

class _SemanticSearchDialogState extends ConsumerState<SemanticSearchDialog> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  String? _errorMessage;
  String? _summary;
  List<Map<String, dynamic>> _results = [];
  List<String> _keywords = [];
  final Set<String> _selectedCollections = {'iump', 'especiales', 'coros'};

  final List<String> _exampleQueries = [
    'Mar tempestuoso o la barca',
    'La armadura de Dios y la fe',
    'El Buen Pastor y Salmo 23',
    'El perdón de pecados y la Cruz',
    'El Alfarero y el barro',
    'Espíritu Santo y fuego de Pentecostés',
    'Consuelo en momentos de prueba y dolor',
    'Segunda venida de Cristo y trompeta final',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    if ((widget.initialQuery ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results = [];
      _summary = null;
      _keywords = [];
    });

    try {
      var allHymns = ref.read(allHymnsGlobalProvider).value ?? [];
      if (allHymns.isEmpty) {
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 300));
          allHymns = ref.read(allHymnsGlobalProvider).value ?? [];
          if (allHymns.isNotEmpty) break;
        }
      }
      if (allHymns.isEmpty) {
        throw Exception('El catálogo de cantos aún se está cargando. Intenta en unos segundos.');
      }
      if (!mounted) return;

      final searchResponse = await GeminiAiService.searchHymnsSemantically(
        context: context,
        query: query,
        catalog: allHymns,
        allowedCollections: _selectedCollections,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _summary = searchResponse['summary']?.toString();
          _results = List<Map<String, dynamic>>.from(searchResponse['matches'] ?? []);
          _keywords = List<String>.from(searchResponse['keywords'] ?? []);
          if (_results.isEmpty) {
            _errorMessage = 'Gemini no encontró coincidencias para esta búsqueda conceptual. Intenta describir el tema con otras palabras.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  String _getCollectionName(String col) {
    switch (col) {
      case 'iump':
        return 'Himnario IUMP';
      case 'especiales':
        return 'Especiales';
      case 'coros':
        return 'Coros';
      default:
        return col.toUpperCase();
    }
  }

  Color _getCollectionColor(String col, ThemeData theme) {
    switch (col) {
      case 'iump':
        return Colors.blue.shade700;
      case 'especiales':
        return Colors.purple.shade700;
      case 'coros':
        return Colors.teal.shade700;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 40,
        vertical: isCompact ? 24 : 36,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade600, Colors.orange.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Búsqueda Semántica con IA',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Encuentra cantos por concepto, historia o metáfora',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Barra de entrada y botón de búsqueda
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _performSearch(),
                      decoration: InputDecoration(
                        hintText: 'Ej: Himnos que hablen del mar tempestuoso o de la armadura de Dios...',
                        hintStyle: GoogleFonts.nunito(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      style: GoogleFonts.nunito(fontSize: 14),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Buscar', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Filtros de colección y sugerencias rápidas
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Buscar en:',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  FilterChip(
                    label: const Text('Himnario IUMP'),
                    labelStyle: GoogleFonts.nunito(fontSize: 11),
                    selected: _selectedCollections.contains('iump'),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedCollections.add('iump');
                        } else if (_selectedCollections.length > 1) {
                          _selectedCollections.remove('iump');
                        }
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Especiales'),
                    labelStyle: GoogleFonts.nunito(fontSize: 11),
                    selected: _selectedCollections.contains('especiales'),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedCollections.add('especiales');
                        } else if (_selectedCollections.length > 1) {
                          _selectedCollections.remove('especiales');
                        }
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Coros'),
                    labelStyle: GoogleFonts.nunito(fontSize: 11),
                    selected: _selectedCollections.contains('coros'),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedCollections.add('coros');
                        } else if (_selectedCollections.length > 1) {
                          _selectedCollections.remove('coros');
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Sugerencias de ejemplo
              if (_results.isEmpty && !_isLoading && _errorMessage == null) ...[
                Text(
                  'Ideas populares para probar:',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _exampleQueries.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final ex = _exampleQueries[idx];
                      return ActionChip(
                        label: Text(ex, style: GoogleFonts.nunito(fontSize: 11)),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        onPressed: () {
                          _controller.text = ex;
                          _performSearch();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Divider
              const Divider(height: 16),

              // Contenido dinámico (Loading, Error o Lista de Resultados)
              Expanded(
                child: _buildBody(context, theme, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Consultando a Gemini IA...',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analizando metáforas, pasajes bíblicos y estrofas del catálogo',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded, size: 48, color: Colors.orange.shade700),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: GoogleFonts.nunito(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                onPressed: _performSearch,
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 56,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 12),
            Text(
              'Ingresa cualquier tema, frase o metáfora',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gemini buscará en las estrofas y contexto teológico de todos los cantos',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Resumen conceptual devuelto por Gemini
        if (_summary != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _summary!,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_keywords.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _keywords.map((kw) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$kw',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),

        // Lista de cantos recomendados
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _results[index];
              final Hymn hymn = item['hymn'] as Hymn;
              final reason = item['relevanceReason'] as String? ?? '';
              final colColor = _getCollectionColor(hymn.collection, theme);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : theme.colorScheme.surface,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(context, '${hymn.collection}-${hymn.id}');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_getCollectionName(hymn.collection)} #${hymn.id}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (hymn.toneNote.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hymn.toneNote,
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hymn.title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💡 ', style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: GoogleFonts.nunito(
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Tocar para abrir canto →',
                            style: GoogleFonts.nunito(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
