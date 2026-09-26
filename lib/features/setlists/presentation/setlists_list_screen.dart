import '../../../core/utils/formatters.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/setlist.dart';
import 'setlists_provider.dart';

class SetlistsListScreen extends ConsumerWidget {
  const SetlistsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fondo base gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                  ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                  : [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)],
              ),
            ),
          ),

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
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // AppBar Elegante
                SliverAppBar(
                  expandedHeight: 80.0,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  titleSpacing: 24,
                  centerTitle: false,
                  title: Text(
                    'Repertorios de Culto',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 26,
                    ),
                  ),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      tooltip: 'Escanear QR de Culto',
                      onPressed: () => context.push('/scan-qr'),
                    ),
                  ],
                ),

                // Lista de repertorios
                setlistsAsync.when(
                  data: (setlists) {
                    if (setlists.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        theme.colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                                        theme.colorScheme.primary.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.queue_music_rounded,
                                    size: 64,
                                    color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.8 : 0.6),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Aún no hay repertorios',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Organiza tus cantos para el próximo culto creando tu primer repertorio.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(
                                    'Crear Repertorio',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _showAddSetlistDialog(context, ref),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 200),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final setlist = setlists[index];
                            return _buildSetlistCard(context, ref, setlist, isDark, theme)
                                .animate()
                                .fadeIn(delay: (index * 50).ms)
                                .slideY(begin: 0.1);
                          },
                          childCount: setlists.length,
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
      floatingActionButton: setlistsAsync.maybeWhen(
        data: (setlists) => setlists.isEmpty ? null : Padding(
          padding: const EdgeInsets.only(bottom: 140.0),
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.add_rounded),
            label: Text('Nuevo Repertorio', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () => _showAddSetlistDialog(context, ref),
          ),
        ).animate().scale(delay: 200.ms),
        orElse: () => null,
      ),
    );
  }

  Widget _buildSetlistCard(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.03),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                ? Colors.white.withValues(alpha: 0.04) 
                : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark 
                  ? Colors.white.withValues(alpha: 0.06) 
                  : Colors.white.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              title: Text(
                setlist.title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(setlist.date),
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.music_note_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${setlist.hymnIds.length} cantos',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                ref.read(activeSetlistProvider.notifier).setSetlist(setlist);
                context.push('/setlists/setlist-detail');
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSetlistDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final dateController = TextEditingController(text: dateStr);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Nuevo Repertorio',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Título del Culto/Repertorio',
                    hintText: 'ej: Culto Adoración Domingo',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    hintText: 'YYYY-MM-DD',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  ref.read(setlistsProvider.notifier).addSetlist(
                    titleController.text.trim().toUpperCase(),
                    dateController.text.trim(),
                    [],
                  );
                  context.pop();
                }
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  /// Convierte una fecha almacenada a formato DD-MM-YYYY para mostrar.
  /// Soporta tanto YYYY-MM-DD (legado) como DD-MM-YYYY (nuevo).
  String _formatDate(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return raw;
    // Si el primer segmento tiene 4 dígitos es formato YYYY-MM-DD (legado)
    if (parts[0].length == 4) {
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }
    return raw; // ya está en DD-MM-YYYY
  }
}
