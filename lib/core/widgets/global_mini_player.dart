import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/global_audio_service.dart';

class GlobalMiniPlayer extends ConsumerWidget {
  const GlobalMiniPlayer({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(globalAudioProvider);

    // Si no hay audio activo o no debe ser visible
    if (!audioState.isVisible || audioState.hymn == null) {
      return const SizedBox.shrink();
    }

    // Si ya estamos dentro del visor del canto, ocultar el mini-reproductor
    // para no duplicar controles con la vista de detalle
    final currentPath = GoRouterState.of(context).uri.path;
    if (currentPath.contains('/hymn/')) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hymn = audioState.hymn!;

    final durationMs = audioState.duration.inMilliseconds.toDouble();
    final positionMs = audioState.position.inMilliseconds.toDouble();
    final progress = (durationMs > 0)
        ? (positionMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    String collectionLabel;
    if (hymn.collection == 'especiales') {
      collectionLabel = 'Especial';
    } else if (hymn.collection == 'coros') {
      collectionLabel = 'Coro';
    } else {
      collectionLabel = 'IUMP';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            // Regresar al canto en reproducción
            final hymnKey = '${hymn.collection}-${hymn.id}';
            context.go('/home/hymn/$hymnKey');
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF1E293B).withValues(alpha: 0.92),
                            const Color(0xFF0F172A).withValues(alpha: 0.96),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.95),
                            const Color(0xFFF1F5F9).withValues(alpha: 0.95),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Badge número / icono
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: audioState.isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          theme.colorScheme.primary,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.music_note_rounded,
                                      size: 22,
                                      color: theme.colorScheme.primary,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Título y tiempos
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${hymn.id}. ${hymn.title}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.black.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        collectionLabel,
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                    if (audioState.isLooping) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.repeat_one_rounded,
                                        size: 13,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_formatDuration(audioState.position)} / ${_formatDuration(audioState.duration)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Botón Play / Pause
                          IconButton(
                            icon: Icon(
                              audioState.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_filled_rounded,
                              size: 38,
                              color: theme.colorScheme.primary,
                            ),
                            tooltip: audioState.isPlaying ? 'Pausar' : 'Reanudar',
                            onPressed: () {
                              ref
                                  .read(globalAudioProvider.notifier)
                                  .togglePlayPause();
                            },
                          ),
                          // Botón Cerrar (Detener)
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                            tooltip: 'Detener y cerrar',
                            onPressed: () {
                              ref
                                  .read(globalAudioProvider.notifier)
                                  .stopAndClose();
                            },
                          ),
                        ],
                      ),
                    ),
                    // Barra de progreso delgada al fondo
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2.5,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

