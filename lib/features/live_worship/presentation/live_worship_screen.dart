import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../hymns/domain/hymn.dart';
import '../../hymns/presentation/hymn_list_screen.dart';
import '../../hymns/presentation/notation_provider.dart';
import '../domain/live_session.dart';
import 'live_session_provider.dart';

// ─────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL: MODO CULTO EN VIVO
// ─────────────────────────────────────────────────────────────
class LiveWorshipScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const LiveWorshipScreen({super.key, required this.sessionId});

  @override
  ConsumerState<LiveWorshipScreen> createState() => _LiveWorshipScreenState();
}

class _LiveWorshipScreenState extends ConsumerState<LiveWorshipScreen> {
  String? _myDeviceId;
  bool _hasJoined = false;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    _initDeviceAndJoin();
  }

  Future<void> _initDeviceAndJoin() async {
    final deviceId = await ref.read(deviceIdProvider.future);
    setState(() => _myDeviceId = deviceId);

    // Registrar presencia en Firestore
    final session =
        await ref.read(liveSessionStreamProvider(widget.sessionId).future);
    if (session != null && session.directorDeviceId != deviceId) {
      await LiveSessionService.joinSession(widget.sessionId, deviceId);
      setState(() => _hasJoined = true);
    }
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    // Eliminar presencia al salir (solo si era participante)
    if (_hasJoined && _myDeviceId != null) {
      LiveSessionService.leaveSession(widget.sessionId, _myDeviceId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(liveSessionStreamProvider(widget.sessionId));
    final allHymnsAsync = ref.watch(allHymnsGlobalProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return sessionAsync.when(
      loading: () => Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Scaffold(
        body: Center(child: Text('Error al conectar: $e')),
      ),
      data: (session) {
        if (session == null) {
          return _buildSessionEnded(context, isDark);
        }
        if (!session.isActive) {
          return _buildSessionEnded(context, isDark);
        }

        final allHymns = allHymnsAsync.value ?? [];
        final isDirector = _myDeviceId == session.directorDeviceId;
        final hymns = _resolveHymns(session.hymnIds, allHymns);
        final currentHymn = hymns.isNotEmpty &&
                session.currentIndex < hymns.length
            ? hymns[session.currentIndex]
            : null;

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: Column(
            children: [
              // ─── Header ────────────────────────────────
              _buildHeader(context, ref, session, isDirector, hymns, isDark, theme),

              // ─── Himno actual ──────────────────────────
              Expanded(
                child: currentHymn == null
                    ? _buildEmptyState(isDark)
                    : _buildHymnView(currentHymn, session, isDark, theme),
              ),

              // ─── Controles del Director ────────────────
              if (isDirector)
                _buildDirectorControls(
                    context, ref, session, hymns, allHymns, isDark, theme),

              // ─── Barra de estado del Participante ──────
              if (!isDirector)
                _buildViewerBar(session, isDark, theme),
            ],
          ),
        );
      },
    );
  }

  // ─── HEADER ────────────────────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    LiveSession session,
    bool isDirector,
    List<Hymn> hymns,
    bool isDark,
    ThemeData theme,
  ) {
    final liveUrl =
        'https://himnario-vito-2026.web.app/culto-en-vivo/${session.sessionId}';

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 8, 16, 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.98)
            : Colors.white.withValues(alpha: 0.98),
        border: Border(
          bottom: BorderSide(
            color:
                isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          // Botón volver
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),

          // Indicador EN VIVO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  'EN VIVO',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat()).then(delay: 800.ms).fadeOut(duration: 400.ms).then().fadeIn(duration: 400.ms),

          const SizedBox(width: 10),

          // Título del culto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87),
                ),
                if (isDirector)
                  Text(
                    '${session.participantCount} ${session.participantCount == 1 ? 'participante' : 'participantes'} conectados',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45),
                  ),
              ],
            ),
          ),

          // Botones del Director: toggle acordes + QR + compartir
          if (isDirector) ...[
            // Toggle acordes
            IconButton(
              icon: Icon(
                session.showChords
                    ? Icons.music_note_rounded
                    : Icons.music_off_rounded,
                color: session.showChords
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
              tooltip: session.showChords ? 'Ocultar acordes' : 'Mostrar acordes',
              onPressed: () => LiveSessionService.setShowChords(
                  session.sessionId, !session.showChords),
            ),
            // QR
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded),
              tooltip: 'Código QR de la sesión',
              onPressed: () => _showQrDialog(context, liveUrl, session, isDark),
            ),
            // Compartir
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Compartir enlace',
              onPressed: () => _shareSessionLink(liveUrl, session),
            ),
          ],
        ],
      ),
    );
  }

  // ─── VISTA DEL HIMNO ───────────────────────────────────────
  Widget _buildHymnView(
      Hymn hymn, LiveSession session, bool isDark, ThemeData theme) {
    // Procesar letra ocultando acordes si showChords=false
    final rawLyrics = session.showChords
        ? hymn.lyrics
        : _stripChords(hymn.lyrics);

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.5,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Número e información básica
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${session.currentIndex + 1} de ${session.hymnIds.length}',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              if (hymn.tone.isNotEmpty || hymn.toneNote.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🎵 ${Hymn.formatToneDisplay(hymn.tone.isNotEmpty ? hymn.tone : hymn.toneNote, ref.watch(notationProvider))}',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Título del himno
          Text(
            hymn.collection == 'iump' ? '${hymn.id} - ${hymn.title}' : hymn.title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            hymn.collection == 'iump' 
                ? 'Himnario IUMP' 
                : (hymn.collection == 'especiales' ? 'Alabanza Especial' : 'Coro de Avivamiento'),
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Letra sanitizada y formateada profesionalmente
          _buildFormattedLyricsDisplay(rawLyrics, hymn.title, isDark, theme),
        ],
      ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  int? _parseRomanNumeral(String clean) {
    clean = clean.toUpperCase().trim();
    const map = {
      'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5, 'VI': 6,
      'VII': 7, 'VIII': 8, 'IX': 9, 'X': 10, 'XI': 11, 'XII': 12,
    };
    return map[clean];
  }

  List<String> _getMergedBlocks(String lyrics) {
    final List<String> rawBlocks = lyrics.split('\n\n');
    final List<String> merged = [];
    
    final RegExp prefixRegExp = RegExp(
      r'^(\d+|[IVXivx]+|coro|final|solista|puente|interludio)(?:\s*[\.\-:\s]|$)', 
      caseSensitive: false
    );

    for (final block in rawBlocks) {
      final trimmedBlock = block.trim();
      if (trimmedBlock.isEmpty) continue;
      
      if (merged.isEmpty) {
        merged.add(trimmedBlock);
      } else {
        final lastBlock = merged.last;
        final firstLineLast = lastBlock.split('\n').first.trim();
        final firstLineCurrent = trimmedBlock.split('\n').first.trim();
        
        final prevHasPrefix = prefixRegExp.hasMatch(firstLineLast);
        final currentHasPrefix = prefixRegExp.hasMatch(firstLineCurrent);
        
        if (prevHasPrefix && !currentHasPrefix) {
          merged[merged.length - 1] = '$lastBlock\n\n$trimmedBlock';
        } else {
          merged.add(trimmedBlock);
        }
      }
    }
    return merged;
  }

  Widget _buildFormattedLyricsDisplay(String rawLyrics, String title, bool isDark, ThemeData theme) {
    final sanitized = Hymn.ensureHeadersOnOwnLine(rawLyrics);
    final blocks = _getMergedBlocks(sanitized);

    final RegExp keywordRegExp = RegExp(
      r'^(coro\s+[ivx]+|coro\s+\d+|coro\s+final|coro|final|solista|puente|interludio)(?:\s*:\s*|\s+|$)', 
      caseSensitive: false
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: blocks.map((block) {
        final trimmed = block.trim();
        if (trimmed.isEmpty) return const SizedBox();

        final lines = trimmed.split('\n');
        final firstLine = lines.first.trim();
        final match = keywordRegExp.firstMatch(firstLine);
        final isChorus = match != null;

        if (isChorus) {
          String keyword = match.group(1)!.toLowerCase();
          final RegExp coroRomanRegExp = RegExp(r'^coro\s+([ivx]+)$', caseSensitive: false);
          final coroRomanMatch = coroRomanRegExp.firstMatch(keyword);
          if (coroRomanMatch != null) {
            final romanPart = coroRomanMatch.group(1)!;
            final decimal = _parseRomanNumeral(romanPart);
            if (decimal != null) {
              keyword = 'coro $decimal';
            }
          }
          final String headerText = keyword.toUpperCase();
          final String firstLineContent = firstLine.substring(match.end).trim();
          final List<String> bodyLines = [];
          if (firstLineContent.isNotEmpty) {
            bodyLines.add(firstLineContent);
          }
          bodyLines.addAll(lines.skip(1));

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1B4B).withValues(alpha: 0.4)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 4,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    headerText,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                ...bodyLines.map((line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    Hymn.formatLineCasing(line),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white.withValues(alpha: 0.95) : const Color(0xFF1E293B),
                    ),
                  ),
                )),
              ],
            ),
          );
        }

        // Estrofa estándar
        Widget? numberWidget;
        final arabicMatch = RegExp(r'^(\d+)(?:\s*\.\s*|\s*\-\s*|\s+|$)(.*)').firstMatch(firstLine);
        String firstLineRest = firstLine;
        if (arabicMatch != null) {
          final numStr = arabicMatch.group(1)!;
          firstLineRest = arabicMatch.group(2)?.trim() ?? '';
          numberWidget = Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 4),
            child: Text(
              '$numStr.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          );
        } else {
          final romanMatch = RegExp(r'^([IVXivx]+)(?:\s*\.\s*|\s*\-\s*|\s+|$)(.*)').firstMatch(firstLine);
          if (romanMatch != null) {
            final romanStr = romanMatch.group(1)!;
            final converted = _parseRomanNumeral(romanStr);
            if (converted != null) {
              firstLineRest = romanMatch.group(2)?.trim() ?? '';
              numberWidget = Padding(
                padding: const EdgeInsets.only(bottom: 4, top: 4),
                child: Text(
                  '$converted.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              );
            }
          }
        }

        final List<String> bodyLines = [];
        if (firstLineRest.isNotEmpty || numberWidget == null) {
          bodyLines.add(firstLineRest);
        }
        bodyLines.addAll(lines.skip(1));

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (numberWidget != null) numberWidget,
              ...bodyLines.map((line) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    Hymn.formatLineCasing(line),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      height: 1.6,
                      color: isDark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF334155),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── CONTROLES DEL DIRECTOR ────────────────────────────────
  Widget _buildDirectorControls(
    BuildContext context,
    WidgetRef ref,
    LiveSession session,
    List<Hymn> resolvedHymns,
    List<Hymn> allHymns,
    bool isDark,
    ThemeData theme,
  ) {
    final canPrev = session.currentIndex > 0;
    final canNext = session.currentIndex < session.hymnIds.length - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.98)
            : Colors.white.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navegación
          Row(
            children: [
              // Anterior
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.skip_previous_rounded),
                  label: const Text('Anterior'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                      color: canPrev
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white24 : Colors.black12),
                    ),
                    foregroundColor: canPrev
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.white38 : Colors.black26),
                  ),
                  onPressed: canPrev
                      ? () => LiveSessionService.setCurrentIndex(
                          session.sessionId, session.currentIndex - 1)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // Siguiente
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Siguiente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: canNext
                      ? () => LiveSessionService.setCurrentIndex(
                          session.sessionId, session.currentIndex + 1)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Agregar + Terminar
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.playlist_add_rounded, size: 20),
                label: const Text('Agregar canto'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () =>
                    _showAddHymnDialog(context, ref, session, allHymns, isDark),
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.stop_circle_outlined,
                    color: Colors.redAccent, size: 20),
                label: const Text('Terminar culto',
                    style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: () => _confirmEndSession(context, session),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── BARRA DE PARTICIPANTE ─────────────────────────────────
  Widget _buildViewerBar(LiveSession session, bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.98)
            : Colors.white.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility_rounded,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black26),
          const SizedBox(width: 6),
          Text(
            'Modo Participante — El Director controla la sesión',
            style: GoogleFonts.outfit(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  // ─── SESIÓN TERMINADA ──────────────────────────────────────
  Widget _buildSessionEnded(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.church_rounded,
                size: 72,
                color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 20),
            Text(
              'El culto ha finalizado',
              style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              'El Director ha cerrado esta sesión',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ESTADO VACÍO ──────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Text(
        'No hay himnos en este repertorio',
        style: GoogleFonts.outfit(
            color: isDark ? Colors.white38 : Colors.black38),
      ),
    );
  }

  // ─── DIÁLOGO QR ────────────────────────────────────────────
  void _showQrDialog(
      BuildContext context, String url, LiveSession session, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Código QR del Culto',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.title,
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 16),
            // URL copiable
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Enlace copiado al portapapeles')),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark
                          ? Colors.white12
                          : Colors.black12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        url,
                        style: GoogleFonts.outfit(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Compartir'),
            onPressed: () {
              ctx.pop();
              _shareSessionLink(url, session);
            },
          ),
        ],
      ),
    );
  }

  // ─── COMPARTIR ENLACE ──────────────────────────────────────
  Future<void> _shareSessionLink(String url, LiveSession session) async {
    final text =
        '🎵 *${session.title}*\n📅 ${session.date}\n\nÚnete al Modo Culto en Vivo:\n$url';

    if (kIsWeb) {
      // En Web: copiar al portapapeles + abrir WhatsApp
      await Clipboard.setData(ClipboardData(text: url));
      final whatsappUrl = Uri.parse(
          'https://wa.me/?text=${Uri.encodeComponent(text)}');
      final uri = whatsappUrl;
      // ignore: deprecated_member_use
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await SharePlus.instance.share(
          ShareParams(text: text, subject: session.title));
    }
  }

  // ─── AGREGAR CANTO EN VIVO ─────────────────────────────────
  void _showAddHymnDialog(
    BuildContext context,
    WidgetRef ref,
    LiveSession session,
    List<Hymn> allHymns,
    bool isDark,
  ) {
    String searchQ = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModal) {
          final filtered = allHymns.where((h) {
            if (session.hymnIds.contains('${h.collection}-${h.id}')) return false;
            if (searchQ.trim().isEmpty) return true;
            
            final normQ = Hymn.normalizeString(searchQ);
            if (normQ.isEmpty) return true;
            
            // Buscar solo coincidencia en título o ID
            final idMatch = h.id.toString() == searchQ.trim();
            final titleMatch = h.normalizedTitle.contains(normQ);
            return idMatch || titleMatch;
          }).toList();

          filtered.sort((a, b) {
            if (searchQ.trim().isNotEmpty) {
              final normQ = Hymn.normalizeString(searchQ);
              final exactA = a.normalizedTitle == normQ ? 1 : 0;
              final exactB = b.normalizedTitle == normQ ? 1 : 0;
              if (exactA != exactB) return exactB.compareTo(exactA);

              final startsA = a.normalizedTitle.startsWith(normQ) ? 1 : 0;
              final startsB = b.normalizedTitle.startsWith(normQ) ? 1 : 0;
              if (startsA != startsB) return startsB.compareTo(startsA);
            }
            final pa = a.collection == 'iump' ? 1 : (a.collection == 'especiales' ? 2 : 3);
            final pb = b.collection == 'iump' ? 1 : (b.collection == 'especiales' ? 2 : 3);
            return pa != pb ? pa.compareTo(pb) : a.title.compareTo(b.title);
          });

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.97)
                  : Colors.white.withValues(alpha: 0.97),
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Añadir Canto en Vivo',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por título o número...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (v) => setModal(() => searchQ = v),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final h = filtered[i];
                        return ListTile(
                          title: Text(h.collection == 'iump' ? '${h.id} - ${h.title}' : h.title,
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            h.collection == 'iump'
                                ? 'Himno #${h.id}'
                                : (h.collection == 'especiales'
                                    ? 'Alabanza Especial'
                                    : 'Coro'),
                            style: GoogleFonts.outfit(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.add_circle_outline_rounded),
                          onTap: () async {
                            final newIds = List<String>.from(session.hymnIds)
                              ..add('${h.collection}-${h.id}');
                            await LiveSessionService.updateHymnIds(
                                session.sessionId, newIds);
                            if (ctx2.mounted) Navigator.of(ctx2).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── CONFIRMAR FINALIZAR SESIÓN ────────────────────────────
  void _confirmEndSession(BuildContext context, LiveSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Terminar el culto?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Todos los participantes verán que el culto ha finalizado y serán desconectados.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              ctx.pop();
              await LiveSessionService.endSession(session.sessionId);
              if (context.mounted) context.pop();
            },
            child: const Text('Terminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────
  List<Hymn> _resolveHymns(List<String> hymnIds, List<Hymn> allHymns) {
    final result = <Hymn>[];
    for (final hId in hymnIds) {
      final parts = hId.split('-');
      final col = parts[0];
      final id = int.tryParse(parts.sublist(1).join('-')) ?? 0;
      final match = allHymns.firstWhere(
        (h) => h.collection == col && h.id == id,
        orElse: () => Hymn(
            id: 0, title: '', toneNote: '', beats: '',
            timeSignature: '', lyrics: '', collection: ''),
      );
      if (match.id != 0) result.add(match);
    }
    return result;
  }

  String _stripChords(String lyrics) {
    // Elimina acordes entre corchetes: [DO] [SOLm] etc.
    return lyrics.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
  }
}
