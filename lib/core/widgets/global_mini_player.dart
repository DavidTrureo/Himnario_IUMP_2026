import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/hymns/presentation/spinning_vinyl.dart';
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

    // En tablets (iPad), la pantalla del canto muestra la tarjeta de estudio expandida (680px),
    // por lo que ocultamos el mini reproductor únicamente en tablet dentro de /hymn/.
    // En teléfonos móviles permanece siempre visible y esbelto sobre la barra de navegación.
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    String currentPath = '';
    try {
      currentPath = GoRouterState.of(context).uri.path;
    } catch (_) {}
    if (isTablet && currentPath.contains('/hymn/')) {
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

    // Paleta de color según la colección del canto
    final Color accentColor;
    final String collectionLabel;
    if (hymn.collection == 'especiales') {
      accentColor = const Color(0xFFA855F7); // Púrpura especial
      collectionLabel = 'Especial';
    } else if (hymn.collection == 'coros') {
      accentColor = const Color(0xFF10B981); // Esmeralda coro
      collectionLabel = 'Coro';
    } else {
      accentColor = theme.colorScheme.primary; // Azul celestial IUMP
      collectionLabel = 'Himno IUMP';
    }

    // Para Especiales y Coros, no mostrar el ID numérico interno (ej. 1164)
    final displayTitle = hymn.collection == 'iump'
        ? '${hymn.id}. ${hymn.title}'
        : hymn.title;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            // Regresar al canto en reproducción si estamos en otra pantalla
            final hymnKey = '${hymn.collection}-${hymn.id}';
            if (!currentPath.endsWith(hymnKey)) {
              try {
                context.go('/home/hymn/$hymnKey');
              } catch (_) {}
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
                            Colors.white.withValues(alpha: 0.96),
                            const Color(0xFFF8FAFC).withValues(alpha: 0.96),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: isDark ? 0.20 : 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      child: Row(
                        children: [
                          // Mini Carátula / Vinilo giratorio temático
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accentColor.withValues(alpha: 0.25),
                                  accentColor.withValues(alpha: 0.08),
                                ],
                              ),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: audioState.isLoading
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          accentColor,
                                        ),
                                      ),
                                    )
                                  : SpinningVinyl(
                                      isPlaying: audioState.isPlaying,
                                      color: accentColor,
                                      size: 22,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Título y Tiempos
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayTitle,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: accentColor.withValues(alpha: 0.3),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          collectionLabel,
                                          style: GoogleFonts.outfit(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: accentColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_formatDuration(audioState.position)} / ${_formatDuration(audioState.duration)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Botón interactivo de repetición continua (Loop)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () {
                                          ref
                                              .read(globalAudioProvider.notifier)
                                              .toggleLoop();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: Icon(
                                            audioState.isLooping
                                                ? Icons.repeat_one_rounded
                                                : Icons.repeat_rounded,
                                            size: 14,
                                            color: audioState.isLooping
                                                ? accentColor
                                                : (isDark
                                                    ? Colors.white38
                                                    : Colors.black38),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Controles: Retroceder 10s
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded),
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            color: isDark ? Colors.white70 : Colors.black87,
                            tooltip: 'Retroceder 10s',
                            onPressed: () {
                              ref
                                  .read(globalAudioProvider.notifier)
                                  .seekRelative(const Duration(seconds: -10));
                            },
                          ),
                          const SizedBox(width: 2),
                          // Botón Play / Pause hermoseado con resplandor
                          GestureDetector(
                            onTap: () {
                              ref
                                  .read(globalAudioProvider.notifier)
                                  .togglePlayPause();
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    accentColor,
                                    accentColor.withValues(alpha: 0.85),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  audioState.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          // Controles: Avanzar 10s
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded),
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            color: isDark ? Colors.white70 : Colors.black87,
                            tooltip: 'Avanzar 10s',
                            onPressed: () {
                              ref
                                  .read(globalAudioProvider.notifier)
                                  .seekRelative(const Duration(seconds: 10));
                            },
                          ),
                          const SizedBox(width: 2),
                          // Botón Cerrar (Detener)
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 19,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
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
                    // Barra de progreso delgada al fondo con color de colección
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                      child: SizedBox(
                        height: 3,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
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
