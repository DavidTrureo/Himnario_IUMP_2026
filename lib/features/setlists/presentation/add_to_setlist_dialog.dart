import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../hymns/domain/hymn.dart';
import '../domain/setlist.dart';
import 'setlists_provider.dart';

/// Diálogo modal interactivo para agregar o quitar un canto de una Lista de Culto (Repertorio).
void showAddToSetlistDialog(BuildContext context, WidgetRef ref, Hymn hymn) {
  final key = '${hymn.collection}-${hymn.id}';
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final setlistsAsync = ref.watch(setlistsProvider);
      return setlistsAsync.when(
        data: (setlists) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              24 + MediaQuery.of(ctx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.playlist_add_rounded,
                      color: Color(0xFF4F46E5),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Agregar a Repertorio',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona la lista de culto donde deseas incluir "${hymn.title}":',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                if (setlists.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                      child: Text(
                        'Aún no tienes listas de repertorios creadas.',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: setlists.length,
                      itemBuilder: (ctx2, i) {
                        final setlist = setlists[i];
                        final isInSetlist = setlist.hymnIds.contains(key);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isInSetlist
                                  ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isInSetlist
                                  ? Icons.check_circle_rounded
                                  : Icons.queue_music_rounded,
                              color: isInSetlist
                                  ? const Color(0xFF4F46E5)
                                  : Colors.grey[600],
                              size: 20,
                            ),
                          ),
                          title: Text(
                            setlist.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${setlist.hymnIds.length} cantos • ${setlist.date}',
                            style: GoogleFonts.nunito(fontSize: 12),
                          ),
                          trailing: isInSetlist
                              ? TextButton(
                                  onPressed: () async {
                                    final updatedIds =
                                        List<String>.from(setlist.hymnIds)
                                          ..remove(key);
                                    final updatedSetlist = setlist.copyWith(
                                      hymnIds: updatedIds,
                                    );
                                    await ref
                                        .read(setlistsProvider.notifier)
                                        .updateSetlist(updatedSetlist);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Removido de "${setlist.title}"',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Quitar',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Agregar'),
                                  onPressed: () async {
                                    final updatedIds =
                                        List<String>.from(setlist.hymnIds)
                                          ..add(key);
                                    final updatedSetlist = setlist.copyWith(
                                      hymnIds: updatedIds,
                                    );
                                    await ref
                                        .read(setlistsProvider.notifier)
                                        .updateSetlist(updatedSetlist);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Agregado a "${setlist.title}"',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Divider(color: Colors.grey.withValues(alpha: 0.2)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  title: Text(
                    'Crear Nuevo Repertorio',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showCreateSetlistDialog(context, ref, key);
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 150,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => SizedBox(
          height: 150,
          child: Center(child: Text('Error: $err')),
        ),
      );
    },
  );
}

/// Diálogo para crear un nuevo repertorio y asociar el canto inmediatamente
void showCreateSetlistDialog(
  BuildContext context,
  WidgetRef ref,
  String hymnKey,
) {
  final titleCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        'Nuevo Repertorio',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: titleCtrl,
        decoration: const InputDecoration(
          labelText: 'Nombre del Repertorio',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            final title = titleCtrl.text.trim();
            if (title.isNotEmpty) {
              final date = DateTime.now().toIso8601String().split('T')[0];
              await ref
                  .read(setlistsProvider.notifier)
                  .addSetlist(title, date, [hymnKey]);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Repertorio creado y canto agregado'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          child: const Text('Crear y Agregar'),
        ),
      ],
    ),
  );
}

