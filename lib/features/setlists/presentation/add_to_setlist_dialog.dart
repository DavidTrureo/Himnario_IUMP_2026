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
    useRootNavigator: true, // Se monta sobre el navegador raíz para nunca quedar tapado por el menú flotante
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E293B), // Slate 800 acorde a la paleta dark
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final setlistsAsync = ref.watch(setlistsProvider);
      return SafeArea(
        top: false,
        child: setlistsAsync.when(
          data: (setlists) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                20 + MediaQuery.of(ctx).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.playlist_add_rounded,
                          color: Color(0xFF38BDF8),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Agregar a Repertorio',
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selecciona la lista de culto donde deseas incluir "${hymn.title}":',
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      color: const Color(0xFF94A3B8),
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
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
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
                                    ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isInSetlist
                                    ? Icons.check_circle_rounded
                                    : Icons.queue_music_rounded,
                                color: isInSetlist
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF94A3B8),
                                size: 22,
                              ),
                            ),
                            title: Text(
                              setlist.title,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              '${setlist.hymnIds.length} cantos • ${setlist.date}',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
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
                                      if (ctx.mounted) {
                                        Navigator.of(ctx, rootNavigator: true).pop();
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(0xFF1E293B),
                                            content: Text(
                                              'Removido de "${setlist.title}"',
                                              style: GoogleFonts.nunito(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              side: const BorderSide(color: Color(0xFF334155), width: 1),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text(
                                      'Quitar',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                      foregroundColor: const Color(0xFF38BDF8),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text(
                                      'Agregar',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
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
                                      if (ctx.mounted) {
                                        Navigator.of(ctx, rootNavigator: true).pop();
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(0xFF1E293B),
                                            content: Text(
                                              'Agregado a "${setlist.title}"',
                                              style: GoogleFonts.nunito(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              side: const BorderSide(color: Color(0xFF334155), width: 1),
                                            ),
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
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF334155)),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(ctx, rootNavigator: true).pop();
                      showCreateSetlistDialog(context, ref, key);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Color(0xFF38BDF8),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Crear Nuevo Repertorio',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: const Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                    ),
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
            child: Center(
              child: Text(
                'Error: $err',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
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
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      title: Text(
        'Nuevo Repertorio',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      content: TextField(
        controller: titleCtrl,
        style: GoogleFonts.nunito(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Nombre del Repertorio',
          labelStyle: GoogleFonts.nunito(color: const Color(0xFF94A3B8)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Cancelar',
            style: GoogleFonts.nunito(color: const Color(0xFF94A3B8)),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF38BDF8),
            foregroundColor: const Color(0xFF0F172A),
          ),
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
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    content: Text(
                      'Repertorio "$title" creado y canto agregado',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFF334155), width: 1),
                    ),
                  ),
                );
              }
            }
          },
          child: Text(
            'Crear y Agregar',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

