import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../hymns/domain/hymn.dart';
import '../../hymns/presentation/hymn_list_screen.dart';
import '../domain/setlist.dart';
import 'setlists_provider.dart';

class SetlistDetailScreen extends ConsumerStatefulWidget {
  const SetlistDetailScreen({super.key});

  @override
  ConsumerState<SetlistDetailScreen> createState() => _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setlist = ref.watch(activeSetlistProvider);
    final allHymnsAsync = ref.watch(allHymnsGlobalProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (setlist == null) {
      return const Scaffold(
        body: Center(child: Text('Repertorio no encontrado')),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Auroras decorativas de fondo
          Positioned(
            top: -100,
            right: -100,
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
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // AppBar
                SliverAppBar(
                  expandedHeight: 140.0,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      tooltip: 'Eliminar Repertorio',
                      onPressed: () => _confirmDeleteSetlist(context, ref, setlist),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          setlist.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          _formatDate(setlist.date),
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    centerTitle: true,
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () {
                      ref.read(activeSetlistProvider.notifier).setSetlist(null);
                      context.pop();
                    },
                  ),
                ),

                // Lista de cantos
                allHymnsAsync.when(
                  data: (hymns) {
                    final setlistHymns = _getHymnsInSetlist(setlist, hymns);

                    if (setlistHymns.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_off_rounded,
                                size: 50,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Aún no hay cantos en este repertorio',
                                style: GoogleFonts.outfit(
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black45,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.playlist_add_rounded),
                                label: const Text('Agregar Cantos'),
                                onPressed: () => _showAddHymnToSetlistDialog(context, ref, setlist, hymns),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final hymn = setlistHymns[index];
                            return _buildHymnItem(context, ref, setlist, hymn, index, isDark, theme)
                                .animate()
                                .fadeIn(delay: (index * 50).ms)
                                .slideY(begin: 0.05);
                          },
                          childCount: setlistHymns.length,
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, s) => SliverFillRemaining(
                    child: Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: allHymnsAsync.when(
        data: (hymns) {
          final setlistHymns = _getHymnsInSetlist(setlist, hymns);
          if (setlistHymns.isEmpty) return const SizedBox.shrink();

          return Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Agregar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _showAddHymnToSetlistDialog(context, ref, setlist, hymns),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: Text(
                      'Iniciar Modo Culto',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      final firstHymn = setlistHymns.first;
                      context.push('/hymn/${firstHymn.collection}-${firstHymn.id}');
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, e) => const SizedBox.shrink(),
      ),
    );
  }

  List<Hymn> _getHymnsInSetlist(Setlist setlist, List<Hymn> allHymns) {
    final List<Hymn> result = [];
    for (final hId in setlist.hymnIds) {
      final parts = hId.split('-');
      final col = parts[0];
      final id = int.tryParse(parts.sublist(1).join('-')) ?? 0;
      
      final matching = allHymns.firstWhere(
        (h) => h.collection == col && h.id == id,
        orElse: () => const Hymn(id: 0, title: '', tone: '', lyrics: '', collection: ''),
      );
      if (matching.id != 0) {
        result.add(matching);
      }
    }
    return result;
  }

  Widget _buildHymnItem(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
    Hymn hymn,
    int index,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          foregroundColor: theme.colorScheme.primary,
          radius: 18,
          child: Text(
            '${index + 1}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        title: Text(
          hymn.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          hymn.collection == 'iump' 
            ? 'Himnario IUMP #${hymn.id}' 
            : (hymn.collection == 'especiales' ? 'Alabanza Especial' : 'Coro de Avivamiento'),
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botones de reordenamiento
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
              onPressed: index > 0 
                ? () => _moveHymnInSetlist(ref, setlist, index, -1)
                : null,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              onPressed: index < setlist.hymnIds.length - 1 
                ? () => _moveHymnInSetlist(ref, setlist, index, 1)
                : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
              onPressed: () => _removeHymnFromSetlist(ref, setlist, index),
            ),
          ],
        ),
        onTap: () {
          context.push('/hymn/${hymn.collection}-${hymn.id}');
        },
      ),
    );
  }

  void _moveHymnInSetlist(WidgetRef ref, Setlist setlist, int index, int direction) {
    final newList = List<String>.from(setlist.hymnIds);
    final targetIndex = index + direction;
    final item = newList.removeAt(index);
    newList.insert(targetIndex, item);

    final updatedSetlist = Setlist(
      id: setlist.id,
      title: setlist.title,
      date: setlist.date,
      hymnIds: newList,
    );

    ref.read(setlistsProvider.notifier).updateSetlist(updatedSetlist);
    ref.read(activeSetlistProvider.notifier).setSetlist(updatedSetlist);
  }

  void _removeHymnFromSetlist(WidgetRef ref, Setlist setlist, int index) {
    final newList = List<String>.from(setlist.hymnIds);
    newList.removeAt(index);

    final updatedSetlist = Setlist(
      id: setlist.id,
      title: setlist.title,
      date: setlist.date,
      hymnIds: newList,
    );

    ref.read(setlistsProvider.notifier).updateSetlist(updatedSetlist);
    ref.read(activeSetlistProvider.notifier).setSetlist(updatedSetlist);
  }

  void _showAddHymnToSetlistDialog(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
    List<Hymn> allHymns,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filtrar himnos por query de búsqueda del diálogo
            final filteredList = allHymns.where((hymn) {
              if (setlist.hymnIds.contains('${hymn.collection}-${hymn.id}')) return false; // Evitar duplicados
              if (_searchQuery.isEmpty) return true;
              final cleanQuery = _searchQuery.toLowerCase();
              return hymn.title.toLowerCase().contains(cleanQuery) || 
                     hymn.id.toString().contains(cleanQuery);
            }).toList();

            // Ordenar por prioridad (Iump primero, luego especiales, luego coros)
            filteredList.sort((a, b) {
              final priorityA = a.collection == 'iump' ? 1 : (a.collection == 'especiales' ? 2 : 3);
              final priorityB = b.collection == 'iump' ? 1 : (b.collection == 'especiales' ? 2 : 3);
              if (priorityA != priorityB) return priorityA.compareTo(priorityB);
              return a.title.compareTo(b.title);
            });

            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                  height: MediaQuery.of(context).size.height * 0.75,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Añadir Canto al Repertorio',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por título o número...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setModalState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredList.length,
                          itemBuilder: (context, idx) {
                            final hymn = filteredList[idx];
                            return ListTile(
                              title: Text(hymn.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                hymn.collection == 'iump' 
                                  ? 'Himno #${hymn.id}' 
                                  : (hymn.collection == 'especiales' ? 'Alabanza Especial' : 'Coro'),
                                style: GoogleFonts.outfit(fontSize: 12),
                              ),
                              trailing: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary),
                              onTap: () {
                                final newList = List<String>.from(setlist.hymnIds);
                                newList.add('${hymn.collection}-${hymn.id}');
                                
                                final updated = Setlist(
                                  id: setlist.id,
                                  title: setlist.title,
                                  date: setlist.date,
                                  hymnIds: newList,
                                );

                                ref.read(setlistsProvider.notifier).updateSetlist(updated);
                                ref.read(activeSetlistProvider.notifier).setSetlist(updated);
                                context.pop();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSetlist(BuildContext context, WidgetRef ref, Setlist setlist) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Repertorio'),
          content: Text('¿Estás seguro que deseas eliminar el repertorio "${setlist.title}"? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                ref.read(setlistsProvider.notifier).deleteSetlist(setlist.id);
                context.pop(); // Cerrar diálogo
                context.pop(); // Volver a la lista de repertorios
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  /// Convierte una fecha almacenada a formato DD-MM-YYYY para mostrar.
  String _formatDate(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return raw;
    if (parts[0].length == 4) {
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }
    return raw;
  }
}
