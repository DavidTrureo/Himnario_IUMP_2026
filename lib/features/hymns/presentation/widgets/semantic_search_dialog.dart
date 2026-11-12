import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/gemini_ai_service.dart';
import '../../../../core/services/hymn_semantic_retriever.dart';
import '../../domain/hymn.dart';
import '../hymn_list_screen.dart';

typedef SemanticSearchExecutor = Future<Map<String, dynamic>> Function({
  required BuildContext context,
  required String query,
  required List<Hymn> catalog,
  Set<String>? allowedCollections,
  String searchMode,
});

class SemanticSearchDialog extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String defaultMode; // 'simple', 'biblical' o 'conceptual'
  final SemanticSearchExecutor? searchExecutor;

  const SemanticSearchDialog({
    super.key,
    this.initialQuery,
    this.defaultMode = 'simple',
    this.searchExecutor,
  });

  @override
  ConsumerState<SemanticSearchDialog> createState() =>
      _SemanticSearchDialogState();
}

class _SemanticSearchDialogState extends ConsumerState<SemanticSearchDialog> {
  late final TextEditingController _controller;
  late String _activeMode; // 'simple', 'biblical' o 'conceptual'
  bool _isLoading = false;
  bool _isContextCardCollapsed = false;
  bool _hasSearchedAi = false;
  String? _lastAiMode;
  bool _fromCache = false;
  bool _isLocalFallback = false;
  bool _quotaReached = false;
  String? _errorMessage;
  String? _summary;
  String? _biblicalPassage;
  String? _biblicalContext;
  String? _spiritualTone;
  List<Map<String, dynamic>> _results = [];
  Map<String, Map<String, dynamic>> _collectionResults = {};
  Map<String, AdditionalMatchesPool> _extraPools = {};
  Map<String, int> _extraLoadedCountByCol = {};
  Map<String, int> _extraBatchesByCol = {};
  String _activeResultCollection = 'iump';
  List<String> _keywords = [];
  final Set<String> _selectedCollections = {'iump', 'especiales', 'coros'};

  final List<Map<String, String>> _simpleSuggestions = [
    {'title': 'Alabanzas de Honra', 'query': 'honra'},
    {'title': 'Gratitud y Gracias', 'query': 'gracias'},
    {'title': 'Espíritu Santo', 'query': 'Espíritu Santo'},
    {'title': 'Victoria en Cristo', 'query': 'victoria'},
    {'title': 'Consagración', 'query': 'consagración'},
    {'title': 'La Cruz', 'query': 'cruz'},
  ];

  final List<Map<String, String>> _biblicalSuggestions = [
    {
      'title': 'Salmo 23 (Valle de sombra)',
      'query': 'aunque ande en valle de sombra de muerte no temeré mal alguno',
    },
    {
      'title': 'Isaías 43 (Aguas y fuego)',
      'query': 'cuando pases por las aguas yo estaré contigo y por los ríos no te anegarán',
    },
    {
      'title': '1 Reyes 19 (Elías desanimado)',
      'query': 'el profeta Elías cansado en el desierto debajo del enebro pidiendo la muerte',
    },
    {
      'title': 'Efesios 6 (Armadura)',
      'query': 'vestíos de toda la armadura de Dios para estar firmes contra las asechanzas del enemigo',
    },
    {
      'title': 'Isaías 40 (Águilas/Fuerzas)',
      'query': 'los que esperan a Jehová tendrán nuevas fuerzas levantarán alas como las águilas',
    },
    {
      'title': 'Isaías 53 (La Cruz y Sanidad)',
      'query': 'herido fue por nuestras rebeliones y por su llaga fuimos nosotros curados',
    },
    {
      'title': 'Lucas 15 (Hijo Pródigo)',
      'query': 'el hijo pródigo que regresa arrepentido pidiendo perdón a su padre',
    },
    {
      'title': 'Hechos 2 (Pentecostés)',
      'query': 'el derramamiento del Espíritu Santo como viento recio y fuego de Pentecostés',
    },
    {
      'title': 'Llamado al Altar',
      'query': 'mensaje de quebrantamiento, arrepentimiento, entrega total y consagración a Dios',
    },
    {
      'title': 'Consuelo en Aflicción',
      'query': 'palabra de consuelo, paz y fortaleza en medio del dolor, lágrimas y prueba difícil',
    },
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

  List<String> _orderedSelectedCollections() {
    return HymnSemanticRetriever.collectionOrder
        .where(_selectedCollections.contains)
        .toList();
  }

  Map<String, Map<String, dynamic>> _parseCollectionPayload(
    Map<String, dynamic> searchResponse,
    List<Map<String, dynamic>> flatMatches,
  ) {
    final orderedCols = _orderedSelectedCollections();
    final rawCols = searchResponse['collections'];
    final parsed = <String, Map<String, dynamic>>{};

    if (rawCols is Map) {
      for (final col in orderedCols) {
        final rawEntry = rawCols[col];
        if (rawEntry is Map) {
          final matches = List<Map<String, dynamic>>.from(
            (rawEntry['matches'] as List?) ?? const [],
          );
          final rawReason = rawEntry['noMoreReason']?.toString().trim() ?? '';
          final reason = rawReason.isNotEmpty
              ? rawReason
              : HymnSemanticRetriever.buildDefaultNoMoreReason(
                  collection: col,
                  foundCount: matches.length,
                );
          parsed[col] = {
            'matches': matches,
            'noMoreReason': reason,
          };
        }
      }
    }

    // Respaldo si alguna fuente antigua devolvió solo lista plana
    for (final col in orderedCols) {
      if (parsed.containsKey(col)) continue;
      final colMatches = flatMatches.where((item) {
        final hymn = item['hymn'];
        return hymn is Hymn && hymn.collection == col;
      }).take(HymnSemanticRetriever.maxResultsPerCollection).toList();
      parsed[col] = {
        'matches': colMatches,
        'noMoreReason': HymnSemanticRetriever.buildDefaultNoMoreReason(
          collection: col,
          foundCount: colMatches.length,
        ),
      };
    }

    return parsed;
  }

  String _pickInitialActiveCollection(
    Map<String, Map<String, dynamic>> colResults,
  ) {
    final ordered = _orderedSelectedCollections();
    for (final col in ordered) {
      final matches = colResults[col]?['matches'] as List?;
      if (matches != null && matches.isNotEmpty) {
        return col;
      }
    }
    return ordered.isNotEmpty ? ordered.first : 'iump';
  }

  List<Map<String, dynamic>> _displayedMatchesFor(String col) {
    final base = List<Map<String, dynamic>>.from(
      (_collectionResults[col]?['matches'] as List?) ?? const [],
    );
    final loadedExtra = _extraLoadedCountByCol[col] ?? 0;
    if (loadedExtra <= 0) return base;
    final pool = _extraPools[col];
    if (pool == null || pool.candidates.isEmpty) return base;
    return [
      ...base,
      ...pool.candidates.take(loadedExtra),
    ];
  }

  int _remainingExtraCountFor(String col) {
    final pool = _extraPools[col];
    if (pool == null || pool.candidates.isEmpty) return 0;
    final batches = _extraBatchesByCol[col] ?? 0;
    if (batches >= HymnSemanticRetriever.maxAdditionalBatchesPerCollection) {
      return 0;
    }
    final loaded = _extraLoadedCountByCol[col] ?? 0;
    return math.max(0, pool.candidates.length - loaded);
  }

  void _loadMoreForCollection(String col) {
    final pool = _extraPools[col];
    if (pool == null) return;
    final batches = _extraBatchesByCol[col] ?? 0;
    if (batches >= HymnSemanticRetriever.maxAdditionalBatchesPerCollection) {
      return;
    }
    final loaded = _extraLoadedCountByCol[col] ?? 0;
    final remaining = pool.candidates.length - loaded;
    if (remaining <= 0) return;

    final step = math.min(
      HymnSemanticRetriever.additionalBatchSize,
      remaining,
    );
    setState(() {
      _extraLoadedCountByCol = {
        ..._extraLoadedCountByCol,
        col: loaded + step,
      };
      _extraBatchesByCol = {
        ..._extraBatchesByCol,
        col: batches + 1,
      };
    });
  }

  void _runKeywordSearch(String keyword) {
    final clean = keyword.trim();
    if (clean.isEmpty) return;
    _controller.text = clean;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    _performSearch();
  }

  void _performSimpleSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasSearchedAi = false;
        _lastAiMode = null;
        _fromCache = false;
        _isLocalFallback = false;
        _quotaReached = false;
        _errorMessage = null;
        _results = [];
        _collectionResults = {};
        _extraPools = {};
        _extraLoadedCountByCol = {};
        _extraBatchesByCol = {};
        _summary = null;
        _biblicalPassage = null;
        _biblicalContext = null;
        _spiritualTone = null;
        _keywords = [];
      });
      return;
    }

    final allHymns = ref.read(allHymnsGlobalProvider).value ?? [];
    if (allHymns.isEmpty) {
      setState(() {
        _isLoading = true;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _performSimpleSearch();
      });
      return;
    }

    final filtered = allHymns.where((h) {
      if (!_selectedCollections.contains(h.collection)) return false;
      return h.matchesSearch(query);
    }).toList();

    final normQuery = Hymn.normalizeString(query);
    filtered.sort((a, b) {
      // 1. Coincidencia exacta de ID
      final aId = a.id.toString() == query ? 1 : 0;
      final bId = b.id.toString() == query ? 1 : 0;
      if (aId != bId) return bId.compareTo(aId);

      // 2. Coincidencia en título
      final aTitle = a.normalizedTitle.contains(normQuery) ? 1 : 0;
      final bTitle = b.normalizedTitle.contains(normQuery) ? 1 : 0;
      if (aTitle != bTitle) return bTitle.compareTo(aTitle);

      // 3. Prioridad de colección
      final priorityA = a.collection == 'iump' ? 1 : (a.collection == 'especiales' ? 2 : 3);
      final priorityB = b.collection == 'iump' ? 1 : (b.collection == 'especiales' ? 2 : 3);
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);

      return a.id.compareTo(b.id);
    });

    final matches = filtered.take(30).map((h) {
      return {
        'hymn': h,
        'relevanceReason': 'Coincidencia directa con "$query"',
        'spiritualMoment': 'Búsqueda por Título',
      };
    }).toList();

    setState(() {
      _isLoading = false;
      _hasSearchedAi = false;
      _lastAiMode = null;
      _fromCache = false;
      _isLocalFallback = false;
      _quotaReached = false;
      _errorMessage = matches.isEmpty
          ? 'No se encontraron cantos con "$query" en las colecciones seleccionadas.'
          : null;
      _summary = matches.isNotEmpty
          ? 'Se encontraron ${matches.length} cantos que coinciden directamente con "$query":'
          : null;
      _biblicalPassage = null;
      _biblicalContext = null;
      _spiritualTone = null;
      _results = matches;
      _collectionResults = {};
      _extraPools = {};
      _extraLoadedCountByCol = {};
      _extraBatchesByCol = {};
      _keywords = [];
    });
  }

  Future<void> _performSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    if (_activeMode == 'simple') {
      _performSimpleSearch();
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasSearchedAi = false;
      _fromCache = false;
      _isLocalFallback = false;
      _quotaReached = false;
      _errorMessage = null;
      _results = [];
      _collectionResults = {};
      _extraPools = {};
      _extraLoadedCountByCol = {};
      _extraBatchesByCol = {};
      _summary = null;
      _biblicalPassage = null;
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

      final executor =
          widget.searchExecutor ?? GeminiAiService.searchHymnsSemantically;
      final searchResponse = await executor(
        context: context,
        query: query,
        catalog: allHymns,
        allowedCollections: Set<String>.from(_selectedCollections),
        searchMode: _activeMode,
      );

      final flatMatches =
          List<Map<String, dynamic>>.from(searchResponse['matches'] ?? []);
      final colResults = _parseCollectionPayload(searchResponse, flatMatches);
      final initialTab = _pickInitialActiveCollection(colResults);

      final excludedIdsByCol = <String, Set<int>>{};
      for (final entry in colResults.entries) {
        final ids = <int>{};
        final list = entry.value['matches'] as List?;
        if (list != null) {
          for (final item in list) {
            if (item is Map && item['hymn'] is Hymn) {
              ids.add((item['hymn'] as Hymn).id);
            }
          }
        }
        excludedIdsByCol[entry.key] = ids;
      }

      final extraPools = HymnSemanticRetriever.findAdditionalMatchesByCollection(
        query: query,
        catalog: allHymns,
        excludedIdsByCollection: excludedIdsByCol,
        allowedCollections: Set<String>.from(_selectedCollections),
        searchMode: _activeMode,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasSearchedAi = true;
          _lastAiMode = _activeMode;
          _fromCache = searchResponse['fromCache'] == true;
          _isLocalFallback = searchResponse['isLocalFallback'] == true;
          _quotaReached = searchResponse['quotaReached'] == true;
          _summary = searchResponse['summary']?.toString();
          _biblicalPassage = searchResponse['biblicalPassage']?.toString();
          _biblicalContext = searchResponse['biblicalContext']?.toString();
          _spiritualTone = searchResponse['spiritualTone']?.toString();
          _results = flatMatches;
          _collectionResults = colResults;
          _extraPools = extraPools;
          _extraLoadedCountByCol = {};
          _extraBatchesByCol = {};
          _activeResultCollection = initialTab;
          _keywords = List<String>.from(searchResponse['keywords'] ?? []);
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasSearchedAi = false;
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
          padding: EdgeInsets.all(isCompact ? 14.0 : 20.0),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Asistente Bíblico con IA',
                              style: GoogleFonts.outfit(
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Gemini 2.5 Flash',
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
                    icon: const Icon(Icons.vpn_key_rounded, size: 20),
                    tooltip: 'Configurar Clave API',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final newKey = await GeminiAiService.showApiKeyInputDialog(
                        context,
                        reason: 'Configura o actualiza tu Clave API de Gemini (Google AI Studio) para el Asistente Bíblico:',
                      );
                      if (newKey != null && newKey.isNotEmpty && mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Clave API actualizada correctamente'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        if (_controller.text.trim().isNotEmpty) {
                          _performSearch();
                        }
                      }
                    },
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
                showSelectedIcon: false,
                segments: [
                  ButtonSegment<String>(
                    value: 'simple',
                    icon: const Icon(Icons.search_rounded, size: 15),
                    label: Text(
                      isCompact ? 'Título' : 'Búsqueda Simple',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment<String>(
                    value: 'biblical',
                    icon: const Icon(Icons.menu_book_rounded, size: 15),
                    label: Text(
                      isCompact ? 'Predicación' : 'Predicación / Cita',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment<String>(
                    value: 'conceptual',
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 15),
                    label: Text(
                      isCompact ? 'Tema' : 'Tema / Metáfora',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                selected: {_activeMode},
                onSelectionChanged: (Set<String> newSelection) {
                  final newMode = newSelection.first;
                  setState(() {
                    _activeMode = newMode;
                  });
                  if (newMode == 'simple') {
                    _performSimpleSearch();
                  } else if (_controller.text.trim().isNotEmpty &&
                      (!_hasSearchedAi || _lastAiMode != newMode)) {
                    _performSearch();
                  }
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: isCompact ? 4 : 10, vertical: 8),
                  ),
                  textStyle: WidgetStatePropertyAll(
                    GoogleFonts.nunito(
                      fontSize: isCompact ? 11.5 : 12,
                      fontWeight: FontWeight.bold,
                    ),
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
                        hintText: _activeMode == 'simple'
                            ? 'Buscar por título o número (ej: "Honra y gloria", "45")...'
                            : (_activeMode == 'biblical'
                                ? 'Ej: "aunque ande en valle de sombra" / "Elías en el desierto" / Romanos 8:28...'
                                : 'Ej: Himnos que hablen del mar tempestuoso o de la armadura de Dios...'),
                        hintStyle: GoogleFonts.nunito(fontSize: 13, color: Colors.grey),
                        prefixIcon: Icon(
                          _activeMode == 'simple'
                              ? Icons.search_rounded
                              : (_activeMode == 'biblical'
                                  ? Icons.auto_stories_rounded
                                  : Icons.lightbulb_outline_rounded),
                          size: 20,
                        ),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  _controller.clear();
                                  if (_activeMode == 'simple') {
                                    _performSimpleSearch();
                                  } else {
                                    setState(() {});
                                  }
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
                      onChanged: (_) {
                        if (_activeMode == 'simple') {
                          _performSimpleSearch();
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeMode == 'simple'
                          ? theme.colorScheme.primary
                          : Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 14 : 18,
                        vertical: 15,
                      ),
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
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _activeMode == 'simple'
                                    ? Icons.search_rounded
                                    : Icons.auto_awesome_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _activeMode == 'simple' ? 'Buscar' : 'Analizar',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filtros de colecciones
              Wrap(
                spacing: 6,
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
                  for (final col in HymnSemanticRetriever.collectionOrder)
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                      label: Text(_getCollectionName(col)),
                      labelStyle: GoogleFonts.nunito(fontSize: 11),
                      selected: _selectedCollections.contains(col),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedCollections.add(col);
                          } else if (_selectedCollections.length > 1) {
                            _selectedCollections.remove(col);
                          }
                          if (!_selectedCollections
                              .contains(_activeResultCollection)) {
                            _activeResultCollection =
                                _pickInitialActiveCollection(_collectionResults);
                          }
                        });
                        if (_activeMode == 'simple') {
                          _performSimpleSearch();
                        } else if (val &&
                            _hasSearchedAi &&
                            !_collectionResults.containsKey(col) &&
                            _controller.text.trim().isNotEmpty) {
                          _performSearch();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Chips de sugerencia rápida según modo
              if (!_hasSearchedAi && _results.isEmpty && !_isLoading && _errorMessage == null) ...[
                Text(
                  _activeMode == 'simple'
                      ? 'Búsquedas rápidas sugeridas:'
                      : (_activeMode == 'biblical'
                          ? 'Pasajes célebres y temas para ministrar:'
                          : 'Conceptos y metáforas populares:'),
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
                    itemCount: _activeMode == 'simple'
                        ? _simpleSuggestions.length
                        : (_activeMode == 'biblical'
                            ? _biblicalSuggestions.length
                            : _conceptualSuggestions.length),
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final item = _activeMode == 'simple'
                          ? _simpleSuggestions[idx]
                          : (_activeMode == 'biblical'
                              ? _biblicalSuggestions[idx]
                              : _conceptualSuggestions[idx]);
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
                child: _buildBody(context, theme, isDark, isCompact),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, ThemeData theme, bool isDark, bool isCompact) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              _activeMode == 'biblical'
                  ? 'Analizando contexto bíblico y letras completas...'
                  : 'Explorando metáforas y estrofas en toda la base...',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Buscando hasta 10 coincidencias reales en Himnario IUMP, Especiales y Coros',
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

    final isAiStructuredView = _activeMode != 'simple' && _hasSearchedAi;

    if (!isAiStructuredView && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _activeMode == 'simple'
                  ? Icons.search_rounded
                  : (_activeMode == 'biblical'
                      ? Icons.menu_book_rounded
                      : Icons.lightbulb_outline_rounded),
              size: 52,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 12),
            Text(
              _activeMode == 'simple'
                  ? 'Escribe el título o número de cualquier alabanza'
                  : (_activeMode == 'biblical'
                      ? 'Escribe un versículo, una frase bíblica o lo predicado'
                      : 'Ingresa cualquier temática, metáfora o frase de alabanza'),
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _activeMode == 'simple'
                  ? 'Búsqueda instantánea en el Himnario IUMP, Coros y Especiales en tiempo real.'
                  : (_activeMode == 'biblical'
                      ? 'Analizará las letras reales y te mostrará hasta 10 cantos afines por colección.'
                      : 'Interpretará la figura poética y seleccionará hasta 10 cantos por colección.'),
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

    final hasContext = (_biblicalContext != null && _biblicalContext!.isNotEmpty) ||
        (_summary != null && _summary!.isNotEmpty);

    if (!isAiStructuredView) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _results.length + (hasContext ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (hasContext && index == 0) {
            return _buildContextCard(context, theme, isDark, isCompact);
          }
          final resultIndex = hasContext ? index - 1 : index;
          return _buildHymnResultCard(
            context,
            theme,
            isDark,
            _results[resultIndex],
          );
        },
      );
    }

    final orderedCols = _orderedSelectedCollections();
    final activeCol = orderedCols.contains(_activeResultCollection)
        ? _activeResultCollection
        : (orderedCols.isNotEmpty ? orderedCols.first : 'iump');
    final activePayload = _collectionResults[activeCol];
    final activeMatches = _displayedMatchesFor(activeCol);
    final rawNoMore = activePayload?['noMoreReason']?.toString().trim() ?? '';
    final noMoreReason = rawNoMore.isNotEmpty
        ? rawNoMore
        : HymnSemanticRetriever.buildDefaultNoMoreReason(
            collection: activeCol,
            foundCount: activeMatches.length,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCollectionResultTabs(context, theme, isDark, isCompact, orderedCols, activeCol),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            key: const ValueKey('ai_results_listview'),
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (hasContext) ...[
                _buildContextCard(context, theme, isDark, isCompact),
                const SizedBox(height: 10),
              ],
              if (activeMatches.isEmpty)
                _buildCollectionEmptyState(
                  context,
                  theme,
                  isDark,
                  activeCol,
                  noMoreReason,
                  orderedCols,
                )
              else ...[
                for (int i = 0; i < activeMatches.length; i++) ...[
                  _buildHymnResultCard(
                    context,
                    theme,
                    isDark,
                    activeMatches[i],
                    rank: i + 1,
                  ),
                  if (i < activeMatches.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                _buildCollectionStatusBanner(
                  context,
                  theme,
                  isDark,
                  activeCol,
                  activeMatches.length,
                  noMoreReason,
                  orderedCols,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionResultTabs(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isCompact,
    List<String> orderedCols,
    String activeCol,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < orderedCols.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final col = orderedCols[i];
                final count = _displayedMatchesFor(col).length;
                final isSelected = col == activeCol;
                final colColor = _getCollectionColor(col, theme);
                final shortLabel = (isCompact && col == 'iump')
                    ? 'Himnario'
                    : _getCollectionName(col);

                return InkWell(
                  key: ValueKey('ai_collection_tab_$col'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _activeResultCollection = col;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colColor.withValues(alpha: isDark ? 0.28 : 0.14)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? colColor
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shortLabel,
                          style: GoogleFonts.outfit(
                            fontSize: isCompact ? 12 : 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? (isDark ? Colors.white : colColor)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: count > 0
                                ? colColor.withValues(alpha: isSelected ? 0.9 : 0.18)
                                : (isDark ? Colors.white12 : Colors.black12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: count > 0
                                  ? (isSelected ? Colors.white : colColor)
                                  : (isDark ? Colors.white54 : Colors.black54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  List<String> _otherCollectionsWithMatches(
    String currentCol,
    List<String> orderedCols,
  ) {
    return orderedCols.where((col) {
      if (col == currentCol) return false;
      return _displayedMatchesFor(col).isNotEmpty;
    }).toList();
  }

  Widget _buildCollectionStatusBanner(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    String col,
    int count,
    String noMoreReason,
    List<String> orderedCols,
  ) {
    final otherWithMatches = _otherCollectionsWithMatches(col, orderedCols);
    final baseCount =
        ((_collectionResults[col]?['matches'] as List?) ?? const []).length;
    final loadedExtra = _extraLoadedCountByCol[col] ?? 0;
    final loadedBatches = _extraBatchesByCol[col] ?? 0;
    final hasLoadedExtra = loadedExtra > 0;
    final pool = _extraPools[col];
    final remainingExtra = _remainingExtraCountFor(col);
    final nextBatchSize = math.min(
      HymnSemanticRetriever.additionalBatchSize,
      remainingExtra,
    );
    final isFull = baseCount >= HymnSemanticRetriever.maxResultsPerCollection;
    final colColor = _getCollectionColor(col, theme);
    final colFullName = HymnSemanticRetriever.collectionDisplayName(col);

    final String headerTitle;
    if (hasLoadedExtra) {
      final initialLabel = _isLocalFallback ? 'iniciales' : 'IA';
      headerTitle =
          '$count cantos mostrados en $colFullName ($baseCount $initialLabel + $loadedExtra locales)';
    } else if (isFull) {
      headerTitle = 'Top $count más certeros en $colFullName';
    } else {
      headerTitle =
          '$count ${count == 1 ? "canto encontrado" : "cantos encontrados"} en $colFullName';
    }

    final String bodyText;
    if (remainingExtra > 0) {
      if (hasLoadedExtra) {
        bodyText =
            'Se agregaron $loadedExtra sugerencias locales verificadas. Quedan $remainingExtra más dentro del margen temático de tu búsqueda.';
      } else {
        bodyText =
            'Se seleccionaron los $baseCount cantos de $colFullName con mayor fidelidad bíblica y temática a tu búsqueda. Si no conoces estas melodías, puedes explorar coincidencias locales adicionales sin gastar cuota de IA.';
      }
    } else if (hasLoadedExtra) {
      bodyText = pool?.exhaustReason ?? noMoreReason;
    } else if (isFull) {
      bodyText = (pool != null && pool.stoppedForDrift)
          ? 'Se seleccionaron los $count cantos de $colFullName con mayor fidelidad bíblica y temática a tu búsqueda. ${pool.exhaustReason}'
          : 'Se seleccionaron los $count cantos de $colFullName con mayor fidelidad bíblica y temática a tu búsqueda.';
    } else {
      bodyText = noMoreReason;
    }

    return Container(
      key: ValueKey('ai_collection_footer_$col'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isFull
            ? colColor.withValues(alpha: isDark ? 0.12 : 0.06)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.amber.shade50.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFull
              ? colColor.withValues(alpha: 0.25)
              : Colors.amber.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFull
                    ? Icons.verified_rounded
                    : Icons.auto_awesome_motion_rounded,
                size: 16,
                color: isFull
                    ? colColor
                    : (isDark ? Colors.amber.shade300 : Colors.amber.shade800),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headerTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            bodyText,
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              height: 1.35,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          if (remainingExtra > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: ValueKey('ai_load_more_$col'),
                onPressed: () => _loadMoreForCollection(col),
                icon: Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: colColor,
                ),
                label: Text(
                  'Mostrar $nextBatchSize más afines (${_getCollectionName(col)}) · $remainingExtra disp.',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colColor,
                  side: BorderSide(color: colColor.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Búsqueda local en el dispositivo (\$0 cuota IA) · bloque ${loadedBatches + 1} de ${HymnSemanticRetriever.maxAdditionalBatchesPerCollection}, se detiene si los cantos se alejan del tema.',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
          if (!isFull && otherWithMatches.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final other in otherWithMatches)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: _getCollectionColor(other, theme),
                    ),
                    label: Text(
                      'Ver ${_displayedMatchesFor(other).length} en ${_getCollectionName(other)}',
                      style: GoogleFonts.nunito(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _activeResultCollection = other;
                      });
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionEmptyState(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    String col,
    String noMoreReason,
    List<String> orderedCols,
  ) {
    final colColor = _getCollectionColor(col, theme);
    final colFullName = HymnSemanticRetriever.collectionDisplayName(col);
    final otherWithMatches = _otherCollectionsWithMatches(col, orderedCols);

    return Container(
      key: ValueKey('ai_collection_empty_$col'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.library_music_outlined,
                  size: 20,
                  color: colColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sin coincidencias en $colFullName',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            noMoreReason,
            style: GoogleFonts.nunito(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          if (otherWithMatches.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Opciones disponibles en otras colecciones:',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final other in otherWithMatches)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _getCollectionColor(other, theme),
                      side: BorderSide(
                        color: _getCollectionColor(other, theme)
                            .withValues(alpha: 0.5),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.music_note_rounded, size: 15),
                    label: Text(
                      '${_getCollectionName(other)} (${(_collectionResults[other]?['matches'] as List).length})',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _activeResultCollection = other;
                      });
                    },
                  ),
              ],
            ),
          ],
          if (_keywords.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Toca un concepto relacionado para ampliar la búsqueda:',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final kw in _keywords)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '#$kw',
                      style: GoogleFonts.nunito(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _runKeywordSearch(kw),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContextCard(
      BuildContext context, ThemeData theme, bool isDark, bool isCompact) {
    final String sourceLabel;
    final IconData sourceIcon;
    if (_fromCache) {
      sourceLabel = 'Caché instantánea';
      sourceIcon = Icons.bolt_rounded;
    } else if (_isLocalFallback) {
      sourceLabel = _quotaReached
          ? 'Búsqueda local profunda (cuota IA pausada)'
          : 'Búsqueda local profunda (sin conexión)';
      sourceIcon = Icons.offline_bolt_outlined;
    } else {
      sourceLabel = 'IA · Análisis completo de letras';
      sourceIcon = Icons.auto_awesome_rounded;
    }

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _isContextCardCollapsed = !_isContextCardCollapsed;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                    Expanded(
                      child: Text(
                        _activeMode == 'biblical'
                            ? 'Contexto Bíblico & Exhortación'
                            : 'Interpretación Espiritual',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    if (_spiritualTone != null && _spiritualTone!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isCompact ? 120 : 180),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🕊️ $_spiritualTone',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      _isContextCardCollapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                      size: 20,
                    ),
                  ],
                ),
                if (!_isContextCardCollapsed) ...[
                  if (_hasSearchedAi) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            sourceIcon,
                            size: 12,
                            color: isDark
                                ? Colors.amber.shade200
                                : Colors.amber.shade900,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            sourceLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.amber.shade200
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_biblicalPassage != null && _biblicalPassage!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Pasaje Bíblico: $_biblicalPassage',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: _keywords
                          .map(
                            (kw) => InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => _runKeywordSearch(kw),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.black.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  '#$kw',
                                  style: GoogleFonts.nunito(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ] else if (_biblicalPassage != null && _biblicalPassage!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '📖 $_biblicalPassage • Toca para ver el análisis completo',
                    style: GoogleFonts.nunito(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.amber.shade200.withValues(alpha: 0.8) : Colors.amber.shade900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHymnResultCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> item, {
    int? rank,
  }) {
    final Hymn hymn = item['hymn'] as Hymn;
    final reason = item['relevanceReason'] as String? ?? '';
    final moment = item['worshipMoment'] as String?;
    final isExtraLocal = item['isExtraLocal'] == true;
    final relevanceLevel =
        (item['relevanceLevel']?.toString().toLowerCase().trim() ?? '');
    final colColor = _getCollectionColor(hymn.collection, theme);
    final momentColor = _getMomentColor(moment);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
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
                  if (rank != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? colColor
                            : colColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$rank',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rank <= 3 ? Colors.white : colColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
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
                  if (moment != null && moment.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: momentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.label_important_outline_rounded,
                              size: 12,
                              color: momentColor,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                moment,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: momentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                  ],
                  if (isExtraLocal) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: colColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colColor.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        'Adicional local',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : colColor,
                        ),
                      ),
                    ),
                  ] else if (relevanceLevel == 'directa' ||
                      relevanceLevel == 'alta') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: (relevanceLevel == 'directa'
                                ? Colors.green
                                : Colors.amber.shade700)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        relevanceLevel == 'directa'
                            ? 'Acierto directo'
                            : 'Alta afinidad',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: relevanceLevel == 'directa'
                              ? (isDark
                                  ? Colors.green.shade300
                                  : Colors.green.shade800)
                              : (isDark
                                  ? Colors.amber.shade300
                                  : Colors.amber.shade900),
                        ),
                      ),
                    ),
                  ],
                  if (hymn.toneNote.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Text(
                        hymn.toneNote,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
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
  }
}
