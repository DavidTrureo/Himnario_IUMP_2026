import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/hymn.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../favorites/domain/favorites_notifier.dart';

// Notifier para la colección activa ('iump', 'especiales', etc.)
class ActiveCollectionNotifier extends Notifier<String> {
  @override
  String build() => 'iump';

  void setCollection(String collection) {
    state = collection;
  }
}

final activeCollectionProvider = NotifierProvider<ActiveCollectionNotifier, String>(() {
  return ActiveCollectionNotifier();
});

// Provider asíncrono para cargar todos los himnos
final allHymnsProvider = Provider<AsyncValue<List<Hymn>>>((ref) {
  final collection = ref.watch(activeCollectionProvider);
  return ref.watch(hymnsProvider(collection));
});

// Provider asíncrono para cargar todos los himnos de todas las colecciones (para favoritos)
final allHymnsGlobalProvider = Provider<AsyncValue<List<Hymn>>>((ref) {
  final list1 = ref.watch(hymnsProvider('iump'));
  final list2 = ref.watch(hymnsProvider('especiales'));
  final list3 = ref.watch(hymnsProvider('coros'));

  if (list1.isLoading || list2.isLoading || list3.isLoading) {
    return const AsyncValue.loading();
  }
  if (list1.hasError) return AsyncValue.error(list1.error!, list1.stackTrace!);
  if (list2.hasError) return AsyncValue.error(list2.error!, list2.stackTrace!);
  if (list3.hasError) return AsyncValue.error(list3.error!, list3.stackTrace!);

  return AsyncValue.data([
    ...list1.value ?? [],
    ...list2.value ?? [],
    ...list3.value ?? [],
  ]);
});

// Función de alto nivel (debe ser top-level para poder usarse en compute)
Set<String> findDuplicatesWorker(Map<String, dynamic> args) {
  final List<Hymn> allHymns = args['hymns'] as List<Hymn>;
  final Set<String> ignoredPairs = args['ignoredPairs'] as Set<String>;
  final Set<String> duplicateKeys = {};
  
  final List<Map<String, dynamic>> normalizedList = allHymns.map((h) {
    final cleanLyrics = h.lyrics.replaceAll(RegExp(r'\[[^\]]*\]'), '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final List<String> trigrams = [];
    for (int k = 0; k < cleanLyrics.length - 2; k++) {
      trigrams.add(cleanLyrics.substring(k, k + 3));
    }
    return {
      'key': '${h.collection}-${h.id}',
      'collection': h.collection,
      'id': h.id,
      'title': h.title,
      'normTitle': h.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim(),
      'cleanLyrics': cleanLyrics,
      'trigramsSet': Set<String>.from(trigrams),
    };
  }).toList();

  for (int i = 0; i < normalizedList.length; i++) {
    final item1 = normalizedList[i];
    final String key1 = item1['key'];
    final String normTitle1 = item1['normTitle'];
    final String cleanLyrics1 = item1['cleanLyrics'];
    final Set<String> trigramsSet1 = item1['trigramsSet'] as Set<String>;
    final String col1 = item1['collection'];
    final int id1 = item1['id'];

    for (int j = i + 1; j < normalizedList.length; j++) {
      final item2 = normalizedList[j];
      final String key2 = item2['key'];
      final String col2 = item2['collection'];
      final int id2 = item2['id'];
      
      if (col1 == col2 && id1 == id2) continue;

      // Si la pareja de cantos ya fue confirmada como no duplicada, la omitimos
      if (ignoredPairs.contains('${key1}_${key2}') || ignoredPairs.contains('${key2}_${key1}')) {
        continue;
      }

      // 1. Títulos idénticos
      final String normTitle2 = item2['normTitle'];
      if (normTitle1.length > 3 && normTitle1 == normTitle2) {
        duplicateKeys.add(key1);
        duplicateKeys.add(key2);
        continue;
      }

      // 2. Letras idénticas
      final String cleanLyrics2 = item2['cleanLyrics'];
      if (cleanLyrics1 == cleanLyrics2 && cleanLyrics1.isNotEmpty) {
        duplicateKeys.add(key1);
        duplicateKeys.add(key2);
        continue;
      }

      // 3. Similitud de trigramas (solo si son suficientemente largas)
      if (cleanLyrics1.length > 50 && cleanLyrics2.length > 50) {
        final trigramsSet2 = item2['trigramsSet'] as Set<String>;
        if (trigramsSet1.isNotEmpty && trigramsSet2.isNotEmpty) {
          int intersection = 0;
          for (final t1 in trigramsSet1) {
            if (trigramsSet2.contains(t1)) intersection++;
          }
          final double similarity = (2.0 * intersection) / (trigramsSet1.length + trigramsSet2.length);
          // Usamos un umbral estricto del 85% para evitar falsos positivos
          if (similarity >= 0.85) {
            duplicateKeys.add(key1);
            duplicateKeys.add(key2);
          }
        }
      }
    }
  }

  return duplicateKeys;
}

// Provider asíncrono para precalcular claves de cantos duplicados o similares
final duplicateHymnsKeysProvider = FutureProvider<Set<String>>((ref) async {
  final allHymnsState = ref.watch(allHymnsGlobalProvider);
  final allHymns = allHymnsState.value ?? [];
  if (allHymns.isEmpty) return {};

  final prefs = await SharedPreferences.getInstance();
  final List<String> ignoredPairs = prefs.getStringList('ignored_duplicate_pairs') ?? [];
  final Set<String> ignoredPairsSet = Set<String>.from(ignoredPairs);

  final args = {
    'hymns': allHymns,
    'ignoredPairs': ignoredPairsSet,
  };

  return kIsWeb ? findDuplicatesWorker(args) : await compute(findDuplicatesWorker, args);
});

// Notifier para la búsqueda
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) {
    state = query;
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() {
  return SearchQueryNotifier();
});

// Notifier para el toggle de favoritos
class ShowFavoritesNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setFavorites(bool value) {
    state = value;
  }

  void toggle() {
    state = !state;
  }
}

final showFavoritesProvider = NotifierProvider<ShowFavoritesNotifier, bool>(() {
  return ShowFavoritesNotifier();
});

// Notifier para la categoría activa
class ActiveCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'Todos';

  void setCategory(String category) {
    state = category;
  }
}

final activeCategoryProvider = NotifierProvider<ActiveCategoryNotifier, String>(() {
  return ActiveCategoryNotifier();
});

// Provider para filtrar los himnos cargados
final filteredHymnsProvider = Provider<AsyncValue<List<Hymn>>>((ref) {
  final showFavorites = ref.watch(showFavoritesProvider);
  final activeCollection = ref.watch(activeCollectionProvider);

  final hymnsAsyncValue = (showFavorites || activeCollection == 'all' || activeCollection == 'acordes')
      ? ref.watch(allHymnsGlobalProvider) 
      : ref.watch(allHymnsProvider);
      
  final query = ref.watch(searchQueryProvider);
  final favorites = ref.watch(favoritesProvider);
  final activeCategory = ref.watch(activeCategoryProvider);

  final Map<String, List<int>> categoryNumbers = {
    'Predicación': [
      8, 13, 39, 48, 79, 85, 92, 93, 97, 119, 128, 133, 141, 155, 159, 162, 163, 
      166, 178, 182, 183, 187, 189, 192, 215, 219, 220, 230, 231, 236, 237, 238, 
      242, 244, 249, 254, 265, 273, 274, 288, 297, 300, 302, 303, 305, 314, 315, 
      316, 323, 349, 371, 395, 402, 408, 420
    ],
    'Fúnebre': [38, 40, 47, 54, 66, 123, 152, 153, 187, 266, 277, 293, 304, 351, 375, 388],
    'Santa Cena': [27],
    'Consagración': [35],
    'Adoración': [18, 43, 67, 73, 87, 109, 114, 137, 152, 170, 171, 178, 180, 193, 194, 207, 379, 406, 430, 436, 470, 471],
    'Navidad': [31, 57, 73, 74, 103, 116, 117, 118, 258, 278, 299, 399, 409],
    'Coritos': List.generate(29, (index) => 463 + index), // 463 al 491
  };

  return hymnsAsyncValue.whenData((hymns) {
    List<Hymn> result = List.from(hymns);
    
    if (activeCollection == 'especiales' || activeCollection == 'coros') {
      result.sort((a, b) => a.title.compareTo(b.title));
    }

    if (showFavorites) {
      result = result.where((hymn) => favorites.contains('${hymn.collection}-${hymn.id}')).toList();
      result.sort((a, b) => a.title.compareTo(b.title));
    } else if (activeCollection == 'all') {
      result.sort((a, b) {
        final priorityA = a.collection == 'iump' ? 1 : (a.collection == 'especiales' ? 2 : 3);
        final priorityB = b.collection == 'iump' ? 1 : (b.collection == 'especiales' ? 2 : 3);
        if (priorityA != priorityB) {
          return priorityA.compareTo(priorityB);
        }
        if (a.collection == 'iump') {
          return a.id.compareTo(b.id);
        } else {
          return a.title.compareTo(b.title);
        }
      });
    } else if (activeCollection == 'acordes') {
      result = result.where((hymn) => hymn.lyrics.contains('[')).toList();
      result.sort((a, b) {
        final priorityA = a.collection == 'iump' ? 1 : (a.collection == 'especiales' ? 2 : 3);
        final priorityB = b.collection == 'iump' ? 1 : (b.collection == 'especiales' ? 2 : 3);
        if (priorityA != priorityB) {
          return priorityA.compareTo(priorityB);
        }
        if (a.collection == 'iump') {
          return a.id.compareTo(b.id);
        } else {
          return a.title.compareTo(b.title);
        }
      });
    }
    
    if (activeCollection == 'iump' && activeCategory != 'Todos' && categoryNumbers.containsKey(activeCategory)) {
      final allowedIds = categoryNumbers[activeCategory]!;
      result = result.where((hymn) => allowedIds.contains(hymn.id)).toList();
    }
    
    if (query.isNotEmpty) {
      result = result.where((hymn) => hymn.matchesSearch(query)).toList();
    }
    
    return result;
  });
});

class HymnListScreen extends ConsumerStatefulWidget {
  const HymnListScreen({super.key});

  @override
  ConsumerState<HymnListScreen> createState() => _HymnListScreenState();
}

class _HymnListScreenState extends ConsumerState<HymnListScreen> {
  final Set<String> _selectedKeys = {}; // Formato: 'coleccion-id'
  bool _isMultiSelectMode = false;
  String _notation = 'spanish';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notation = prefs.getString('pref_chords_notation') ?? 'spanish';
      });
    }
  }

  void _showBiblicalAssistantDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const BiblicalAssistantDialog(),
    );
  }

  Future<void> _deleteSelectedHymns(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Eliminar ${_selectedKeys.length} cantos?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Esta acción eliminará de forma definitiva los ${_selectedKeys.length} cantos seleccionados de Firestore y del archivo local. ¿Confirmar?',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.nunito()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final List<String> keys = _selectedKeys.toList();
        for (final key in keys) {
          final parts = key.split('-');
          final collection = parts[0];
          final id = int.parse(parts[1]);
          await ref.read(hymnsProvider(collection).notifier).deleteHymn(id);
        }
        
        if (mounted) {
          navigator.pop(); // Cerrar loader
          setState(() {
            _selectedKeys.clear();
            _isMultiSelectMode = false;
          });
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Se eliminaron los cantos con éxito', style: GoogleFonts.nunito()),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          navigator.pop(); // Cerrar loader
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e', style: GoogleFonts.nunito()),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Future<void> _moveSelectedHymns(BuildContext context) async {
    String? targetCollection = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Trasladar ${_selectedKeys.length} cantos a:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'iump'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_outline, size: 20),
                  const SizedBox(width: 12),
                  Text('Himnario IUMP', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'especiales'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.music_note, size: 20, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 12),
                  Text('Alabanzas Especiales', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'coros'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.library_music, size: 20, color: Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  Text('Coros de Avivamiento', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (targetCollection != null) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final List<String> keys = _selectedKeys.toList();
        final allHymns = ref.read(allHymnsGlobalProvider).value ?? [];
        
        for (final key in keys) {
          final parts = key.split('-');
          final collection = parts[0];
          final id = int.parse(parts[1]);
          
          if (collection == targetCollection) continue;
          
          final hymn = allHymns.firstWhere((h) => h.collection == collection && h.id == id);
          await ref.read(hymnsProvider(collection).notifier).moveHymnTo(hymn, targetCollection);
        }

        if (mounted) {
          navigator.pop(); // Cerrar loader
          setState(() {
            _selectedKeys.clear();
            _isMultiSelectMode = false;
          });
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Se trasladaron los cantos con éxito', style: GoogleFonts.nunito()),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          navigator.pop(); // Cerrar loader
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error al trasladar: $e', style: GoogleFonts.nunito()),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredHymnsAsync = ref.watch(filteredHymnsProvider);
    final favorites = ref.watch(favoritesProvider);
    final activeCollection = ref.watch(activeCollectionProvider);
    final showFavorites = ref.watch(showFavoritesProvider);
    final activeCategory = ref.watch(activeCategoryProvider);
    final adminMode = ref.watch(adminModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String getTitle() {
      if (showFavorites) return 'Mis Favoritos';
      if (activeCollection == 'especiales') return 'Alabanzas Especiales';
      if (activeCollection == 'coros') return 'Coros de Avivamiento';
      if (activeCollection == 'all') return 'Buscador Global';
      if (activeCollection == 'acordes') return 'Acordes & Guías';
      return 'Himnario IUMP';
    }


    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Auroras decorativas de fondo
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: isDark 
                  ? const Color(0xFF6366F1).withValues(alpha: 0.08) 
                  : const Color(0xFF818CF8).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: const SizedBox(),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header fijo y elegante
                Container(
                  decoration: BoxDecoration(
                    color: isDark 
                      ? theme.colorScheme.surface.withValues(alpha: 0.8) 
                      : Colors.white.withValues(alpha: 0.8),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // AppBar Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          children: [
                            if (_isMultiSelectMode)
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  setState(() {
                                    _selectedKeys.clear();
                                    _isMultiSelectMode = false;
                                  });
                                },
                              )
                            else if (Navigator.canPop(context))
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                onPressed: () => Navigator.pop(context),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isMultiSelectMode ? '${_selectedKeys.length} seleccionados' : getTitle(),
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (!_isMultiSelectMode)
                              IconButton(
                                icon: const Icon(Icons.auto_stories_rounded),
                                tooltip: 'Asistente por Predicación/Palabra',
                                onPressed: () => _showBiblicalAssistantDialog(context, ref),
                              ),
                            if (_isMultiSelectMode) ...[
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                tooltip: 'Eliminar seleccionados',
                                onPressed: _selectedKeys.isEmpty ? null : () => _deleteSelectedHymns(context),
                              ),
                              IconButton(
                                icon: const Icon(Icons.drive_file_move_rounded),
                                tooltip: 'Trasladar seleccionados',
                                onPressed: _selectedKeys.isEmpty ? null : () => _moveSelectedHymns(context),
                              ),
                            ] else if (adminMode) ...[
                              IconButton(
                                icon: const Icon(Icons.select_all_rounded),
                                tooltip: 'Selección múltiple',
                                onPressed: () {
                                  setState(() {
                                    _isMultiSelectMode = true;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Buscador y botones rápidos
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Hero(
                                tag: 'search-bar',
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: SearchBar(
                                    hintText: 'Buscar por título, número o letra...',
                                    hintStyle: WidgetStatePropertyAll(
                                      GoogleFonts.nunito(
                                        color: isDark ? Colors.white38 : Colors.black38,
                                        fontSize: 14,
                                      ),
                                    ),
                                    leading: Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Icon(Icons.search_rounded, color: isDark ? Colors.white60 : Colors.black45),
                                    ),
                                    elevation: const WidgetStatePropertyAll(0),
                                    backgroundColor: WidgetStatePropertyAll(
                                      isDark 
                                        ? Colors.white.withValues(alpha: 0.04) 
                                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    ),
                                    onChanged: (value) {
                                      ref.read(searchQueryProvider.notifier).updateQuery(value);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (!showFavorites && activeCollection == 'iump')
                              IconButton(
                                onPressed: () => _showFilterBottomSheet(context, ref),
                                tooltip: 'Filtrar por categoría',
                                style: IconButton.styleFrom(
                                  backgroundColor: activeCategory != 'Todos'
                                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                    : (isDark ? Colors.white.withValues(alpha: 0.04) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  minimumSize: const Size(50, 50),
                                ),
                                icon: Icon(
                                  Icons.filter_list_rounded,
                                  color: activeCategory != 'Todos' ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            if (!showFavorites && activeCollection == 'iump')
                              const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                ref.read(showFavoritesProvider.notifier).toggle();
                              },
                              tooltip: showFavorites ? 'Mostrar todos' : 'Mostrar guardados',
                              style: IconButton.styleFrom(
                                  backgroundColor: showFavorites 
                                    ? theme.colorScheme.primary.withValues(alpha: 0.12) 
                                    : (isDark ? Colors.white.withValues(alpha: 0.04) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  minimumSize: const Size(50, 50),
                                ),
                              icon: Icon(
                                showFavorites ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: showFavorites ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Categorías deslizantes (IUMP)
                      if (!showFavorites && activeCollection == 'iump')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              physics: const BouncingScrollPhysics(),
                              children: [
                                _buildQuickFilterChip(ref, 'Todos', activeCategory),
                                _buildQuickFilterChip(ref, 'Predicación', activeCategory),
                                _buildQuickFilterChip(ref, 'Adoración', activeCategory),
                                _buildQuickFilterChip(ref, 'Consagración', activeCategory),
                                _buildQuickFilterChip(ref, 'Santa Cena', activeCategory),
                                _buildQuickFilterChip(ref, 'Coritos', activeCategory),
                                _buildQuickFilterChip(ref, 'Fúnebre', activeCategory),
                                _buildQuickFilterChip(ref, 'Navidad', activeCategory),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Contenido de la lista expandido, asegurando que no se superponga
                Expanded(
                  child: filteredHymnsAsync.when(
                    data: (hymns) {
                      if (hymns.isEmpty) {
                        final query = ref.watch(searchQueryProvider);
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black12),
                                const SizedBox(height: 16),
                                Text(
                                  'No se encontraron himnos locales', 
                                  style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)
                                ),
                                if (query.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    icon: const Icon(Icons.cloud_sync_rounded),
                                    label: Text(
                                      'Buscar en Internet',
                                      style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _showOnlineSearchDialog(context, ref, query),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ).animate().fadeIn();
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 80.0),
                        itemCount: hymns.length,
                        itemBuilder: (context, index) {
                          final hymn = hymns[index];
                          final key = '${hymn.collection}-${hymn.id}';
                          final isSelected = _selectedKeys.contains(key);
                          final isFavorite = favorites.contains(key);
                          final duplicateKeysAsync = ref.watch(duplicateHymnsKeysProvider);
                          final isDuplicate = adminMode && (duplicateKeysAsync.value?.contains(key) ?? false);
                          
                          final Color defaultCardColor = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white;
                          final Color cardColor = isSelected
                            ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04)
                            : (isDuplicate
                                ? Colors.amber.withValues(alpha: isDark ? 0.06 : 0.03)
                                : defaultCardColor);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                  ? theme.colorScheme.primary
                                  : (isDuplicate
                                      ? Colors.amber.withValues(alpha: isDark ? 0.4 : 0.25)
                                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02))),
                                width: isSelected ? 1.5 : (isDuplicate ? 1.5 : 1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  if (_isMultiSelectMode) {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedKeys.remove(key);
                                        if (_selectedKeys.isEmpty) {
                                          _isMultiSelectMode = false;
                                        }
                                      } else {
                                        _selectedKeys.add(key);
                                      }
                                    });
                                  } else {
                                    context.push('/hymn/$key');
                                  }
                                },
                                onLongPress: adminMode ? () {
                                  setState(() {
                                    _isMultiSelectMode = true;
                                    _selectedKeys.add(key);
                                  });
                                } : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Row(
                                    children: [
                                      if (_isMultiSelectMode) ...[
                                        Checkbox(
                                          value: isSelected,
                                          activeColor: theme.colorScheme.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          onChanged: (val) {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedKeys.remove(key);
                                                if (_selectedKeys.isEmpty) {
                                                  _isMultiSelectMode = false;
                                                }
                                              } else {
                                                _selectedKeys.add(key);
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (hymn.collection == 'iump')
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.4 : 0.8),
                                                theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.1 : 0.4),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.1 : 0.15),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            hymn.id.toString(),
                                            style: GoogleFonts.outfit(
                                              color: theme.colorScheme.onPrimaryContainer,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            hymn.collection == 'especiales' ? Icons.music_note_rounded : Icons.library_music_rounded, 
                                            color: hymn.collection == 'especiales' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981), 
                                            size: 24
                                          ),
                                        ),
                                      const SizedBox(width: 14),
                                      // Detalles
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              hymn.title,
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                if (isDuplicate) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.08),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: Colors.amber.withValues(alpha: isDark ? 0.3 : 0.2),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 12),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'DUPLICADO',
                                                          style: GoogleFonts.nunito(
                                                            fontSize: 10,
                                                            color: isDark ? Colors.amber[200] : Colors.amber[900],
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (showFavorites || activeCollection == 'all') ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      hymn.collection == 'iump' ? 'Himnario IUMP' : (hymn.collection == 'especiales' ? 'Especial' : 'Coro'),
                                                      style: GoogleFonts.nunito(
                                                        fontSize: 11,
                                                        color: theme.colorScheme.primary,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (hymn.tone.isNotEmpty)
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.music_note_rounded, 
                                                        size: 13, 
                                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        Hymn.formatToneDisplay(hymn.tone, _notation),
                                                        style: GoogleFonts.nunito(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Acciones rápidas (Favoritos y Navegación)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                              color: isFavorite ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              ref.read(favoritesProvider.notifier).toggleFavorite(key);
                                            },
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: () {
        final adminMode = ref.watch(adminModeProvider);
        if (!adminMode) return null;
        // Si el contenedor activo no es de los tres principales ('iump', 'especiales', 'coros'),
        // por defecto creamos el himno en 'iump'.
        final targetCollection = (activeCollection == 'iump' || activeCollection == 'especiales' || activeCollection == 'coros')
            ? activeCollection
            : 'iump';
        return FloatingActionButton(
          tooltip: 'Agregar Himno',
          onPressed: () => _showCreateHymnDialog(context, ref, targetCollection),
          child: const Icon(Icons.add),
        );
      }(),
    );
  }

  Widget _buildQuickFilterChip(WidgetRef ref, String name, String activeCategory) {
    final isSelected = activeCategory == name;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(name),
        labelStyle: GoogleFonts.nunito(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 13,
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            ref.read(activeCategoryProvider.notifier).setCategory(name);
          } else {
            ref.read(activeCategoryProvider.notifier).setCategory('Todos');
          }
        },
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context, WidgetRef ref) {
    final activeCategory = ref.read(activeCategoryProvider);
    final categories = [
      {'name': 'Todos', 'icon': Icons.grid_view_rounded, 'color': Colors.indigo},
      {'name': 'Predicación', 'icon': Icons.auto_stories_rounded, 'color': Colors.blue},
      {'name': 'Fúnebre', 'icon': Icons.brightness_4_rounded, 'color': Colors.grey},
      {'name': 'Santa Cena', 'icon': Icons.local_cafe_rounded, 'color': Colors.red},
      {'name': 'Consagración', 'icon': Icons.volunteer_activism_rounded, 'color': Colors.teal},
      {'name': 'Adoración', 'icon': Icons.favorite_rounded, 'color': Colors.pink},
      {'name': 'Navidad', 'icon': Icons.star_rounded, 'color': Colors.amber},
      {'name': 'Coritos', 'icon': Icons.music_note_rounded, 'color': Colors.orange},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Filtrar por Categoría',
                style: GoogleFonts.outfit(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Selecciona una categoría de himnos de IUMP',
                style: GoogleFonts.nunito(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final catName = cat['name'] as String;
                    final catIcon = cat['icon'] as IconData;
                    final catColor = cat['color'] as Color;
                    final isSelected = activeCategory == catName;

                    return GestureDetector(
                      onTap: () {
                        ref.read(activeCategoryProvider.notifier).setCategory(catName);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? catColor.withValues(alpha: 0.12) 
                            : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected 
                              ? catColor.withValues(alpha: 0.3) 
                              : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              catIcon, 
                              color: isSelected ? catColor : (isDark ? Colors.white54 : Colors.black45),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                catName,
                                style: GoogleFonts.nunito(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected 
                                    ? (isDark ? Colors.white : catColor) 
                                    : theme.colorScheme.onSurface,
                                  fontSize: 13.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateHymnDialog(BuildContext context, WidgetRef ref, String collection) {
    final hymns = ref.read(hymnsProvider(collection)).value ?? [];
    
    int nextId = 1;
    if (hymns.isNotEmpty) {
      nextId = hymns.map((h) => h.id).reduce((a, b) => a > b ? a : b) + 1;
    }
    
    final idController = TextEditingController(text: nextId.toString());
    final titleController = TextEditingController();
    final toneController = TextEditingController();
    final lyricsController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  collection == 'iump' 
                    ? 'Nuevo Himno IUMP' 
                    : (collection == 'especiales' ? 'Nueva Alabanza Especial' : 'Nuevo Coro'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Escanear Letra con IA',
                icon: const Icon(Icons.document_scanner_rounded, color: Colors.blue),
                onPressed: () => _handleImageOcr(
                  context,
                  titleController,
                  toneController,
                  lyricsController,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (collection == 'iump')
                    TextFormField(
                      controller: idController,
                      decoration: const InputDecoration(labelText: 'Número del Himno'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerido';
                        if (int.tryParse(value) == null) return 'Debe ser un número';
                        final parsed = int.parse(value);
                        if (hymns.any((h) => h.id == parsed)) return 'Este número de himno ya existe';
                        return null;
                      },
                    ),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: toneController,
                    decoration: const InputDecoration(labelText: 'Tono (ej: SOL MAYOR)'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lyricsController,
                    decoration: const InputDecoration(
                      labelText: 'Letra',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 8,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.nunito()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final id = collection == 'iump' 
                    ? int.parse(idController.text) 
                    : nextId;
                  
                  await ref.read(hymnsProvider(collection).notifier).saveHymn(
                    id: id,
                    title: titleController.text.trim(),
                    tone: toneController.text.trim().isNotEmpty 
                      ? (toneController.text.toUpperCase().contains('TONO') 
                          ? toneController.text.trim().toUpperCase() 
                          : 'TONO: ${toneController.text.trim().toUpperCase()}')
                      : '',
                    lyrics: lyricsController.text.trim(),
                    isNew: true,
                  );
                  
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Himno creado con éxito', style: GoogleFonts.nunito()),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              child: Text('Crear', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleImageOcr(
    BuildContext context,
    TextEditingController titleCtrl,
    TextEditingController toneCtrl,
    TextEditingController lyricsCtrl,
  ) async {
    // 1. Obtener la API key de Gemini
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('gemini_api_key') ?? '';
    if (apiKey.isEmpty) {
      if (!context.mounted) return;
      final enteredKey = await _showGeminiKeyInputDialog(context);
      if (enteredKey == null || enteredKey.trim().isEmpty) return;
      apiKey = enteredKey.trim();
      await prefs.setString('gemini_api_key', apiKey);
    }

    // 2. Mostrar selector de cámara o galería
    if (!context.mounted) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Tomar Foto con Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    // 3. Seleccionar la imagen
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    // 4. Mostrar cargando con animación
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Analizando texto con Gemini...',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );

    // 5. Convertir imagen a base64
    try {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 6. Preparar llamada a Gemini
      final requestBody = jsonEncode({
        'contents': [{
          'parts': [
            {
              'text': 'Analiza esta imagen y extrae el texto del canto, himno o alabanza cristiana. '
                      'Identifica el título oficial del canto (si no está, infiérelo de la letra), '
                      'los acordes iniciales / tono (ej: RE / 2 TIEMPOS, SOLm / 3 TIEMPOS) si vienen escritos en alguna parte (si no vienen, deja el tono vacío), '
                      'y la letra completa del canto organizada de forma prolija en estrofas y coros claros, '
                      'eliminando cualquier acorde escrito entre medio de la letra (queremos solo el texto limpio de la letra). \n'
                      'Retorna el resultado estrictamente en este formato JSON, sin bloques de código markdown, sin explicaciones ni textos decorativos, solo el JSON:\n'
                      '{\n'
                      '  "title": "Título del canto",\n'
                      '  "tone": "Acorde / N tiempos (dejar vacío si no hay indicación)",\n'
                      '  "lyrics": "Letra completa limpia"\n'
                      '}'
            },
            {
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': base64Image
              }
            }
          ]
        }]
      });

      // Intentar llamar a los modelos en v1 o v1beta
      http.Response? response;
      final modelsToTry = [
        'gemini-2.0-flash',
        'gemini-1.5-flash',
      ];

      for (final model in modelsToTry) {
        try {
          final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
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

        if (response == null) {
          try {
            final url = Uri.parse('https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$apiKey');
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

      // Cerrar diálogo de cargando
      if (context.mounted) {
        Navigator.pop(context); // Cierra cargando
      }

      if (response != null && response.statusCode == 200) {
        final respData = jsonDecode(response.body);
        String rawText = respData['candidates'][0]['content']['parts'][0]['text'] as String;
        
        rawText = rawText.trim();
        if (rawText.startsWith('```json')) {
          rawText = rawText.substring(7);
        } else if (rawText.startsWith('```')) {
          rawText = rawText.substring(3);
        }
        if (rawText.endsWith('```')) {
          rawText = rawText.substring(0, rawText.length - 3);
        }
        rawText = rawText.trim();

        final parsed = jsonDecode(rawText);
        if (parsed is Map) {
          final titleVal = parsed['title']?.toString() ?? '';
          final toneVal = parsed['tone']?.toString() ?? '';
          final lyricsVal = parsed['lyrics']?.toString() ?? '';

          if (titleVal.isNotEmpty) titleCtrl.text = titleVal.toUpperCase();
          if (toneVal.isNotEmpty) toneCtrl.text = toneVal.toUpperCase();
          if (lyricsVal.isNotEmpty) lyricsCtrl.text = lyricsVal;

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Texto y estructura cargados con éxito!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        throw Exception(response?.body ?? 'Error al llamar a Gemini');
      }

    } catch (e) {
      if (context.mounted) {
        // Asegurarnos de que cerramos el diálogo cargando si todavía está abierto
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error en el escaneo'),
            content: Text('No pudimos procesar la imagen de manera exitosa: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<String?> _showGeminiKeyInputDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Ingresar API Key de Gemini',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para escanear letras de cantos necesitas una API Key de Gemini. Es totalmente gratuita y la puedes obtener en la web de Google AI Studio.',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'API Key de Gemini',
                  hintText: 'AIzaSy...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Guardar y Escanear'),
            ),
          ],
        );
      },
    );
  }

  void _showOnlineSearchDialog(BuildContext context, WidgetRef ref, String initialQuery) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OnlineSearchDialog(initialQuery: initialQuery),
    );
  }
}

class OnlineSearchDialog extends ConsumerStatefulWidget {
  final String initialQuery;
  const OnlineSearchDialog({super.key, required this.initialQuery});

  @override
  ConsumerState<OnlineSearchDialog> createState() => _OnlineSearchDialogState();
}

class _OnlineSearchDialogState extends ConsumerState<OnlineSearchDialog> {
  late String query;
  String geminiKey = '';
  bool isLoadingKey = true;
  bool isSearching = false;
  String errorMessage = '';
  String rawErrorDetails = '';
  String foundTitle = '';
  String foundLyrics = '';
  String selectedCollection = 'especiales'; // 'iump', 'especiales' o 'coros'
  bool hasSearched = false;

  final titleController = TextEditingController();
  final toneController = TextEditingController();
  final lyricsController = TextEditingController();
  final keyController = TextEditingController();
  final idController = TextEditingController();

  @override
  void initState() {
    super.initState();
    query = widget.initialQuery;
    _loadApiKey();
  }

  @override
  void dispose() {
    titleController.dispose();
    toneController.dispose();
    lyricsController.dispose();
    keyController.dispose();
    idController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        geminiKey = prefs.getString('gemini_api_key') ?? '';
        keyController.text = geminiKey;
        isLoadingKey = false;
      });
      if (geminiKey.isNotEmpty) {
        _performSearch();
      }
    }
  }

  Future<void> _performSearch() async {
    if (geminiKey.trim().isEmpty) {
      setState(() {
        errorMessage = 'Por favor ingresa una API Key de Gemini válida.';
      });
      return;
    }

    setState(() {
      isSearching = true;
      errorMessage = '';
      hasSearched = false;
    });

    List<String> errors = [];

    try {
      http.Response? response;
      final requestBody = jsonEncode({
        'contents': [{
          'parts': [{
            'text': 'Encuentra la letra oficial de la alabanza, himno o coro de iglesia cristiano titulado: "$query". \n'
                    'REGLA DE FILTRADO TEMÁTICO: Si la canción solicitada es de carácter claramente comercial, popular o secular (es decir, amor romántico de pareja, reggaetón comercial, pop secular, rock secular, etc. sin ninguna relación con la fe, Dios, Jesucristo o la iglesia), debes retornar el JSON con los campos vacíos: {"title": "", "lyrics": ""}. \n'
                    'Si es un canto cristiano de adoración, alabanza, coro o himnario, devuelve el resultado ESTRICTAMENTE en este formato JSON, sin bloques de código markdown, sin explicaciones ni textos decorativos, solo el JSON:\n'
                    '{\n'
                    '  "title": "Título oficial de la alabanza",\n'
                    '  "lyrics": "Letra completa de la alabanza o coro, organizada con estrofas y coros claros."\n'
                    '}'
          }]
        }]
      });
      final modelsToTry = [
        'gemini-2.0-flash',
        'gemini-1.5-flash',
      ];

      for (final model in modelsToTry) {
        if (response != null) break;
        // Intentar v1beta
        try {
          final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$geminiKey');
          final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: requestBody).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            response = res;
            break;
          } else {
            errors.add('v1beta/$model (Cod: ${res.statusCode}): ${res.body}');
          }
        } catch (e) {
          errors.add('v1beta/$model (Exc): $e');
        }

        // Intentar v1
        if (response == null) {
          try {
            final url = Uri.parse('https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$geminiKey');
            final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: requestBody).timeout(const Duration(seconds: 10));
            if (res.statusCode == 200) {
              response = res;
              break;
            } else {
              errors.add('v1/$model (Cod: ${res.statusCode}): ${res.body}');
            }
          } catch (e) {
            errors.add('v1/$model (Exc): $e');
          }
        }
      }

      if (response != null && response.statusCode == 200) {
        final respData = jsonDecode(response.body);
        String rawText = respData['candidates'][0]['content']['parts'][0]['text'] as String;
        
        rawText = rawText.trim();
        if (rawText.startsWith('```json')) {
          rawText = rawText.substring(7);
        } else if (rawText.startsWith('```')) {
          rawText = rawText.substring(3);
        }
        if (rawText.endsWith('```')) {
          rawText = rawText.substring(0, rawText.length - 3);
        }
        rawText = rawText.trim();

        final parsed = jsonDecode(rawText);
        
        String titleVal = '';
        String lyricsVal = '';
        if (parsed is Map) {
          parsed.forEach((k, v) {
            final keyLower = k.toString().toLowerCase();
            if (keyLower == 'title' || keyLower == 'titulo' || keyLower == 'título') {
              titleVal = v?.toString() ?? '';
            } else if (keyLower == 'lyrics' || keyLower == 'letra') {
              lyricsVal = v?.toString() ?? '';
            }
          });
        }
        foundTitle = titleVal.trim();
        foundLyrics = lyricsVal.trim();

        if (mounted) {
          if (foundTitle.isEmpty || foundLyrics.isEmpty) {
            setState(() {
              errorMessage = 'No pudimos encontrar la letra de "$query" automáticamente en internet.';
              isSearching = false;
              hasSearched = true;
            });
          } else {
            setState(() {
              titleController.text = foundTitle;
              lyricsController.text = foundLyrics;
              isSearching = false;
              hasSearched = true;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = parseFriendlyGeminiError(errors);
            rawErrorDetails = errors.join('\n');
            isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'No se pudo conectar con la IA de Google.\n\nRevisa tu conexión a internet o intenta de nuevo más tarde.';
          rawErrorDetails = e.toString();
          isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cargar la API Key de SharedPreferences
    if (isLoadingKey) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando configuración...'),
          ],
        ),
      );
    }

    // Si está buscando en internet
    if (isSearching) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Buscando letra oficial de:',
              style: GoogleFonts.nunito(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '"$query"',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    // Vista 1: Ingreso de API Key (si no hay guardada)
    if (geminiKey.trim().isEmpty && !hasSearched) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Buscar en Internet',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Para buscar letras de manera inteligente en internet, la app utiliza la Inteligencia Artificial (Gemini API).',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                decoration: InputDecoration(
                  labelText: 'API Key de Gemini',
                  labelStyle: GoogleFonts.nunito(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  hintText: 'AIzaSy...',
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final uri = Uri.parse('https://aistudio.google.com/');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(
                  'Obtener API Key gratuita de Google AI Studio',
                  style: GoogleFonts.nunito(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: GoogleFonts.nunito(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (rawErrorDetails.isNotEmpty)
                  ExpansionTile(
                    title: Text('Ver detalles técnicos para soporte', style: GoogleFonts.nunito(color: Colors.grey, fontSize: 12)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(rawErrorDetails, style: const TextStyle(fontFamily: 'monospace', color: Colors.redAccent, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.nunito()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final key = keyController.text.trim();
              if (key.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('gemini_api_key', key);
                setState(() {
                  geminiKey = key;
                  errorMessage = '';
                });
                _performSearch();
              } else {
                setState(() {
                  errorMessage = 'Ingresa una llave válida.';
                });
              }
            },
            child: Text('Guardar y Buscar', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    // Vista 2: Error o sin resultados
    if (errorMessage.isNotEmpty || (hasSearched && foundTitle.isEmpty)) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Búsqueda fallida',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              errorMessage.isNotEmpty ? errorMessage : 'No se pudo encontrar la letra de "$query" de forma automática.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'Puedes intentar cambiar tu consulta o ingresar los datos manualmente.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              SharedPreferences.getInstance().then((prefs) {
                prefs.remove('gemini_api_key');
                setState(() {
                  geminiKey = '';
                  errorMessage = '';
                  hasSearched = false;
                });
              });
            },
            child: Text('Borrar Key', style: GoogleFonts.nunito(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.nunito()),
          ),
        ],
      );
    }

    // Vista 3: Resultados encontrados - Previsualización y Edición
    final isAdmin = ref.watch(adminModeProvider);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Letra encontrada en Internet',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revisa y edita los datos antes de guardarlos en el himnario.',
                style: GoogleFonts.nunito(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: toneController,
                decoration: const InputDecoration(labelText: 'Tono (opcional, ej: SOL MAYOR)'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              Text(
                'Vista Previa de la Letra Encontrada:',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    lyricsController.text.trim().isNotEmpty 
                      ? lyricsController.text 
                      : '(Letra vacía)',
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: lyricsController,
                onChanged: (val) {
                  setState(() {}); // Re-renderiza para actualizar la vista previa en tiempo real
                },
                decoration: const InputDecoration(
                  labelText: 'Editar Letra (Si es necesario)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 6,
              ),
              if (selectedCollection == 'iump') ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: idController,
                  decoration: const InputDecoration(
                    labelText: 'Número del Himno IUMP',
                    hintText: 'Ej: 492',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 16),
              // Selector de colección
              Text(
                '¿Dónde deseas agregar esta alabanza?',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Himnario IUMP'),
                    selected: selectedCollection == 'iump',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedCollection = 'iump';
                          if (idController.text.isEmpty) {
                            final targetHymns = ref.read(hymnsProvider('iump')).value ?? [];
                            int nextId = 1;
                            if (targetHymns.isNotEmpty) {
                              nextId = targetHymns.map((h) => h.id).reduce((a, b) => a > b ? a : b) + 1;
                            }
                            idController.text = nextId.toString();
                          }
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Alabanzas Especiales'),
                    selected: selectedCollection == 'especiales',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedCollection = 'especiales';
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Coros de Avivamiento'),
                    selected: selectedCollection == 'coros',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedCollection = 'coros';
                        });
                      }
                    },
                  ),
                ],
              ),
              if (!isAdmin) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Debes activar el Modo Administrador para guardar himnos.',
                          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            SharedPreferences.getInstance().then((prefs) {
              prefs.remove('gemini_api_key');
              setState(() {
                geminiKey = '';
                hasSearched = false;
              });
            });
          },
          child: Text('Cambiar Key', style: GoogleFonts.nunito(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: GoogleFonts.nunito()),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isAdmin ? () async {
            final targetCollection = selectedCollection;
            final targetHymns = ref.read(hymnsProvider(targetCollection)).value ?? [];
            
            int idToSave;
            if (targetCollection == 'iump') {
              idToSave = int.tryParse(idController.text) ?? 1;
              if (targetHymns.any((h) => h.id == idToSave)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('El número de himno $idToSave ya existe en el Himnario IUMP', style: GoogleFonts.nunito()),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
            } else {
              int nextId = 1;
              if (targetHymns.isNotEmpty) {
                nextId = targetHymns.map((h) => h.id).reduce((a, b) => a > b ? a : b) + 1;
              }
              idToSave = nextId;
            }

            await ref.read(hymnsProvider(targetCollection).notifier).saveHymn(
              id: idToSave,
              title: titleController.text.trim(),
              tone: toneController.text.trim().isNotEmpty 
                ? (toneController.text.toUpperCase().contains('TONO') 
                    ? toneController.text.trim() 
                    : 'TONO: ${toneController.text.trim().toUpperCase()}')
                : '',
              lyrics: lyricsController.text.trim(),
              isNew: true,
            );

            if (!context.mounted) return;
            Navigator.pop(context);

            String friendlyCollectionName = targetCollection == 'iump' 
              ? 'el Himnario IUMP' 
              : (targetCollection == 'especiales' ? 'Alabanzas Especiales' : 'Coros');

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Alabanza agregada a $friendlyCollectionName con éxito', style: GoogleFonts.nunito()),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          } : null,
          child: Text('Agregar al Himnario', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class BiblicalAssistantDialog extends ConsumerStatefulWidget {
  const BiblicalAssistantDialog({super.key});

  @override
  ConsumerState<BiblicalAssistantDialog> createState() => _BiblicalAssistantDialogState();
}

class _BiblicalAssistantDialogState extends ConsumerState<BiblicalAssistantDialog> {
  final _inputController = TextEditingController();
  final _keyController = TextEditingController();
  
  String geminiKey = '';
  bool isLoadingKey = true;
  bool isSearching = false;
  String errorMessage = '';
  String rawErrorDetails = '';
  List<Map<String, dynamic>> recommendations = [];
  bool hasSearched = false;
  bool showKeySetup = false;
  final Set<String> _selectedCollections = {'iump', 'especiales', 'coros'};

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        geminiKey = prefs.getString('gemini_api_key') ?? '';
        _keyController.text = geminiKey;
        isLoadingKey = false;
      });
    }
  }

  Future<void> _performAssistantSearch() async {
    final userInput = _inputController.text.trim();
    if (userInput.isEmpty) return;

    if (geminiKey.trim().isEmpty) {
      setState(() {
        errorMessage = 'Por favor ingresa una API Key de Gemini válida.';
      });
      return;
    }

    setState(() {
      isSearching = true;
      errorMessage = '';
      recommendations.clear();
      hasSearched = false;
    });

    final allHymnsGlobal = ref.read(allHymnsGlobalProvider).value ?? [];
    final allHymns = allHymnsGlobal
        .where((h) => _selectedCollections.contains(h.collection))
        .toList();

    try {
      if (allHymns.isEmpty) {
        setState(() {
          errorMessage = 'No hay cantos en las colecciones seleccionadas.';
          isSearching = false;
        });
        return;
      }

      // Pre-filtrar cantos basados en palabras clave de la consulta del usuario
      final queryWords = userInput.toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(' ')
          .where((w) {
            if (w.isEmpty) return false;
            // Permitir números de cualquier longitud (para pasajes como Juan 3, Salmo 23)
            final isDigit = RegExp(r'^\d+$').hasMatch(w);
            if (isDigit) return true;
            
            // Para palabras comunes, exigir más de 2 letras y excluir conectores
            return w.length > 2 && 
                   w != 'del' && 
                   w != 'por' && 
                   w != 'con' && 
                   w != 'para' && 
                   w != 'sobre' && 
                   w != 'una' && 
                   w != 'los' && 
                   w != 'las' && 
                   w != 'que';
          })
          .toList();

      List<Hymn> filteredList = [];
      if (queryWords.isEmpty) {
        filteredList = allHymns;
      } else {
        final scoredHymns = allHymns.map((h) {
          int score = 0;
          final titleLower = h.title.toLowerCase();
          final lyricsLower = h.lyrics.toLowerCase();
          for (final word in queryWords) {
            if (titleLower.contains(word)) score += 15; // mayor peso a coincidencias en título
            final matches = word.allMatches(lyricsLower).length;
            score += matches.clamp(0, 4); // limitar para evitar que la repetición artificial ahogue himnos tradicionales
          }
          return MapEntry(h, score);
        }).where((entry) => entry.value > 0).toList();

        scoredHymns.sort((a, b) => b.value.compareTo(a.value));

        if (scoredHymns.isNotEmpty) {
          filteredList = scoredHymns.map((e) => e.key).take(90).toList();
        } else {
          filteredList = allHymns;
        }
      }

      final compactCatalog = filteredList.map((h) => {
        'id': h.id,
        'title': h.title,
        'collection': h.collection,
      }).toList();

      final requestBody = jsonEncode({
        'contents': [{
          'parts': [{
            'text': 'Analiza la siguiente lectura bíblica o tema de predicación: "$userInput". \n'
                    'De la siguiente lista de cantos en formato JSON que tenemos en nuestra aplicación:\n'
                    '${jsonEncode(compactCatalog)}\n\n'
                    'Recomienda un máximo de 5 cantos de esa lista que guarden estrecha relación temática, teológica o emocional con el tema/lectura bíblica. No sugieras ningún canto que no esté explícitamente en la lista proporcionada. \n'
                    'Para cada recomendación, incluye una justificación teológica o contextual de una frase explicando por qué se relaciona con la palabra.\n'
                    'Retorna el resultado en este formato JSON:\n'
                    '{\n'
                    '  "recommendations": [\n'
                    '    {\n'
                    '      "id": 123,\n'
                    '      "collection": "nombre_de_coleccion",\n'
                    '      "title": "Título del canto",\n'
                    '      "reason": "Explicación de la relación."\n'
                    '    }\n'
                    '  ]\n'
                    '}'
          }]
        }],
        'generation_config': {
          'response_mime_type': 'application/json'
        }
      });

      final attempts = [
        {'model': 'gemini-1.5-flash', 'api': 'v1beta'},
        {'model': 'gemini-2.0-flash', 'api': 'v1beta'},
        {'model': 'gemini-1.5-flash', 'api': 'v1'},
      ];

      http.Response? response;
      List<String> errors = [];

      for (final attempt in attempts) {
        final model = attempt['model']!;
        final api = attempt['api']!;
        try {
          final url = Uri.parse('https://generativelanguage.googleapis.com/$api/models/$model:generateContent?key=$geminiKey');
          final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: requestBody).timeout(const Duration(seconds: 12));
          if (res.statusCode == 200) {
            response = res;
            break;
          } else {
            String detailedError = '${res.statusCode}';
            try {
              final parsedBody = jsonDecode(res.body);
              if (parsedBody['error'] != null && parsedBody['error']['message'] != null) {
                detailedError = '${res.statusCode}: ${parsedBody['error']['message']}';
              }
            } catch (_) {}
            errors.add('$model ($api): $detailedError');
          }
        } catch (e) {
          errors.add('$model ($api) Exc: $e');
        }
      }

      if (response != null && response.statusCode == 200) {
        final respData = jsonDecode(response.body);
        String rawText = respData['candidates'][0]['content']['parts'][0]['text'] as String;
        
        rawText = rawText.trim();
        if (rawText.startsWith('```json')) {
          rawText = rawText.substring(7);
        } else if (rawText.startsWith('```')) {
          rawText = rawText.substring(3);
        }
        if (rawText.endsWith('```')) {
          rawText = rawText.substring(0, rawText.length - 3);
        }
        rawText = rawText.trim();

        final parsed = jsonDecode(rawText);
        final recs = List<Map<String, dynamic>>.from(parsed['recommendations'] ?? []);

        setState(() {
          recommendations = recs;
          isSearching = false;
          hasSearched = true;
        });
      } else {
        // FALLBACK LOCAL: Si la API de Google falla o la clave no tiene acceso, buscar coincidencias locales
        _performLocalFallbackSearch(userInput, allHymns);
      }
    } catch (e) {
      _performLocalFallbackSearch(userInput, allHymns);
    }
  }

  void _performLocalFallbackSearch(String query, List<Hymn> allHymns) {
    final lowerQuery = query.toLowerCase();
    final words = lowerQuery.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();

    List<Map<String, dynamic>> localRecs = [];
    for (final h in allHymns) {
      final titleLower = h.title.toLowerCase();
      final lyricsLower = h.lyrics.toLowerCase();

      int score = 0;
      for (final word in words) {
        if (titleLower.contains(word)) score += 3;
        if (lyricsLower.contains(word)) score += 1;
      }

      if (score > 0) {
        localRecs.add({
          'id': h.id,
          'collection': h.collection,
          'title': h.title,
          'reason': 'Sugerencia local basada en coincidencias de texto con "$query".'
        });
      }

      if (localRecs.length >= 10) break;
    }

    setState(() {
      recommendations = localRecs;
      isSearching = false;
      hasSearched = true;
      if (localRecs.isEmpty) {
        errorMessage = 'No se encontraron cantos relacionados con el término buscado.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isLoadingKey) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (geminiKey.trim().isEmpty || showKeySetup) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Configurar API Key de Gemini', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Esta app requiere una API Key de Gemini para sugerir cantos automáticamente a partir de lecturas bíblicas y temas de predicación.',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyController,
                decoration: InputDecoration(
                  labelText: 'API Key de Gemini',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => launchUrl(Uri.parse('https://aistudio.google.com/'), mode: LaunchMode.externalApplication),
                child: Text(
                  'Obtén tu API Key gratis aquí',
                  style: GoogleFonts.nunito(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (showKeySetup) {
                setState(() {
                  showKeySetup = false;
                });
              } else {
                Navigator.pop(context);
              }
            },
            child: Text('Cancelar', style: GoogleFonts.nunito()),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = _keyController.text.trim();
              if (key.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('gemini_api_key', key);
                setState(() {
                  geminiKey = key;
                  showKeySetup = false;
                });
              }
            },
            child: Text('Guardar', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    if (isSearching) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Analizando catálogo de cantos...', style: GoogleFonts.nunito(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              '"${_inputController.text}"',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(Icons.auto_stories_rounded, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Encontrar Cantos por Palabra',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          IconButton(
            icon: Icon(Icons.vpn_key_rounded, color: theme.colorScheme.primary, size: 20),
            tooltip: 'Configurar API Key',
            onPressed: () {
              setState(() {
                showKeySetup = true;
              });
            },
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasSearched) ...[
                Text(
                  'Ingresa el pasaje leído o describe de qué trató la predicación para sugerirte los cantos ideales en el culto.',
                  style: GoogleFonts.nunito(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Buscar en colecciones:',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: Text('Himnario IUMP', style: GoogleFonts.nunito(fontSize: 12)),
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
                      label: Text('Especiales', style: GoogleFonts.nunito(fontSize: 12)),
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
                      label: Text('Coros', style: GoogleFonts.nunito(fontSize: 12)),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _inputController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ej: Salmo 23 (El Señor es mi pastor) / Sobre tener fe y confianza en Dios en medio del desierto',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  style: GoogleFonts.nunito(fontSize: 14),
                ),
              ] else ...[
                Text(
                  'Recomendaciones para:\n"${_inputController.text}"',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (recommendations.isEmpty)
                  Text('No se encontraron recomendaciones adecuadas.', style: GoogleFonts.nunito(fontSize: 14))
                else
                  ...recommendations.map((rec) {
                    final recId = rec['id'];
                    final recCollection = rec['collection'];
                    final recTitle = rec['title'] ?? 'Canto';
                    final recReason = rec['reason'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/hymn/$recCollection-$recId');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      recCollection == 'iump' ? 'Himno $recId' : (recCollection == 'especiales' ? 'Especial' : 'Coro'),
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      recTitle,
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary, size: 20),
                                ],
                              ),
                              if (recReason.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  recReason,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
              if (errorMessage.isNotEmpty) ...[
                Text(errorMessage, style: GoogleFonts.nunito(color: Colors.red, fontSize: 13)),
                const SizedBox(height: 8),
                if (rawErrorDetails.isNotEmpty)
                  ExpansionTile(
                    title: Text('Ver detalles técnicos para soporte', style: GoogleFonts.nunito(color: Colors.grey, fontSize: 12)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(rawErrorDetails, style: const TextStyle(fontFamily: 'monospace', color: Colors.redAccent, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (hasSearched)
          TextButton(
            onPressed: () {
              setState(() {
                hasSearched = false;
                errorMessage = '';
              });
            },
            child: Text('Buscar otro', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(hasSearched ? 'Cerrar' : 'Cancelar', style: GoogleFonts.nunito()),
        ),
        if (!hasSearched)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _performAssistantSearch,
            child: Text('Sugerir Cantos', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}

String parseFriendlyGeminiError(List<String> errors) {
  bool hasQuotaError = false;
  bool hasInvalidKeyError = false;
  bool hasRegionError = false;
  bool hasNetworkError = false;

  for (final err in errors) {
    final errLower = err.toLowerCase();
    if (errLower.contains('429') || errLower.contains('exhausted') || errLower.contains('quota') || errLower.contains('limit')) {
      hasQuotaError = true;
    }
    if (errLower.contains('api key not valid') || errLower.contains('key not found') || errLower.contains('invalid key') || errLower.contains('api_key_invalid') || errLower.contains('400') || errLower.contains('403')) {
      if (errLower.contains('location') || errLower.contains('supported') || errLower.contains('region') || errLower.contains('country')) {
        hasRegionError = true;
      } else {
        hasInvalidKeyError = true;
      }
    }
    if (errLower.contains('exc') || errLower.contains('socket') || errLower.contains('timeout') || errLower.contains('connect')) {
      hasNetworkError = true;
    }
  }

  if (hasQuotaError) {
    return 'Límite de la versión gratuita superado.\n\n'
        'Por favor, espera unos minutos antes de intentar de nuevo.\n\n'
        'Nota: Google restringe el uso gratuito por dirección IP. Si compartes la red móvil (celular) con otros usuarios o tu zona de cobertura está saturada, es posible que el límite se alcance de inmediato aunque cambies de API Key. Te sugerimos conectarte a una red Wi-Fi privada, usar una VPN, o activar la facturación en Google AI Studio (que elimina los límites de IP y sigue teniendo un consumo inicial gratuito enorme).';
  }
  if (hasInvalidKeyError) {
    return 'La clave API Key de Gemini no es válida o no tiene los permisos necesarios.\n\n'
        'Por favor, verifica que esté bien copiada desde Google AI Studio.';
  }
  if (hasRegionError) {
    return 'El servicio de IA no está disponible en tu ubicación geográfica.\n\n'
        'Google restringe el acceso a Gemini en ciertos países o redes. Intenta conectarte usando otra red o VPN.';
  }
  if (hasNetworkError) {
    return 'No se pudo conectar con el servidor de Google.\n\n'
        'Revisa tu conexión a internet (móvil o wifi) y vuelve a intentarlo.';
  }

  return 'No se pudo conectar con la IA de Google.\n\n'
      'Verifica tu API Key, tu conexión a internet y vuelve a intentarlo.';
}
