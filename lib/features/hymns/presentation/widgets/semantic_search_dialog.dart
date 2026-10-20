import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/gemini_ai_service.dart';
import '../../domain/hymn.dart';
import '../hymn_list_screen.dart';

class SemanticSearchDialog extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String defaultMode; // 'biblical' o 'conceptual'

  const SemanticSearchDialog({
    super.key,
    this.initialQuery,
    this.defaultMode = 'biblical',
  });

  @override
  ConsumerState<SemanticSearchDialog> createState() =>
      _SemanticSearchDialogState();
}

class _SemanticSearchDialogState extends ConsumerState<SemanticSearchDialog> {
  late final TextEditingController _controller;
  late String _activeMode; // 'biblical' o 'conceptual'
  bool _isLoading = false;
  String? _errorMessage;
  String? _summary;
  String? _biblicalContext;
  String? _spiritualTone;
  List<Map<String, dynamic>> _results = [];
  List<String> _keywords = [];
  final Set<String> _selectedCollections = {'iump', 'especiales', 'coros'};

  final List<Map<String, String>> _biblicalSuggestions = [
    {'title': 'Salmo 23', 'query': 'Salmo 23: Jehová es mi Pastor y nada me faltará'},
    {'title': 'Efesios 6 (Armadura)', 'query': 'Efesios 6:10-18: Vestíos de toda la armadura de Dios para la batalla de la fe'},
    {'title': 'Isaías 53 (La Cruz)', 'query': 'Isaías 53: Mas él herido fue por nuestras rebeliones, el siervo sufriente'},
    {'title': 'Lucas 15 (Hijo Pródigo)', 'query': 'Lucas 15: El hijo pródigo, la gracia del Padre y el perdón de pecados'},
    {'title': 'Hechos 2 (Pentecostés)', 'query': 'Hechos 2: El derramamiento del Espíritu Santo y fuego de Pentecostés'},
    {'title': 'Isaías 40 (Nuevas Fuerzas)', 'query': 'Isaías 40: Los que esperan a Jehová tendrán nuevas fuerzas como las águilas'},
    {'title': 'Consuelo en la Prueba', 'query': 'Mensaje de consuelo y fortaleza para los que están pasando por aflicción y dolor'},
    {'title': 'Llamado al Altar', 'query': 'Llamado al arrepentimiento, quebrantamiento, entrega total y consagración a Dios'},
    {'title': 'Segunda Venida', 'query': 'La venida del Señor, el arrebatamiento de la Iglesia y la trompeta final'},
  ];

  final List<Map<String, String>> _conceptualSuggestions = [
    {'title': 'Mar tempestuoso', 'query': 'Himnos que hablen del mar tempestuoso, la barca y Jesús calmando la tempestad'},
    {'title': 'Armadura de Dios', 'query': 'Himnos sobre la armadura de Dios, la lucha espiritual y ser soldado de Cristo'},
    {'title': 'El Alfarero y el Barro', 'query': 'Himno del alfarero que rompe el vaso de barro y lo hace de nuevo'},
    {'title': '99 Ovejas en el Redil', 'query': 'Canto sobre las noventa y nueve ovejas y el Pastor buscando a la perdida'},
    {'title': 'La Zarza que ardía', 'query': 'Alabanza sobre la zarza en el monte que ardía y no se consumía'},
    {'title': 'Un ancla en la tormenta', 'query': 'Tenemos un ancla firme y segura en medio de las olas del mar'},
  ];

  @override
  void initState() {
    super.initState();
    _activeMode = widget.defaultMode;
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
      _biblicalContext = null;
      _spiritualTone = null;
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
        throw Exception(
            'El catálogo de cantos aún se está cargando. Intenta en unos segundos.');
      }
      if (!mounted) return;

      final searchResponse = await GeminiAiService.searchHymnsSemantically(
        context: context,
        query: query,
        catalog: allHymns,
        allowedCollections: _selectedCollections,
        searchMode: _activeMode,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _summary = searchResponse['summary']?.toString();
          _biblicalContext = searchResponse['biblicalContext']?.toString();
          _spiritualTone = searchResponse['spiritualTone']?.toString();
          _results =
              List<Map<String, dynamic>>.from(searchResponse['matches'] ?? []);
          _keywords = List<String>.from(searchResponse['keywords'] ?? []);
          if (_results.isEmpty) {
            _errorMessage =
                'Gemini no encontró coincidencias para esta búsqueda. Intenta describir el tema bíblico con otras palabras.';
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

  Color _getMomentColor(String? moment) {
    final m = (moment ?? '').toLowerCase();
    if (m.contains('altar') || m.contains('consagra') || m.contains('entrega')) {
      return Colors.deepOrange;
    }
    if (m.contains('oración') || m.contains('afligid') || m.contains('enferm')) {
      return Colors.indigo;
    }
    if (m.contains('sellar') || m.contains('predica') || m.contains('mensaje')) {
      return Colors.teal;
    }
    if (m.contains('congrega') || m.contains('apertura')) {
      return Colors.green.shade700;
    }
    return Colors.amber.shade800;
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
        horizontal: isCompact ? 14 : 36,
        vertical: isCompact ? 20 : 32,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: size.height * 0.90,
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
                        colors: [Colors.amber.shade600, Colors.deepOrange.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Asistente Bíblico con IA',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Gemini Flash',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Exégesis de predicación, contexto bíblico y búsqueda de cantos',
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
              const SizedBox(height: 14),

              // Selector de Modo (Pestañas Segmentadas)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'biblical',
                    icon: Icon(Icons.menu_book_rounded, size: 16),
                    label: Text('Predicación / Cita Bíblica'),
                  ),
                  ButtonSegment<String>(
                    value: 'conceptual',
                    icon: Icon(Icons.lightbulb_outline_rounded, size: 16),
                    label: Text('Búsqueda por Tema / Metáfora'),
                  ),
                ],
                selected: {_activeMode},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _activeMode = newSelection.first;
                  });
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

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
                        hintText: _activeMode == 'biblical'
                            ? 'Ej: Romanos 8:28 / Salmo 91 / El pastor predicó sobre vencer el desánimo...'
                            : 'Ej: Himnos que hablen del mar tempestuoso o de la armadura de Dios...',
                        hintStyle: GoogleFonts.nunito(fontSize: 13, color: Colors.grey),
                        prefixIcon: Icon(
                          _activeMode == 'biblical'
                              ? Icons.auto_stories_rounded
                              : Icons.search_rounded,
                          size: 20,
                        ),
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
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                              Text('Analizar', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filtros de colecciones
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
              const SizedBox(height: 6),

              // Chips de sugerencia rápida según modo
              if (_results.isEmpty && !_isLoading && _errorMessage == null) ...[
                Text(
                  _activeMode == 'biblical'
                      ? 'Pasajes célebres y temas para ministrar:'
                      : 'Conceptos y metáforas populares:',
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
                    itemCount: _activeMode == 'biblical'
                        ? _biblicalSuggestions.length
                        : _conceptualSuggestions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final item = _activeMode == 'biblical'
                          ? _biblicalSuggestions[idx]
                          : _conceptualSuggestions[idx];
                      return ActionChip(
                        label: Text(item['title']!, style: GoogleFonts.nunito(fontSize: 11)),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100,
                        onPressed: () {
                          _controller.text = item['query']!;
                          _performSearch();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const Divider(height: 14),

              // Cuerpo con Resultados / Loading / Error
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
            const SizedBox(height: 18),
            Text(
              _activeMode == 'biblical'
                  ? 'Analizando contexto bíblico y teológico...'
                  : 'Buscando metáforas y conceptos en el catálogo...',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Gemini IA está cruzando las Escrituras con el catálogo de himnos y coros',
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
              _activeMode == 'biblical'
                  ? Icons.menu_book_rounded
                  : Icons.search_rounded,
              size: 52,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 12),
            Text(
              _activeMode == 'biblical'
                  ? 'Ingresa una cita bíblica o el resumen de la predicación'
                  : 'Ingresa cualquier temática, metáfora o frase de alabanza',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Gemini entenderá el contexto espiritual y te sugerirá los cantos más idóneos para ministrar',
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
        // Tarjeta de Exégesis Bíblica / Contexto Doctrinal
        if ((_biblicalContext != null && _biblicalContext!.isNotEmpty) ||
            (_summary != null && _summary!.isNotEmpty))
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.blueGrey.shade900, Colors.black]
                    : [Colors.amber.shade50, Colors.orange.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _activeMode == 'biblical'
                          ? Icons.auto_stories_rounded
                          : Icons.lightbulb_outline_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _activeMode == 'biblical'
                          ? 'Contexto Bíblico & Exhortación'
                          : 'Interpretación Espiritual',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                      ),
                    ),
                    const Spacer(),
                    if (_spiritualTone != null && _spiritualTone!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🕊️ $_spiritualTone',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_biblicalContext != null && _biblicalContext!.isNotEmpty)
                  Text(
                    _biblicalContext!,
                    style: GoogleFonts.nunito(
                      fontSize: 12.5,
                      height: 1.35,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                if (_summary != null && _summary!.isNotEmpty && _summary != _biblicalContext) ...[
                  if (_biblicalContext != null && _biblicalContext!.isNotEmpty)
                    const SizedBox(height: 4),
                  Text(
                    _summary!,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
                if (_keywords.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _keywords
                        .map((kw) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$kw',
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ))
                        .toList(),
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
              final moment = item['worshipMoment'] as String?;
              final colColor = _getCollectionColor(hymn.collection, theme);
              final momentColor = _getMomentColor(moment);

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
                            const SizedBox(width: 8),
                            if (moment != null && moment.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: momentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.label_important_outline_rounded,
                                        size: 12, color: momentColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      moment,
                                      style: GoogleFonts.nunito(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: momentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Spacer(),
                            if (hymn.toneNote.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hymn.toneNote,
                                  style: GoogleFonts.outfit(
                                      fontSize: 11, fontWeight: FontWeight.w600),
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
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.grey.shade50,
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
