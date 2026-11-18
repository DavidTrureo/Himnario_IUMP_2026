import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../hymns/domain/hymn.dart';
import '../../domain/recent_hymn.dart';
import '../recent_hymns_provider.dart';

/// Formatea la fecha relativa de manera concisa y en español
String _formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 60) {
    if (diff.inMinutes < 2) return 'Recién';
    return 'Hace ${diff.inMinutes}m';
  } else if (diff.inHours < 24 && now.day == dateTime.day) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return 'Hoy $hour:$min';
  } else if (diff.inDays == 1 || (diff.inHours < 48 && now.day - dateTime.day == 1)) {
    return 'Ayer';
  } else if (diff.inDays < 7) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return 'El ${days[dateTime.weekday - 1]}';
  } else {
    return '${dateTime.day}/${dateTime.month}';
  }
}

/// Sección horizontal elegante para la pantalla de inicio con los cantos entonados recientemente.
class RecentHymnsSection extends ConsumerWidget {
  const RecentHymnsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentHymnsWithHymnProvider);
    if (recents.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de la sección
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF38BDF8),
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Cantados recientemente',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${recents.length}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _confirmClearHistory(context, ref),
                child: Text(
                  'Limpiar',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Carrusel horizontal
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = recents[index];
              return RepaintBoundary(
                key: ValueKey('recent_${item.recent.key}'),
                child: _buildRecentCard(context, ref, item.recent, item.hymn, isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCard(
    BuildContext context,
    WidgetRef ref,
    RecentHymn recent,
    Hymn hymn,
    bool isDark,
  ) {
    Color badgeColor;
    String badgeText;
    if (hymn.collection == 'iump') {
      badgeColor = const Color(0xFF3B82F6); // Azul IUMP
      badgeText = 'Himno ${hymn.id}';
    } else if (hymn.collection == 'especiales') {
      badgeColor = const Color(0xFF8B5CF6); // Morado Especiales
      badgeText = 'Especial';
    } else {
      badgeColor = const Color(0xFF10B981); // Esmeralda Coros
      badgeText = 'Coro';
    }

    final displayTone = recent.tone != null && recent.tone!.isNotEmpty
        ? recent.tone!
        : hymn.toneNote;

    return Container(
      width: 195,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162032) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2A374D).withValues(alpha: 0.8) : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            context.push('/home/hymns/hymn/${recent.key}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fila superior: Colección + Tono
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (displayTone.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.30 : 0.20),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          displayTone,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Título del canto (máximo 2 líneas)
                Text(
                  hymn.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),

                // Fila inferior: Tiempo relativo
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatRelativeTime(recent.timestamp),
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        title: Text(
          'Limpiar historial',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Text(
          '¿Deseas vaciar la lista de cantos entonados recientemente?',
          style: GoogleFonts.nunito(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(color: const Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(recentHymnsProvider.notifier).clearHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    content: Text(
                      'Historial de cantos limpiado',
                      style: GoogleFonts.nunito(color: Colors.white),
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
            child: Text(
              'Limpiar',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
