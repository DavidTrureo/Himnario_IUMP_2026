import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/hymn.dart';
import '../../../core/services/gemini_ai_service.dart';
import 'hymn_list_screen.dart';
import 'notation_provider.dart';
import 'presentation_screen.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../favorites/domain/favorites_notifier.dart';
import '../../setlists/presentation/setlists_provider.dart';
import '../../../core/services/chord_transposer_service.dart';
import '../../../core/services/local_hymn_storage_service.dart';
import 'widgets/chord_diagram_dialog.dart';
import 'widgets/visual_metronome_widget.dart';
import '../../../core/widgets/app_music_icons.dart';
import '../../../core/services/hymn_pdf_service.dart';
import 'widgets/sheet_music_viewer.dart';

// Notifier para controlar el tamaño de la letra
class FontSizeNotifier extends Notifier<double> {
  @override
  double build() => 18.0;

  void increase() {
    if (state < 40.0) state += 2.0;
  }

  void decrease() {
    if (state > 12.0) state -= 2.0;
  }

  void setFontSize(double val) {
    state = val.clamp(14.0, 32.0);
  }
}

final fontSizeProvider = NotifierProvider<FontSizeNotifier, double>(() {
  return FontSizeNotifier();
});

final ignoredDuplicatePairsProvider = FutureProvider<Set<String>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList('ignored_duplicate_pairs') ?? [];
  return list.toSet();
});

class HymnDetailScreen extends ConsumerStatefulWidget {
  final String hymnId;

  const HymnDetailScreen({super.key, required this.hymnId});

  @override
  ConsumerState<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends ConsumerState<HymnDetailScreen> {
  PageController? _pageController;
  int? _currentIndex;
  List<Hymn> _sortedHymns = [];
  bool _initialized = false;
  int _transposeOffset = 0;
  bool _showChords = true;
  String _notation = 'spanish';
  bool _showControlPanel = false; // Oculto por defecto para no tapar las letras
  bool _showMetronome = false; // Metrónomo visual silencioso
  bool _metronomeTop = true;
  bool _metronomeVertical = false;

  // Modo de vista: 'texto' o 'partitura'
  String _viewMode = 'texto';

  // Variables de estado para reproducción de audio
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoadingAudio = false;
  String? _currentAudioUrl;
  bool _showPlayerCard = false;

  YoutubePlayerController? _youtubeController;
  final ScrollController _scrollController = ScrollController();
  bool _isAutoScrolling = false;
  double _autoScrollSpeed = 30.0;

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
    });
    if (_isAutoScrolling) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() async {
    while (_isAutoScrolling) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients && _isAutoScrolling) {
        final double maxScroll = _scrollController.position.maxScrollExtent;
        final double currentScroll = _scrollController.offset;
        final double delta = _autoScrollSpeed / 10.0; // Píxeles por iteración

        if (currentScroll + delta >= maxScroll) {
          // Llegamos al final
          _scrollController.jumpTo(maxScroll);
          setState(() {
            _isAutoScrolling = false;
          });
          break;
        } else {
          _scrollController.animateTo(
            currentScroll + delta,
            duration: const Duration(milliseconds: 100),
            curve: Curves.linear,
          );
        }
      } else {
        break;
      }
    }
  }


  void _updateYoutubePlayer(Hymn hymn) {
    final audioUrl = hymn.audioUrl;
    if (audioUrl.isNotEmpty && (audioUrl.contains('youtube.com') || audioUrl.contains('youtu.be'))) {
      final videoId = YoutubePlayerController.convertUrlToId(audioUrl);
      if (videoId != null) {
        if (_youtubeController == null) {
          _youtubeController = YoutubePlayerController.fromVideoId(
            videoId: videoId,
            autoPlay: false,
            params: const YoutubePlayerParams(showControls: true, mute: false),
          );
        } else {
          _youtubeController!.loadVideoById(videoId: videoId);
          _youtubeController!.pauseVideo();
        }
      }
    } else {
      _youtubeController?.pauseVideo();
    }
  }

  String? _lastLyricsForBlocks;
  int? _lastTransposeOffsetForBlocks;
  List<String> _cachedBlocks = [];

  static final Map<String, Hymn?> _similarityCache = {};

  Hymn? _getSimilarHymnCached(Hymn current, List<Hymn> allHymns, Set<String> ignoredPairs) {
    final key = '${current.collection}-${current.id}';
    if (_similarityCache.containsKey(key)) {
      final cached = _similarityCache[key];
      if (cached != null) {
        final pairKey2 = '${cached.collection}-${cached.id}';
        if (ignoredPairs.contains('${key}_${pairKey2}') || ignoredPairs.contains('${pairKey2}_${key}')) {
          _similarityCache[key] = null;
          return null;
        }
      }
      return cached;
    }
    final result = _findSimilarHymn(current, allHymns, ignoredPairs: ignoredPairs);
    _similarityCache[key] = result;
    return result;
  }

  List<String> _getMergedBlocksCached(String lyrics, int transposeOffset) {
    if (_lastLyricsForBlocks == lyrics && _lastTransposeOffsetForBlocks == transposeOffset) {
      return _cachedBlocks;
    }
    _lastLyricsForBlocks = lyrics;
    _lastTransposeOffsetForBlocks = transposeOffset;
    final sanitized = Hymn.ensureHeadersOnOwnLine(lyrics);
    final transposedLyrics = Hymn.transposeLyrics(sanitized, transposeOffset);
    _cachedBlocks = _getMergedBlocks(transposedLyrics);
    return _cachedBlocks;
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showChords = prefs.getBool('pref_show_chords') ?? true;
      _notation = prefs.getString('pref_chords_notation') ?? 'spanish';
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_show_chords', _showChords);
    await prefs.setString('pref_chords_notation', _notation);
  }

  @override
  void dispose() {
    _scrollController.dispose();

    _pageController?.dispose();
    _audioPlayer?.dispose();
    _youtubeController?.close();
    super.dispose();
  }

  void _initializeHymns(List<Hymn> hymns) {
    final parts = widget.hymnId.split('-');
    final collectionParam = parts.length > 1 ? parts[0] : 'iump';
    final idString = parts.length > 1 ? parts.sublist(1).join('-') : widget.hymnId;
    final id = int.tryParse(idString) ?? 0;

    if (_initialized && _sortedHymns.isNotEmpty) {
      final exists = _sortedHymns.any((h) => h.collection == collectionParam && h.id == id);
      if (exists) return;
    }

    final activeSetlist = ref.read(activeSetlistProvider);

    _sortedHymns = [];

    if (activeSetlist != null) {
      for (final hId in activeSetlist.hymnIds) {
        final hParts = hId.split('-');
        final hCol = hParts[0];
        final hIdNum = int.tryParse(hParts.sublist(1).join('-')) ?? 0;
        final matching = hymns.firstWhere(
          (h) => h.collection == hCol && h.id == hIdNum,
          orElse: () => Hymn(
              id: 0,
              title: '',
              toneNote: '',
              beats: '',
              timeSignature: '',
              lyrics: '',
              collection: ''),
        );
        if (matching.id != 0) {
          _sortedHymns.add(matching);
        }
      }
    }

    // Fallback 1: Si no hay cantos del setlist o el id buscado no está en el setlist, cargar la colección normal
    var startIndex = _sortedHymns.indexWhere((h) => h.collection == collectionParam && h.id == id);
    if (_sortedHymns.isEmpty || startIndex == -1) {
      _sortedHymns = hymns.where((h) => h.collection == collectionParam).toList();
      if (collectionParam == 'iump') {
        _sortedHymns.sort((a, b) => a.id.compareTo(b.id));
      } else {
        _sortedHymns.sort((a, b) => a.title.compareTo(b.title));
      }
      startIndex = _sortedHymns.indexWhere((h) => h.collection == collectionParam && h.id == id);
    }

    // Fallback 2: Buscar en todo el catálogo global por id o título
    if (_sortedHymns.isEmpty || startIndex == -1) {
      final globalMatch = hymns.where((h) => h.id == id).toList();
      if (globalMatch.isNotEmpty) {
        _sortedHymns = globalMatch;
        startIndex = 0;
      }
    }

    if (startIndex != -1 && startIndex < _sortedHymns.length) {
      _currentIndex = startIndex;
      _pageController = PageController(initialPage: startIndex);
    } else if (_sortedHymns.isNotEmpty) {
      _currentIndex = 0;
      _pageController = PageController(initialPage: 0);
    }
    _initialized = true;
    if (_currentIndex != null && _currentIndex! < _sortedHymns.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateYoutubePlayer(_sortedHymns[_currentIndex!]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allHymnsAsync = ref.watch(allHymnsGlobalProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final favorites = ref.watch(favoritesProvider);
    final theme = Theme.of(context);
    final adminMode = ref.watch(adminModeProvider);
    final isDark = theme.brightness == Brightness.dark;
    final dbStatus = ref.watch(databaseStatusProvider);

    // Usar datos previos durante la recarga para evitar pantalla en blanco
    final hymns = allHymnsAsync.whenOrNull(data: (d) => d);

    // Si nunca se han cargado datos, mostrar estados de carga/error
    if (hymns == null) {
      return allHymnsAsync.when(
        data: (_) => const SizedBox.shrink(), // no debería llegar aquí
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, s) => Scaffold(
          body: Center(child: Text('Error: $e')),
        ),
      );
    }

    _initializeHymns(hymns);

    // Actualizar los datos de los himnos en la lista ordenada para reflejar
    // los cambios hechos (e.g. acordes agregados/removidos) sin perder la
    // posición ni el PageController.
    if (_initialized) {
      for (int i = 0; i < _sortedHymns.length; i++) {
        final old = _sortedHymns[i];
        final updated = hymns.where(
          (h) => h.collection == old.collection && h.id == old.id,
        ).firstOrNull;
        if (updated != null && updated != old) {
          _sortedHymns[i] = updated;
        }
      }
    }

    if (_sortedHymns.isEmpty || _currentIndex == null || _pageController == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Catálogo', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              context.pop();
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Regresando al catálogo...',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Volver a la Lista'),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/hymns');
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    final hymn = _sortedHymns[_currentIndex!];
    final isFavorite = favorites.contains('${hymn.collection}-${hymn.id}');

    final activeSetlist = ref.watch(activeSetlistProvider);
    final String moduleBadgeText = activeSetlist != null
        ? '📋 MODO CULTO • ${activeSetlist.title}'
        : (hymn.collection == 'iump' 
            ? '🏛️ HIMNARIO IUMP' 
            : (hymn.collection == 'especiales' ? '✨ ALABANZAS ESPECIALES' : '🔥 COROS DE AVIVAMIENTO'));

    return PopScope(
      canPop: true,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              context.pop();
            },
          ),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: isDark 
                  ? theme.colorScheme.surface.withValues(alpha: 0.5) 
                  : Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
          title: AutoScrollingAppBarTitle(
            badgeText: moduleBadgeText,
            titleText: hymn.collection == 'iump' ? 'Himno ${hymn.id} - ${hymn.title}' : hymn.title,
            primaryColor: theme.colorScheme.primary,
          ),
            actions: [
              _buildDatabaseStatusWidget(dbStatus, theme, isDark),

              if (hymn.audioUrl.isNotEmpty && !hymn.audioUrl.contains('youtube.com') && !hymn.audioUrl.contains('youtu.be'))
                IconButton(
                  icon: const Icon(Icons.cloud_download_rounded),
                  tooltip: 'Descargar audio para escuchar sin internet',
                  onPressed: () => _downloadAudio(hymn),
                ),
              if (hymn.audioUrl.isNotEmpty)
                IconButton(
                  icon: Icon(
                    hymn.audioUrl.contains('youtube.com') || hymn.audioUrl.contains('youtu.be')
                        ? Icons.play_circle_filled_rounded
                        : (_audioPlayer != null && _isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded),
                    color: hymn.audioUrl.contains('youtube.com') || hymn.audioUrl.contains('youtu.be')
                        ? Colors.redAccent
                        : (_audioPlayer != null && _isPlaying ? theme.colorScheme.primary : null),
                  ),
                  tooltip: hymn.audioUrl.contains('youtube.com') || hymn.audioUrl.contains('youtu.be')
                      ? 'Ver en YouTube (Enlace Oficial)'
                      : (_isPlaying ? 'Pausar audio' : 'Escuchar audio (Streaming)'),
                  onPressed: () {
                    final isYoutube = hymn.audioUrl.contains('youtube.com') || hymn.audioUrl.contains('youtu.be');
                    if (isYoutube) {
                      final uri = Uri.parse(hymn.audioUrl.trim());
                      launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) {
                        return launchUrl(uri, mode: LaunchMode.platformDefault);
                      }).catchError((e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No se pudo abrir el enlace: $e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return false;
                      });
                    } else {
                      if (_audioPlayer != null && _currentAudioUrl == hymn.audioUrl) {
                        if (_isPlaying) {
                          _audioPlayer!.pause();
                        } else {
                          _audioPlayer!.play();
                        }
                      } else {
                        setState(() {
                          _showPlayerCard = true;
                        });
                        _initAudio(hymn.audioUrl);
                      }
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.playlist_add_rounded),
                tooltip: 'Agregar a Repertorio',
                onPressed: () {
                  _showAddToSetlistDialog(context, ref, hymn);
                },
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorite ? Colors.red : (isDark ? Colors.white60 : Colors.black54),
                ),
                tooltip: isFavorite ? 'Quitar marcador' : 'Guardar himno',
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggleFavorite('${hymn.collection}-${hymn.id}');
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'metronome':
                      setState(() {
                        _showMetronome = !_showMetronome;
                      });
                      break;
                    case 'sheet_music':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SheetMusicViewer(hymn: hymn)),
                      );
                      break;
                    case 'pdf':
                      _showExportPdfModal(context, hymn);
                      break;
                    case 'projector_pc':
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PresentationScreen(hymn: hymn),
                        ),
                      );
                      break;
                    case 'projector_tv':
                      _showConnectToTvDialog(context, hymn);
                      break;
                    case 'youtube':
                      _launchYouTubeSearch(hymn.title);
                      break;
                    case 'edit':
                      _showEditHymnDialog(context, ref, hymn);
                      break;
                    case 'delete':
                      _confirmDeleteHymn(context, ref, hymn);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'metronome',
                    child: Row(
                      children: [
                        TraditionalMetronomeIcon(
                          size: 20,
                          color: _showMetronome ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 10),
                        Text(_showMetronome ? 'Ocultar metrónomo' : 'Metrónomo silencioso', style: GoogleFonts.nunito()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sheet_music',
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Icon(
                              Icons.library_music_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            if (hymn.sheetMusicUrls.isNotEmpty)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 6, minHeight: 6),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Text('Gestionar Partituras', style: GoogleFonts.nunito()),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 10),
                        Text('Compartir Canto en PDF', style: GoogleFonts.nunito()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'projector_pc',
                    child: Row(
                      children: [
                        const Icon(Icons.computer_rounded, size: 20),
                        const SizedBox(width: 10),
                        Text('Modo Proyector (PC/Mac)', style: GoogleFonts.nunito()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'projector_tv',
                    child: Row(
                      children: [
                        const Icon(Icons.tv_rounded, size: 20),
                        const SizedBox(width: 10),
                        Text('Control Remoto (Smart TV)', style: GoogleFonts.nunito()),
                      ],
                    ),
                  ),
                  if (hymn.audioUrl.isEmpty)
                    PopupMenuItem(
                      value: 'youtube',
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_outline_rounded, size: 20),
                          const SizedBox(width: 10),
                          Text('Buscar en YouTube', style: GoogleFonts.nunito()),
                        ],
                      ),
                    ),
                  if (adminMode) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Text('Editar himno', style: GoogleFonts.nunito(color: theme.colorScheme.primary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                          const SizedBox(width: 10),
                          Text('Eliminar himno', style: GoogleFonts.nunito(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              // Fondo Aurora Decorativa (Estático detrás del PageView)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark 
                      ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                      : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                  ),
                ),
              ),
              Positioned(
                top: 100,
                right: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: isDark 
                      ? const Color(0xFF6366F1).withValues(alpha: 0.06) 
                      : const Color(0xFF818CF8).withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: const SizedBox(),
                ),
              ),

              // PageView Deslizable con las Alabanzas
              Positioned.fill(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _sortedHymns.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                      _transposeOffset = 0; // Resetear transposición al cambiar de himno
                      _showPlayerCard = false;
                      _audioPlayer?.stop(); // Detener el audio al cambiar de canto
                      _updateYoutubePlayer(_sortedHymns[index]);
                    });
                  },
                  itemBuilder: (context, index) {
                    final currentHymn = _sortedHymns[index];
                    return _buildHymnPage(context, currentHymn, fontSize, isDark, theme);
                  },
                ),
                  ),
                ),
              ),
              
              // Controlador flotante de tamaño de letra al fondo de la pantalla (Colapsable)
              if (_showControlPanel)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20 + MediaQuery.of(context).padding.bottom,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark 
                            ? const Color(0xFF1E293B).withValues(alpha: 0.8) 
                            : Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Fila de encabezado con botón de cerrar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ajustes de Lectura',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  tooltip: 'Ocultar ajustes',
                                  onPressed: () {
                                    setState(() {
                                      _showControlPanel = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            if (hymn.lyrics.contains('[')) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.music_note_rounded,
                                      size: 18,
                                      color: isDark ? Colors.white60 : Colors.black45,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Transponer Tono',
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () {
                                        setState(() {
                                          _transposeOffset--;
                                        });
                                      },
                                    ),
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 32),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _transposeOffset == 0 
                                          ? 'Orig.' 
                                          : (_transposeOffset > 0 ? '+$_transposeOffset' : '$_transposeOffset'),
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () {
                                        setState(() {
                                          _transposeOffset++;
                                        });
                                      },
                                    ),
                                    if (_transposeOffset != 0)
                                      IconButton(
                                        icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        tooltip: 'Restablecer',
                                        onPressed: () {
                                          setState(() {
                                            _transposeOffset = 0;
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _showChords ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                      size: 18,
                                      color: isDark ? Colors.white60 : Colors.black45,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ver Acordes',
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      height: 20,
                                      width: 32,
                                      child: Transform.scale(
                                        scale: 0.75,
                                        child: Switch(
                                          value: _showChords,
                                          activeThumbColor: theme.colorScheme.primary,
                                          onChanged: (val) {
                                            setState(() {
                                              _showChords = val;
                                              _savePreferences();
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                      width: 0.8,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Row(
                                    children: [
                                      _buildNotationPill('spanish', 'Latino (DO)', theme, isDark),
                                      const SizedBox(width: 2),
                                      _buildNotationPill('american', 'Amer. (C)', theme, isDark),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                          ],
                          Row(
                            children: [
                              Icon(
                                Icons.text_fields_rounded, 
                                size: 20, 
                                color: isDark ? Colors.white60 : Colors.black45
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3.5,
                                    activeTrackColor: theme.colorScheme.primary,
                                    inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                                    thumbColor: theme.colorScheme.primary,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                  ),
                                  child: Slider(
                                    min: 14.0,
                                    max: 32.0,
                                    value: fontSize,
                                    onChanged: (val) {
                                      ref.read(fontSizeProvider.notifier).setFontSize(val);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${fontSize.toInt()}',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          ],
                        ),
                      ),
                    ),
                  ),
                        ),
                      ),
                    ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

              // Botón flotante para abrir los Ajustes de Lectura
              if (!_showControlPanel)
                Positioned(
                  right: 20,
                  bottom: (_showPlayerCard ? 150 : 20) + MediaQuery.of(context).padding.bottom,
                  child: FloatingActionButton.small(
                    heroTag: 'show-tools-fab',
                    elevation: 4,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onPressed: () {
                      setState(() {
                        _showControlPanel = true;
                      });
                    },
                    child: const Icon(Icons.tune_rounded),
                  ),
                ).animate().fadeIn(delay: 200.ms).scale(),

              // Botón flotante para Autoscroll
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                right: 20,
                bottom: (_showControlPanel 
                    ? 360.0 
                    : (_showPlayerCard ? 230.0 : 100.0) + (_showControlPanel ? 0 : 60)) + MediaQuery.of(context).padding.bottom,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isAutoScrolling) ...[
                      FloatingActionButton.small(
                        heroTag: 'autoscroll-faster',
                        backgroundColor: isDark ? const Color(0xFF334155) : Colors.white,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        onPressed: () {
                          setState(() {
                            _autoScrollSpeed = (_autoScrollSpeed + 10.0).clamp(10.0, 150.0);
                          });
                        },
                        tooltip: 'Más rápido',
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'autoscroll-slower',
                        backgroundColor: isDark ? const Color(0xFF334155) : Colors.white,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        onPressed: () {
                          setState(() {
                            _autoScrollSpeed = (_autoScrollSpeed - 10.0).clamp(10.0, 150.0);
                          });
                        },
                        tooltip: 'Más lento',
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(height: 16),
                    ],
                    FloatingActionButton(
                      heroTag: 'autoscroll-fab',
                      backgroundColor: isDark ? const Color(0xFF6366F1) : theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      onPressed: _toggleAutoScroll,
                      tooltip: _isAutoScrolling ? 'Pausar autoscroll' : 'Iniciar autoscroll',
                      child: Icon(_isAutoScrolling ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    ),
                  ],
                ),
              ),

              // Reproductor de Audio Flotante (Glassmorphic)
              if (_showPlayerCard && _audioPlayer != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: (_showControlPanel ? 290 : 100) + MediaQuery.of(context).padding.bottom,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark 
                            ? const Color(0xFF0F172A).withValues(alpha: 0.85) 
                            : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.audiotrack_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Reproduciendo: ${hymn.title}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isLoadingAudio)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                    ),
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () {
                                      setState(() {
                                        _showPlayerCard = false;
                                        _audioPlayer?.stop();
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                    size: 32,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    if (_isPlaying) {
                                      _audioPlayer?.pause();
                                    } else {
                                      _audioPlayer?.play();
                                    }
                                  },
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3.0,
                                      activeTrackColor: theme.colorScheme.primary,
                                      inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                                      thumbColor: theme.colorScheme.primary,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                    ),
                                    child: Slider(
                                      min: 0.0,
                                      max: _duration.inMilliseconds.toDouble(),
                                      value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
                                      onChanged: (val) {
                                        _audioPlayer?.seek(Duration(milliseconds: val.toInt()));
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_position),
                                    style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                                  ),
                                  Text(
                                    _formatDuration(_duration),
                                    style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1),

              // Metrónomo Flotante Interactivo (Ubicación Rápida mediante Botones Dedicados)
              if (_showMetronome)
                Positioned(
                  top: _metronomeTop ? (MediaQuery.of(context).padding.top + kToolbarHeight + 4) : null,
                  bottom: !_metronomeTop ? (85 + MediaQuery.of(context).padding.bottom) : null,
                  left: _metronomeVertical ? (MediaQuery.of(context).size.width - 82) : 4,
                  right: _metronomeVertical ? 6 : 4,
                  child: VisualMetronomeWidget(
                    initialBpm: 80,
                    isTopPosition: _metronomeTop,
                    isVerticalLayout: _metronomeVertical,
                    onClose: () {
                      setState(() {
                        _showMetronome = false;
                      });
                    },
                    onTogglePosition: () {
                      setState(() {
                        _metronomeTop = !_metronomeTop;
                      });
                    },
                    onToggleOrientation: () {
                      setState(() {
                        _metronomeVertical = !_metronomeVertical;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      );
  }

  Future<String> _getLocalAudioPath(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final hash = url.hashCode.toString();
    return '${dir.path}/hymn_audio_$hash.mp3';
  }

  Future<void> _downloadAudio(Hymn hymn) async {
    if (hymn.audioUrl.isEmpty) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando audio...'), behavior: SnackBarBehavior.floating),
    );

    try {
      final localPath = await _getLocalAudioPath(hymn.audioUrl);
      final file = File(localPath);
      
      if (await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este audio ya estaba descargado localmente.'), behavior: SnackBarBehavior.floating),
          );
          setState(() {});
        }
        return;
      }
      
      final response = await http.get(Uri.parse(hymn.audioUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Audio descargado con éxito para escuchar sin internet!'), behavior: SnackBarBehavior.floating),
          );
          setState(() {}); 
        }
      } else {
        throw Exception('Código de estado HTTP: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar audio: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _initAudio(String url) async {
    if (_audioPlayer != null && _currentAudioUrl == url) return;

    setState(() {
      _isLoadingAudio = true;
    });

    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.dispose();
      }

      final player = AudioPlayer();
      _audioPlayer = player;
      _currentAudioUrl = url;

      if (kIsWeb) {
        await player.setUrl(url);
      } else {
        final localPath = await _getLocalAudioPath(url);
        final file = File(localPath);
        if (await file.exists()) {
          debugPrint('>>> Reproduciendo audio desde memoria local: $localPath');
          await player.setFilePath(localPath);
        } else {
          try {
            final audioSource = LockCachingAudioSource(Uri.parse(url));
            await player.setAudioSource(audioSource);
          } catch (e) {
            debugPrint('>>> Error con LockCachingAudioSource (común en Motorola), usando fallback: $e');
            await player.setAudioSource(AudioSource.uri(Uri.parse(url)));
          }
        }
      }

      player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            _isLoadingAudio = state.processingState == ProcessingState.loading ||
                state.processingState == ProcessingState.buffering;
          });
        }
      });

      player.durationStream.listen((d) {
        if (mounted && d != null) {
          setState(() {
            _duration = d;
          });
        }
      });

      player.positionStream.listen((p) {
        if (mounted) {
          setState(() {
            _position = p;
          });
        }
      });


      setState(() {
        _isLoadingAudio = false;
      });

      await player.play();
    } catch (e) {
      debugPrint('>>> Error al inicializar audio: $e');
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cargar el audio: $e', style: GoogleFonts.nunito()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }


  Widget _buildDatabaseStatusWidget(String status, ThemeData theme, bool isDark) {
    IconData icon;
    Color color;
    String tooltip;

    if (status == 'Conectado') {
      icon = Icons.cloud_done_rounded;
      color = Colors.green;
      tooltip = 'Base de datos: Conectado (Online)';
    } else if (status.startsWith('Offline')) {
      icon = Icons.cloud_off_rounded;
      color = Colors.orange;
      tooltip = 'Base de datos: Offline / Modo Local\n${status.replaceAll('Offline: ', '')}';
    } else {
      icon = Icons.cloud_queue_rounded;
      color = Colors.grey;
      tooltip = 'Base de datos: Conectando...';
    }

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Icon(icon, color: color, size: 21),
      ),
    );
  }

  String _getTransposedTone(String originalTone, int semitones) {
    if (semitones == 0) return originalTone;
    final cleanTone = originalTone.replaceAll('TONO: ', '').trim();
    if (cleanTone.isEmpty) return originalTone;
    final transposed = Hymn.transposeChord(cleanTone, semitones);
    return 'TONO: $transposed';
  }

  Widget _buildViewToggle(String mode, String label, IconData icon, bool isDark, ThemeData theme) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? theme.colorScheme.onPrimary : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? theme.colorScheme.onPrimary : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHymnHeader(Hymn hymn, double fontSize, bool isDark, ThemeData theme, String displayedTone) {
    return Column(
      children: [
        // Alerta inteligente de duplicados / similitud
        Builder(
          builder: (context) {
            final adminMode = ref.watch(adminModeProvider);
            if (!adminMode) return const SizedBox.shrink();
            final allHymnsState = ref.watch(allHymnsGlobalProvider);
            final allHymns = allHymnsState.value ?? [];
            final ignoredPairsState = ref.watch(ignoredDuplicatePairsProvider);
            final ignoredPairsSet = ignoredPairsState.value ?? {};
            final similarHymn = _getSimilarHymnCached(hymn, allHymns, ignoredPairsSet);
            if (similarHymn == null) return const SizedBox.shrink();
            
            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: isDark ? 0.3 : 0.2),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '¡Canto similar detectado!',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.amber[200] : Colors.amber[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Este canto (de ${_getCollectionName(hymn.collection)}) es muy similar o idéntico a "${similarHymn.title}" en la sección "${_getCollectionName(similarHymn.collection)}" (ID: ${similarHymn.id}).',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.compare_rounded, size: 16),
                    label: Text(
                      'Comparar y Resolver',
                      style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _openComparisonView(context, hymn, similarHymn),
                  ),
                ],
              ),
            ).animate().shake(duration: 400.ms);
          },
        ),
        
        // Icono / Número Hero
        Hero(
          tag: 'hymn_icon_${hymn.collection}-${hymn.id}',
          child: hymn.collection == 'iump'
            ? Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.4 : 0.8),
                      theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.1 : 0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
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
                    fontSize: 22,
                  ),
                ),
              )
            : Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  hymn.collection == 'especiales' ? Icons.music_note_rounded : Icons.library_music_rounded, 
                  color: hymn.collection == 'especiales' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981), 
                  size: 32
                ),
              ),
        ),

        // Título Elegante
        Hero(
          tag: 'hymn-title-${hymn.collection}-${hymn.id}',
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              hymn.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: fontSize * 1.25,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : theme.colorScheme.primary,
                height: 1.25,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        
        if (hymn.audioUrl.isNotEmpty && _youtubeController != null && (hymn.audioUrl.contains('youtube.com') || hymn.audioUrl.contains('youtu.be')))
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: YoutubePlayer(
                controller: _youtubeController!,
              ),
            ),
          ),
        
        // Chip de Tono
        if (displayedTone.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isDark 
                ? Colors.white.withValues(alpha: 0.05) 
                : theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark 
                  ? Colors.white.withValues(alpha: 0.08) 
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              Hymn.formatToneDisplay(displayedTone, ref.watch(notationProvider)),
              style: GoogleFonts.outfit(
                fontSize: fontSize * 0.7,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF818CF8) : theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
          ).animate().fadeIn(delay: 150.ms).scale(),

        // Toggle Letra / Partitura
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewToggle('texto', 'Letra y Acordes', Icons.text_format_rounded, isDark, theme),
              _buildViewToggle('partitura', 'Partitura Oficial', Icons.library_music_rounded, isDark, theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHymnPage(BuildContext context, Hymn hymn, double fontSize, bool isDark, ThemeData theme) {
    final hasChords = hymn.lyrics.contains('[');
    final displayedTone = _getTransposedTone(hymn.tone, _transposeOffset);
    final header = _buildHymnHeader(hymn, fontSize, isDark, theme, displayedTone);

    return SizedBox.expand(
      child: SafeArea(
        bottom: false,
        child: _viewMode == 'texto'
            ? Scrollbar(
                controller: _scrollController,
                interactive: true,
                child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20.0, 
                  16.0, 
                  20.0, 
                  (hasChords ? 165.0 : 110.0) + MediaQuery.of(context).padding.bottom
                ),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      children: [
                        header,
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Divider(indent: 80, endIndent: 80, thickness: 1, color: Colors.black12),
                        ).animate().fadeIn(delay: 200.ms),
                        ..._getMergedBlocksCached(hymn.lyrics, _transposeOffset).map(
                          (block) => _buildLyricsBlock(context, hymn, block, fontSize, isDark, theme)
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          height: _showControlPanel ? (hasChords ? 240.0 : 140.0) : 0.0,
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              )
            : Padding(
                padding: EdgeInsets.fromLTRB(
                  20.0, 
                  16.0, 
                  20.0, 
                  MediaQuery.of(context).padding.bottom
                ),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      children: [
                        header,
                        const SizedBox(height: 16),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: isDark ? Colors.black26 : Colors.white70,
                              child: SheetMusicViewer(hymn: hymn, isEmbedded: true),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          height: _showControlPanel ? 140.0 : 0.0,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  int? _parseRomanNumeral(String input) {
    final clean = input.toUpperCase().trim();
    final RegExp romanRegExp = RegExp(r'^(XII|XI|X|IX|VIII|VII|VI|V|IV|III|II|I)$');
    if (!romanRegExp.hasMatch(clean)) return null;
    
    const map = {
      'I': 1,
      'II': 2,
      'III': 3,
      'IV': 4,
      'V': 5,
      'VI': 6,
      'VII': 7,
      'VIII': 8,
      'IX': 9,
      'X': 10,
      'XI': 11,
      'XII': 12,
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
          // Fusionar con el bloque anterior
          merged[merged.length - 1] = '$lastBlock\n\n$trimmedBlock';
        } else {
          merged.add(trimmedBlock);
        }
      }
    }
    return merged;
  }

  Widget _buildLyricsBlock(BuildContext context, Hymn hymn, String block, double fontSize, bool isDark, ThemeData theme) {
    final trimmed = block.trim();
    if (trimmed.isEmpty) return const SizedBox();

    final lines = trimmed.split('\n');
    final firstLine = lines.first.trim();

    final RegExp keywordRegExp = RegExp(
      r'^(coro\s+[ivx]+|coro\s+\d+|coro\s+final|coro|final|solista|puente|interludio)(?:\s*:\s*|\s+|$)', 
      caseSensitive: false
    );
    
    final match = keywordRegExp.firstMatch(firstLine);
    final isChorus = match != null;

    if (isChorus) {
      String keyword = match.group(1)!.toLowerCase();
      
      // Convertir coro con número romano (ej: "coro ii" -> "coro 2")
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
      
      final restOfLines = lines.skip(1).toList();
      final List<String> bodyLines = [];
      if (firstLineContent.isNotEmpty) {
        bodyLines.add(firstLineContent);
      }
      bodyLines.addAll(restOfLines);
      
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 14.0),
        decoration: BoxDecoration(
          color: isDark 
            ? const Color(0xFF6366F1).withValues(alpha: 0.04) 
            : theme.colorScheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  color: isDark ? const Color(0xFF6366F1) : theme.colorScheme.primary,
                ),
                Expanded(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF6366F1).withValues(alpha: 0.15) : theme.colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              headerText,
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF818CF8) : theme.colorScheme.primary,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (final line in bodyLines) ...[
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.end,
                                  children: _buildLineWithChords(Hymn.formatLineCasing(line), fontSize, isDark, theme, isItalic: true),
                                ),
                                if (line != bodyLines.last)
                                  SizedBox(height: _showChords && line.contains('[') ? 10 : 4),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04);
    } else {
      final lines = trimmed.split('\n');
      Widget verseWidget;
      String? parsedNumber;
      String firstLineRest = '';
      
      if (lines.isNotEmpty) {
        // 1. Intentar con número árabe (1, 2, 3...)
        final arabicMatch = RegExp(r'^(\d+)(?:\s*\.\s*|\s*\-\s*|\s+|$)(.*)').firstMatch(lines.first);
        if (arabicMatch != null) {
          parsedNumber = arabicMatch.group(1);
          firstLineRest = arabicMatch.group(2)?.trim() ?? '';
        } else {
          // 2. Intentar con número romano (I, II, III...)
          final romanMatch = RegExp(r'^([IVXivx]+)(\s*\.\s*|\s*\-\s*|\s+|$)(.*)').firstMatch(lines.first);
          if (romanMatch != null) {
            final romanStr = romanMatch.group(1)!;
            final converted = _parseRomanNumeral(romanStr);
            if (converted != null) {
              final separator = romanMatch.group(2) ?? '';
              final restText = romanMatch.group(3) ?? '';
              if (romanStr.toLowerCase() == 'vi' && !separator.contains('.') && !separator.contains('-') && restText.trim().isNotEmpty) {
                // Falso positivo: es la palabra "Vi" (del verbo ver), no el número romano VI.
              } else {
                parsedNumber = converted.toString();
                firstLineRest = restText.trim();
              }
            }
          }
        }
      }
      
      if (parsedNumber != null) {
        final rawRest = [firstLineRest, ...lines.skip(1)].join('\n').trim();
        final rest = rawRest.split('\n').map((l) => Hymn.formatLineCasing(l)).join('\n');
        
        verseWidget = Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  parsedNumber,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final line in rest.split('\n')) ...[
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: _buildLineWithChords(line, fontSize, isDark, theme),
                    ),
                    if (line != rest.split('\n').last)
                      SizedBox(height: _showChords && line.contains('[') ? 10 : 4),
                  ],
                ],
              ),
            ],
          ),
        );
      } else {
        final textToDisplay = trimmed.split('\n').map((l) => Hymn.formatLineCasing(l)).join('\n');
        verseWidget = Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final line in textToDisplay.split('\n')) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: _buildLineWithChords(line, fontSize, isDark, theme),
                ),
                if (line != textToDisplay.split('\n').last)
                  SizedBox(height: _showChords && line.contains('[') ? 10 : 4),
              ],
            ],
          ),
        );
      }
      
      return verseWidget.animate().fadeIn(duration: 250.ms).slideY(begin: 0.04);
    }
  }

  List<Widget> _buildLineWithChords(String line, double fontSize, bool isDark, ThemeData theme, {bool isItalic = false}) {
    final RegExp regExp = RegExp(r'\[([^\]]+)\]');

    // IMPORTANTE: materializar el iterable en una lista para evitar
    // que se re-evalúe el regex en cada acceso (.last, .indexOf, .elementAt)
    // causando comparaciones de identidad fallidas y RangeError.
    final matchesList = regExp.allMatches(line).toList();

    if (matchesList.isEmpty || !_showChords) {
      final cleanLine = line.replaceAll(RegExp(r'\[[^\]]+\]'), '');
      return [
        Text(
          cleanLine,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            color: isDark ? Colors.white.withValues(alpha: 0.85) : theme.colorScheme.onSurface,
            height: 1.5,
          ),
        )
      ];
    }

    final List<Widget> inlineWidgets = [];
    int lastMatchEnd = 0;

    for (int i = 0; i < matchesList.length; i++) {
      final match = matchesList[i];

      // 1. Texto plano antes del acorde
      if (match.start > lastMatchEnd) {
        final textBefore = line.substring(lastMatchEnd, match.start);
        if (textBefore.isNotEmpty) {
          inlineWidgets.add(
            Text(
              textBefore,
              style: GoogleFonts.nunito(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                color: isDark ? Colors.white.withValues(alpha: 0.85) : theme.colorScheme.onSurface,
              ),
            ),
          );
        }
      }

      // 2. Acorde + texto que va directamente debajo de él
      final rawChord = match.group(1)!;
      final transposedChord = ChordTransposerService.transposeSingleChord(rawChord, _transposeOffset);
      final displayedChord = Hymn.convertChordNotation(transposedChord, ref.watch(notationProvider));

      // Fin del texto bajo este acorde: inicio del siguiente acorde (o fin de línea)
      final nextMatchStart = (i == matchesList.length - 1)
          ? line.length
          : matchesList[i + 1].start;

      final textUnder = line.substring(match.end, nextMatchStart);
      final chordFontSize = fontSize * 0.65;
      final minChordWidth = displayedChord.length * (chordFontSize * 0.58);

      inlineWidgets.add(
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: minChordWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => ChordDiagramDialog.show(context, displayedChord),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  child: Text(
                    displayedChord,
                    style: GoogleFonts.outfit(
                      fontSize: chordFontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber[600],
                    ),
                  ),
                ),
              ),
              Text(
                textUnder.isEmpty ? ' ' : textUnder,
                style: GoogleFonts.nunito(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                  color: isDark ? Colors.white.withValues(alpha: 0.85) : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );

      lastMatchEnd = nextMatchStart;
    }

    return inlineWidgets;
  }

  Widget _buildNotationPill(String notationType, String label, ThemeData theme, bool isDark) {
    final currentNotation = ref.watch(notationProvider);
    final isSelected = currentNotation == notationType;
    return GestureDetector(
      onTap: () {
        ref.read(notationProvider.notifier).setNotation(notationType);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
            ? theme.colorScheme.primary 
            : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected 
              ? Colors.white 
              : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  void _showEditHymnDialog(BuildContext context, WidgetRef ref, Hymn hymn) {
    final titleController = TextEditingController(text: hymn.title);
    final parsedTone = Hymn.parseToneComponents(hymn.tone);
    String rawToneNote = hymn.toneNote.isNotEmpty ? hymn.toneNote : (parsedTone['toneNote'] ?? '');
    
    bool isInitialMinor = rawToneNote.endsWith('m') ||
        rawToneNote.toLowerCase().contains('menor') ||
        rawToneNote.endsWith('M');
    String selectedMode = isInitialMinor ? 'Menor' : 'Mayor';

    String cleanRootNote = rawToneNote;
    if (cleanRootNote.endsWith('m') && cleanRootNote.length > 1) {
      cleanRootNote = cleanRootNote.substring(0, cleanRootNote.length - 1);
    } else if (cleanRootNote.toLowerCase().endsWith('menor')) {
      cleanRootNote = cleanRootNote.replaceAll(RegExp(r'menor', caseSensitive: false), '').trim();
    }
    final toneNoteController = TextEditingController(text: cleanRootNote);
    final beatsController = TextEditingController(
      text: hymn.beats.isNotEmpty ? hymn.beats : parsedTone['beats'],
    );
    final timeSignatureController = TextEditingController(
      text: hymn.timeSignature.isNotEmpty ? hymn.timeSignature : parsedTone['timeSignature'],
    );
    final lyricsController = TextEditingController(text: hymn.lyrics);
    final audioUrlController = TextEditingController(text: hymn.audioUrl);
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Saneamos la colección seleccionada para que sea una de las tres principales del dropdown,
    // previniendo aserciones de Flutter al construir el DropdownButtonFormField y bloqueos de interfaz.
    final validCollections = const ['iump', 'especiales', 'coros'];
    String selectedCollection = validCollections.contains(hymn.collection)
        ? hymn.collection
        : 'iump';
    String selectedCategory = hymn.category;

    // Variables de estado locales para la subida y grabación de audio
    bool isUploading = false;
    double uploadProgress = 0.0;
    String uploadStatusText = '';

    bool isRecording = false;
    int recordingSeconds = 0;
    AudioRecorder? recorder;
    Timer? recordingTimer;

    Future<void> pickAndUploadAudio(void Function(void Function()) dialogSetState) async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
        );
        if (result == null || result.files.isEmpty) return;

        final file = result.files.first;
        final fileSizeMB = file.size / (1024 * 1024);

        if (fileSizeMB > 10.0) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Archivo pesado'),
              content: Text(
                'El archivo seleccionado mide ${fileSizeMB.toStringAsFixed(1)} MB, lo cual supera el límite recomendado de 10 MB.\n\n¿Deseas subirlo de todas formas?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Subir de todas formas'),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }

        dialogSetState(() {
          isUploading = true;
          uploadProgress = 0.0;
          uploadStatusText = 'Preparando subida...';
        });

        File fileToUpload = File(file.path!);
        String ext = file.extension ?? 'mp3';

        dialogSetState(() {
          uploadStatusText = 'Subiendo a la nube...';
        });

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('audios/canto_${hymn.collection}_${hymn.id}.$ext');

        UploadTask uploadTask;
        if (kIsWeb) {
          if (file.bytes == null) {
            throw Exception('No se pudieron leer los bytes del archivo en web.');
          }
          uploadTask = storageRef.putData(
            file.bytes!,
            SettableMetadata(contentType: 'audio/mpeg'),
          );
        } else {
          if (file.path == null) {
            throw Exception('Ruta de archivo no válida.');
          }
          uploadTask = storageRef.putFile(
            fileToUpload,
            SettableMetadata(contentType: ext == 'm4a' ? 'audio/mp4' : 'audio/mpeg'),
          );
        }

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          dialogSetState(() {
            uploadProgress = progress.isNaN || progress.isInfinite ? 0.0 : progress;
            uploadStatusText = 'Subiendo: ${(uploadProgress * 100).toInt()}%';
          });
        }, onError: (e) {
          debugPrint('>>> Error en flujo de subida: $e');
        });

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        dialogSetState(() {
          isUploading = false;
          audioUrlController.text = downloadUrl;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio subido con éxito.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        dialogSetState(() {
          isUploading = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir archivo: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }

    Future<void> processYoutubeUrl(void Function(void Function()) dialogSetState) async {
      final inputUrl = audioUrlController.text.trim();
      if (inputUrl.isEmpty || (!inputUrl.contains('youtube.com') && !inputUrl.contains('youtu.be'))) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ingresa una URL válida de YouTube.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      dialogSetState(() {
        audioUrlController.text = inputUrl;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎵 Enlace de YouTube guardado. Cierra y vuelve a abrir el himno para ver el reproductor.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }

    Future<void> startRecording(void Function(void Function()) dialogSetState) async {
      try {
        final hasPermission = await Permission.microphone.request().isGranted;
        if (!hasPermission) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permiso de micrófono denegado.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        recorder = AudioRecorder();
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/canto_${hymn.collection}_${hymn.id}.m4a';

        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        );

        await recorder!.start(config, path: path);

        dialogSetState(() {
          isRecording = true;
          recordingSeconds = 0;
        });

        recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          dialogSetState(() {
            recordingSeconds++;
          });
        });
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al iniciar grabación: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }

    Future<void> stopAndUploadRecording(void Function(void Function()) dialogSetState) async {
      try {
        recordingTimer?.cancel();
        final path = await recorder?.stop();
        await recorder?.dispose();
        recorder = null;

        dialogSetState(() {
          isRecording = false;
        });

        if (path == null) {
          throw Exception('No se generó el archivo de grabación.');
        }

        dialogSetState(() {
          isUploading = true;
          uploadProgress = 0.0;
          uploadStatusText = 'Subiendo grabación...';
        });

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('audios/canto_${hymn.collection}_${hymn.id}.m4a');

        final uploadTask = storageRef.putFile(
          File(path),
          SettableMetadata(contentType: 'audio/mpeg'),
        );

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          dialogSetState(() {
            uploadProgress = progress.isNaN || progress.isInfinite ? 0.0 : progress;
            uploadStatusText = 'Subiendo: ${(uploadProgress * 100).toInt()}%';
          });
        });

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        dialogSetState(() {
          isUploading = false;
          audioUrlController.text = downloadUrl;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grabación subida con éxito.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        dialogSetState(() {
          isUploading = false;
          isRecording = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir grabación: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }

    Future<void> deleteAudioFile(void Function(void Function()) dialogSetState) async {
      final url = audioUrlController.text.trim();
      if (url.isEmpty) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Eliminar audio?'),
          content: const Text(
            'Se eliminará de forma permanente el archivo de audio físico almacenado en la nube. Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      dialogSetState(() {
        isUploading = true;
        uploadStatusText = 'Eliminando archivo...';
      });

      try {
        if (url.contains('firebasestorage.googleapis.com')) {
          final storageRef = FirebaseStorage.instance.refFromURL(url);
          await storageRef.delete();
        }

        dialogSetState(() {
          isUploading = false;
          audioUrlController.text = '';
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio eliminado de la nube con éxito.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        dialogSetState(() {
          isUploading = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar archivo: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Editar Himno ${hymn.id}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mejorar Ortografía y Puntuación con IA',
                    icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                    onPressed: () async {
                      if (lyricsController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ingresa la letra antes de pulir con IA')),
                        );
                        return;
                      }
                      final result = await GeminiAiService.correctHymnGrammar(
                        context: context,
                        title: titleController.text.trim(),
                        lyrics: lyricsController.text.trim(),
                      );
                      if (result != null) {
                        titleController.text = result['title']!;
                        lyricsController.text = result['lyrics']!;
                      }
                    },
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Título'),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Requerido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: toneNoteController,
                              decoration: const InputDecoration(
                                labelText: 'Tono (ej: RE, D)',
                                isDense: true,
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: selectedMode,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Modo',
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Mayor', child: Text('Mayor (M)')),
                                DropdownMenuItem(value: 'Menor', child: Text('Menor (m)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    selectedMode = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: beatsController,
                              decoration: const InputDecoration(
                                labelText: 'Tiempos (ej: 3)',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: timeSignatureController,
                              decoration: const InputDecoration(
                                labelText: 'Métrica (ej: 4/4)',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: selectedCollection,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Sección',
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'iump', child: Text('Himnario IUMP', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'especiales', child: Text('Alabanzas Esp.', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'coros', child: Text('Coros Avivamiento', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    selectedCollection = val;
                                    selectedCategory = '';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: _getValidCategoryValueForEdit(selectedCollection, selectedCategory),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Categoría',
                                isDense: true,
                              ),
                              items: _getCategoryDropdownItemsForEdit(selectedCollection),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    selectedCategory = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: audioUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL del Audio (Enlace Firebase Storage / MP3)',
                          prefixIcon: Icon(Icons.music_video_rounded),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 8),

                      // Panel de subida en curso
                      if (isUploading)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                uploadStatusText,
                                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              if (uploadProgress > 0)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: uploadProgress,
                                    minHeight: 6,
                                  ),
                                )
                              else
                                const SizedBox(
                                  height: 6,
                                  child: LinearProgressIndicator(),
                                ),
                            ],
                          ),
                        ),

                      // Panel de grabación activa
                      if (isRecording)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16)
                                      .animate(onPlay: (controller) => controller.repeat())
                                      .fadeIn(duration: 500.ms)
                                      .fadeOut(duration: 500.ms),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Grabando: ${_formatDuration(Duration(seconds: recordingSeconds))}',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.stop, size: 16),
                                label: const Text('Detener y subir', style: TextStyle(fontSize: 12)),
                                onPressed: isUploading ? null : () => stopAndUploadRecording(setState),
                              ),
                            ],
                          ),
                        ),

                      if (!isUploading && !isRecording)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.file_upload_outlined, size: 18),
                                label: Text('Subir Archivo', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => pickAndUploadAudio(setState),
                              ),
                              if (!kIsWeb)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                    foregroundColor: Colors.amber[900],
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.mic_none_rounded, size: 18),
                                  label: Text('Grabar Audio', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () => startRecording(setState),
                                ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                                  foregroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.cloud_download_rounded, size: 18),
                                label: Text('Extraer YouTube', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => processYoutubeUrl(setState),
                              ),
                              if (audioUrlController.text.isNotEmpty)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                    foregroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                  label: Text('Eliminar', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () => deleteAudioFile(setState),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 12),
                      // Encabezado Asistente de Acordes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.piano_rounded, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Asistente de Acordes:',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            icon: const Icon(Icons.cleaning_services_rounded, size: 15),
                            label: Text(
                              'Borrar acordes',
                              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              lyricsController.text = lyricsController.text.replaceAll(RegExp(r'\[[^\]]*\]'), '');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Se limpiaron todos los acordes del canto', style: GoogleFonts.nunito()),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Botón Constructor de Acordes Compuestos
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '🎼 Constructor de Acordes (Compuestos, Séptimas, Slash)',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          onPressed: () {
                            _showInteractiveChordBuilderModal(context, lyricsController, theme, isDark);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Paleta Rápida de Acordes de Alabanza (1-Tap direct insert)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            for (final chord in [
                              'MIm', 'LAm', 'REm', 'SIm', 'SOL', 'DO', 'RE', 'FA', 'LA', 'MI',
                              'DO7', 'SOL7', 'FA#m', 'SI7', 'SIb', 'DOmaj7', 'SOL#m'
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () {
                                    final text = lyricsController.text;
                                    final selection = lyricsController.selection;
                                    final chordTag = '[$chord]';
                                    final start = selection.start;
                                    final end = selection.end;

                                    if (start < 0) {
                                      lyricsController.text = '$text$chordTag';
                                      lyricsController.selection = TextSelection.collapsed(offset: lyricsController.text.length);
                                    } else {
                                      final newText = text.replaceRange(start, end, chordTag);
                                      lyricsController.text = newText;
                                      lyricsController.selection = TextSelection.collapsed(offset: start + chordTag.length);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      chord,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: lyricsController,
                        decoration: const InputDecoration(
                          labelText: 'Letra',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 12,
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
                  onPressed: () {
                    recordingTimer?.cancel();
                    recorder?.dispose();
                    Navigator.pop(context);
                  },
                  child: Text('Cancelar', style: GoogleFonts.nunito()),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (isUploading || isRecording) ? null : () async {
                    if (formKey.currentState!.validate()) {
                      await LocalHymnStorageService.saveLocalHymnEdit(
                        hymn.collection,
                        hymn.id,
                        lyricsController.text.trim(),
                      );

                      String finalToneNote = toneNoteController.text.trim();
                      if (finalToneNote.isNotEmpty) {
                        String rootNote = finalToneNote.toUpperCase();
                        if (rootNote.endsWith('M')) {
                          rootNote = rootNote.substring(0, rootNote.length - 1);
                        }
                        if (selectedMode == 'Menor') {
                          finalToneNote = '${rootNote}m';
                        } else {
                          finalToneNote = rootNote;
                        }
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      final isMoving = selectedCollection != hymn.collection;

                      Navigator.pop(context); // Cerrar diálogo de inmediato
                      if (isMoving) {
                        Navigator.pop(context); // Salir de la pantalla de detalle ya que se trasladó
                      }

                      // Ejecutar la actualización en Riverpod después de que la navegación se complete
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (isMoving) {
                          ref.read(hymnsProvider(hymn.collection).notifier).moveHymnTo(
                            hymn.copyWith(
                              title: titleController.text.trim(),
                              toneNote: finalToneNote,
                              beats: beatsController.text.trim(),
                              timeSignature: timeSignatureController.text.trim(),
                              lyrics: lyricsController.text.trim(),
                              audioUrl: audioUrlController.text.trim(),
                              category: selectedCategory,
                            ),
                            selectedCollection,
                          );
                        } else {
                          ref.read(hymnsProvider(hymn.collection).notifier).saveHymn(
                            id: hymn.id,
                            title: titleController.text.trim(),
                            toneNote: finalToneNote,
                            beats: beatsController.text.trim(),
                            timeSignature: timeSignatureController.text.trim(),
                            lyrics: lyricsController.text.trim(),
                            isNew: false,
                            audioUrl: audioUrlController.text.trim(),
                            category: selectedCategory,
                          );
                        }

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Himno guardado con éxito', style: GoogleFonts.nunito()),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      });
                    }
                  },
                  child: Text('Guardar', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                ),
              ],

            );
          },
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _getCategoryDropdownItemsForEdit(String collection) {
    final List<Map<String, String>> categories;
    if (collection == 'especiales') {
      categories = [
        {'id': '', 'name': 'Sin Categoría / Ninguna'},
        {'id': 'Coro Nacional', 'name': 'Coro Nacional'},
        {'id': 'Coros Unidos', 'name': 'Coros Unidos'},
      ];
    } else if (collection == 'coros') {
      categories = [
        {'id': '', 'name': 'Sin Categoría / Ninguna'},
        {'id': 'Con Acordes', 'name': 'Con Acordes'},
        {'id': 'DO', 'name': 'Tono DO'},
        {'id': 'RE', 'name': 'Tono RE'},
        {'id': 'MI', 'name': 'Tono MI'},
        {'id': 'FA', 'name': 'Tono FA'},
        {'id': 'SOL', 'name': 'Tono SOL'},
        {'id': 'LA', 'name': 'Tono LA'},
        {'id': 'SI', 'name': 'Tono SI'},
        {'id': 'Menores', 'name': 'Ritmo Menor'},
      ];
    } else {
      categories = [
        {'id': '', 'name': 'Sin Categoría / Ninguna'},
        {'id': 'Predicación', 'name': 'Predicación'},
        {'id': 'Adoración', 'name': 'Adoración'},
        {'id': 'Consagración', 'name': 'Consagración'},
        {'id': 'Santa Cena', 'name': 'Santa Cena'},
        {'id': 'Coritos', 'name': 'Coritos'},
        {'id': 'Fúnebre', 'name': 'Fúnebre'},
        {'id': 'Navidad', 'name': 'Navidad'},
      ];
    }

    return categories.map((cat) {
      return DropdownMenuItem<String>(
        value: cat['id']!,
        child: Text(cat['name']!, overflow: TextOverflow.ellipsis),
      );
    }).toList();
  }

  String _getValidCategoryValueForEdit(String collection, String category) {
    final items = _getCategoryDropdownItemsForEdit(collection);
    if (items.any((item) => item.value == category)) {
      return category;
    }
    return '';
  }

  void _showInteractiveChordBuilderModal(
    BuildContext context,
    TextEditingController lyricsController,
    ThemeData theme,
    bool isDark,
  ) {
    String selectedRoot = 'DO';
    String selectedAccidental = '';
    String selectedQuality = '';
    String selectedSlash = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final rawChord = '$selectedRoot$selectedAccidental$selectedQuality$selectedSlash';
            final chordTag = '[$rawChord]';
            final bottomPadding = 20.0 + MediaQuery.of(context).padding.bottom;

            return SafeArea(
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Constructor Interactivo de Acordes',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Badge de Vista Previa
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: Text(
                          chordTag,
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber[800],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Tónica (Nota)
                    Text('1. Nota Tónica:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ['DO', 'RE', 'MI', 'FA', 'SOL', 'LA', 'SI'].map((root) {
                        final isSel = selectedRoot == root;
                        return ChoiceChip(
                          label: Text(root),
                          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          selected: isSel,
                          selectedColor: theme.colorScheme.primary,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedRoot = root);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 2. Alteración
                    Text('2. Alteración:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        {'label': 'Natural ♮', 'val': ''},
                        {'label': 'Sostenido ♯ (#)', 'val': '#'},
                        {'label': 'Bemol ♭ (b)', 'val': 'b'},
                      ].map((alt) {
                        final isSel = selectedAccidental == alt['val'];
                        return ChoiceChip(
                          label: Text(alt['label']!),
                          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                          selected: isSel,
                          selectedColor: Colors.amber[700],
                          onSelected: (val) {
                            if (val) setModalState(() => selectedAccidental = alt['val']!);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 3. Calidad / Modo
                    Text('3. Tipo / Calidad del Acorde:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        {'label': 'Mayor', 'val': ''},
                        {'label': 'Menor (m)', 'val': 'm'},
                        {'label': 'Séptima (7)', 'val': '7'},
                        {'label': 'Menor 7 (m7)', 'val': 'm7'},
                        {'label': 'Mayor 7 (maj7)', 'val': 'maj7'},
                        {'label': 'Disminuido (dim)', 'val': 'dim'},
                        {'label': 'Suspendido (sus4)', 'val': 'sus4'},
                        {'label': 'Novena (9)', 'val': '9'},
                        {'label': 'Add9', 'val': 'add9'},
                        {'label': 'm7(b5)', 'val': 'm7(b5)'},
                        {'label': 'Menor 6 (m6)', 'val': 'm6'},
                      ].map((qual) {
                        final isSel = selectedQuality == qual['val'];
                        return ChoiceChip(
                          label: Text(qual['label']!),
                          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11.5),
                          selected: isSel,
                          selectedColor: theme.colorScheme.secondary,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedQuality = qual['val']!);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 4. Bajo Alternativo (Slash Chord)
                    Text('4. Bajo Alternativo (Slash Chord /):', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ['', '/DO', '/RE', '/MI', '/FA', '/SOL', '/LA', '/SI', '/DO#', '/FA#', '/SOL#'].map((b) {
                        final isSel = selectedSlash == b;
                        return ChoiceChip(
                          label: Text(b.isEmpty ? 'Sin Bajo' : b),
                          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11.5),
                          selected: isSel,
                          selectedColor: Colors.teal,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedSlash = b);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Botón Insertar con Posicionamiento Automático del Cursor
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: Text(
                          'Insertar $chordTag en Cursor',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onPressed: () {
                          final text = lyricsController.text;
                          final selection = lyricsController.selection;
                          final start = selection.start;
                          final end = selection.end;

                          if (start < 0) {
                            lyricsController.text = '$text$chordTag';
                            lyricsController.selection = TextSelection.collapsed(offset: lyricsController.text.length);
                          } else {
                            final newText = text.replaceRange(start, end, chordTag);
                            lyricsController.text = newText;
                            lyricsController.selection = TextSelection.collapsed(offset: start + chordTag.length);
                          }

                          Navigator.pop(context);
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

  void _confirmDeleteHymn(BuildContext context, WidgetRef ref, Hymn hymn) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Eliminar Himno',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar "${hymn.title}"? Esta acción no se puede deshacer.',
            style: GoogleFonts.nunito(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.nunito()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await ref.read(hymnsProvider(hymn.collection).notifier).deleteHymn(hymn.id);
                if (!context.mounted) return;
                Navigator.pop(context); // Cerrar diálogo
                Navigator.pop(context); // Volver a la lista
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Himno eliminado con éxito', style: GoogleFonts.nunito()),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: Text('Eliminar', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchYouTubeSearch(String title) async {
    final query = Uri.encodeComponent('Iglesia Unida Metodista Pentecostal $title');
    final url = Uri.parse('https://www.youtube.com/results?search_query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir YouTube', style: GoogleFonts.nunito()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Hymn? _findSimilarHymn(Hymn current, List<Hymn> allHymns, {Set<String>? ignoredPairs}) {
    final key1 = '${current.collection}-${current.id}';
    for (final other in allHymns) {
      if (other.collection == current.collection && other.id == current.id) {
        continue;
      }
      final key2 = '${other.collection}-${other.id}';
      if (ignoredPairs != null && (ignoredPairs.contains('${key1}_${key2}') || ignoredPairs.contains('${key2}_${key1}'))) {
        continue;
      }

      // Pre-filtrado rápido por diferencia de longitud
      final len1 = current.lyrics.length;
      final len2 = other.lyrics.length;
      final maxLen = len1 > len2 ? len1 : len2;
      final minLen = len1 < len2 ? len1 : len2;
      if (minLen < maxLen * 0.65) {
        // Si las longitudes de las letras difieren en más del 35%, no pueden ser 80% similares,
        // pero aún así comprobamos si sus títulos coinciden exactamente
        final normalizedTitle1 = _normalizeTitle(current.title);
        final normalizedTitle2 = _normalizeTitle(other.title);
        if (normalizedTitle1.length > 3 && normalizedTitle1 == normalizedTitle2) {
          return other;
        }
        continue;
      }
      
      final similarity = _calculateLyricsSimilarity(current.lyrics, other.lyrics);
      if (similarity >= 0.8) {
        return other;
      }
      
      final normalizedTitle1 = _normalizeTitle(current.title);
      final normalizedTitle2 = _normalizeTitle(other.title);
      if (normalizedTitle1.length > 3 && normalizedTitle1 == normalizedTitle2) {
        return other;
      }
    }
    return null;
  }
  
  double _calculateLyricsSimilarity(String lyrics1, String lyrics2) {
    final clean1 = lyrics1.replaceAll(RegExp(r'\[[^\]]*\]'), '').toLowerCase().replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑ0-9]'), '');
    final clean2 = lyrics2.replaceAll(RegExp(r'\[[^\]]*\]'), '').toLowerCase().replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑ0-9]'), '');
    
    if (clean1 == clean2) return 1.0;
    if (clean1.isEmpty || clean2.isEmpty) return 0.0;
    
    final bigrams1 = _getBigrams(clean1);
    final bigrams2 = _getBigrams(clean2);
    
    if (bigrams1.isEmpty || bigrams2.isEmpty) return 0.0;
    
    int intersection = 0;
    final list2 = List<String>.from(bigrams2);
    for (final b1 in bigrams1) {
      final idx = list2.indexOf(b1);
      if (idx != -1) {
        intersection++;
        list2.removeAt(idx);
      }
    }
    
    return (2.0 * intersection) / (bigrams1.length + bigrams2.length);
  }
  
  List<String> _getBigrams(String str) {
    final bigrams = <String>[];
    for (int i = 0; i < str.length - 1; i++) {
      bigrams.add(str.substring(i, i + 2));
    }
    return bigrams;
  }

  String _normalizeTitle(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }

  String _getCollectionName(String collection) {
    switch (collection) {
      case 'iump':
        return 'Himnario IUMP';
      case 'especiales':
        return 'Alabanzas Especiales';
      case 'coros':
        return 'Coros de Avivamiento';
      default:
        return collection;
    }
  }

  void _openComparisonView(BuildContext context, Hymn hymn1, Hymn hymn2) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final theme = Theme.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Comparador Inteligente de Cantos',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (layoutContext, constraints) {
                final isWide = constraints.maxWidth > 700;
                
                final songView1 = _buildComparisonCard(dialogContext, hymn1, hymn2.lyrics, isDark, theme, isWide);
                final songView2 = _buildComparisonCard(dialogContext, hymn2, hymn1.lyrics, isDark, theme, isWide);
                
                return Column(
                  children: [
                    Expanded(
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: songView1),
                                const VerticalDivider(width: 1),
                                Expanded(child: songView2),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(child: songView1),
                                const Divider(height: 1, thickness: 1),
                                Expanded(child: songView2),
                              ],
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '¿Cómo deseas resolver este duplicado/similitud?',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _resolveDuplicate(dialogContext, ref, keep: hymn2, delete: hymn1),
                                child: Text('Conservar en ${_getCollectionName(hymn2.collection)} (Eliminar ${_getCollectionName(hymn1.collection)})'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _resolveDuplicate(dialogContext, ref, keep: hymn1, delete: hymn2),
                                child: Text('Conservar en ${_getCollectionName(hymn1.collection)} (Eliminar ${_getCollectionName(hymn2.collection)})'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                ),
                                onPressed: () => _ignoreDuplicatePair(dialogContext, ref, hymn1, hymn2),
                                child: const Text('Conservar ambos (No son duplicados)'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildComparisonCard(BuildContext context, Hymn hymn, String otherLyrics, bool isDark, ThemeData theme, bool isWide) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'ORIGEN: ${_getCollectionName(hymn.collection)}'.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${hymn.title} (ID: ${hymn.id})',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (hymn.tone.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Tono: ${hymn.tone}',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _buildHighlightedLyrics(hymn.lyrics, otherLyrics, isDark, theme),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      child: body,
    );
  }

  Widget _buildHighlightedLyrics(String lyrics, String otherLyrics, bool isDark, ThemeData theme) {
    final otherLinesNormalized = otherLyrics
        .split('\n')
        .map((l) => l.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim())
        .where((l) => l.length > 5)
        .toSet();

    final lines = lyrics.split('\n');
    final List<TextSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final normLine = line.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
      final isSimilar = normLine.length > 5 && otherLinesNormalized.contains(normLine);
      
      spans.add(
        TextSpan(
          text: line + (i < lines.length - 1 ? '\n' : ''),
          style: GoogleFonts.nunito(
            fontSize: 14,
            height: 1.5,
            fontWeight: isSimilar ? FontWeight.bold : FontWeight.normal,
            color: isSimilar 
              ? (isDark ? Colors.redAccent[100] : Colors.red[700]) 
              : (isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87),
            backgroundColor: isSimilar 
              ? (isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.05))
              : null,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Future<void> _ignoreDuplicatePair(BuildContext context, WidgetRef ref, Hymn h1, Hymn h2) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> ignoredPairs = prefs.getStringList('ignored_duplicate_pairs') ?? [];
    
    final pair1 = '${h1.collection}-${h1.id}_${h2.collection}-${h2.id}';
    final pair2 = '${h2.collection}-${h2.id}_${h1.collection}-${h1.id}';
    
    if (!ignoredPairs.contains(pair1)) ignoredPairs.add(pair1);
    if (!ignoredPairs.contains(pair2)) ignoredPairs.add(pair2);
    
    await prefs.setStringList('ignored_duplicate_pairs', ignoredPairs);
    
    _similarityCache.clear();
    ref.invalidate(allHymnsGlobalProvider);
    ref.invalidate(duplicateHymnsKeysProvider);
    ref.invalidate(ignoredDuplicatePairsProvider);
    
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se conservarán ambos cantos y no se volverán a mostrar como duplicados.', style: GoogleFonts.nunito()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _resolveDuplicate(
    BuildContext context, 
    WidgetRef ref, {
    required Hymn keep, 
    required Hymn delete,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '¿Confirmar eliminación?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar la alabanza "${delete.title}" de la sección "${_getCollectionName(delete.collection)}"? Esta acción no se puede deshacer y conservará únicamente la versión en "${_getCollectionName(keep.collection)}".',
            style: GoogleFonts.nunito(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        );
      },
    );
    
    if (confirm != true) return;
    
    try {
      await ref.read(hymnsProvider(delete.collection).notifier).deleteHymn(delete.id);
      
      _similarityCache.clear();
      ref.invalidate(allHymnsGlobalProvider);
      ref.invalidate(duplicateHymnsKeysProvider);
      ref.invalidate(ignoredDuplicatePairsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se eliminó "${delete.title}" correctamente.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
        
        final parts = widget.hymnId.split('-');
        final currentCollection = parts.length > 1 ? parts[0] : 'iump';
        final idString = parts.length > 1 ? parts.sublist(1).join('-') : widget.hymnId;
        final currentId = int.tryParse(idString) ?? 0;
        
        if (delete.collection == currentCollection && delete.id == currentId) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _showConnectToTvDialog(BuildContext context, Hymn hymn) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCode = prefs.getString('last_tv_room');
    final codeController = TextEditingController(text: lastCode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conectar a Smart TV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa el código de 4 dígitos que aparece en la pantalla del TV/Proyector (himnario-vito-2026.web.app/tv):'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '1234',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim();
              if (code.length == 4) {
                // Check if the room exists before saving it
                FirebaseFirestore.instance.collection('tv_rooms').doc(code).get().then((doc) async {
                  if (doc.exists) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('last_tv_room', code);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      GoRouter.of(context).push('/remote', extra: {'hymn': hymn, 'roomId': code});
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('La sala no existe o está inactiva.')),
                      );
                    }
                  }
                });
              }
            },
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
  }

  void _showExportPdfModal(BuildContext context, Hymn hymn) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF4F46E5), size: 26),
                  const SizedBox(width: 8),
                  Text(
                    'Compartir Canto en PDF',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${hymn.title} · Membrete Oficial IUMP',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEF2FF),
                  child: Icon(Icons.music_note_rounded, color: Color(0xFF4F46E5)),
                ),
                title: Text('PDF Completo (Letra y Acordes)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _transposeOffset != 0
                      ? 'Incluye acordes transponidos ($_transposeOffset semitono/s)'
                      : 'Incluye tonalidad, métrica y cifrado completo',
                  style: GoogleFonts.outfit(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  ctx.pop();
                  await HymnPdfService.shareHymnPdf(
                    hymn,
                    transposeOffset: _transposeOffset,
                    includeChords: true,
                    notation: ref.read(notationProvider),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF0FDF4),
                  child: Icon(Icons.description_rounded, color: Color(0xFF16A34A)),
                ),
                title: Text('PDF Solo Letra (Sin Acordes)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                subtitle: Text('Ideal para la congregación o imprimir folletos', style: GoogleFonts.outfit(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  ctx.pop();
                  await HymnPdfService.shareHymnPdf(
                    hymn,
                    transposeOffset: _transposeOffset,
                    includeChords: false,
                    notation: ref.read(notationProvider),
                  );
                },
              ),
              const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateSetlistDialog(BuildContext context, WidgetRef ref, String hymnKey) {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nuevo Repertorio', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                await ref.read(setlistsProvider.notifier).addSetlist(title, date, [hymnKey]);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Repertorio creado y canto agregado')),
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

  void _showAddToSetlistDialog(BuildContext context, WidgetRef ref, Hymn hymn) {
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
              padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + MediaQuery.of(ctx).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.playlist_add_rounded, color: Color(0xFF4F46E5), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Agregar a Repertorio',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selecciona la lista de culto donde deseas incluir "${hymn.title}":',
                    style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  if (setlists.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text(
                          'Aún no tienes listas de repertorios creadas.',
                          style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey),
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
                                color: isInSetlist ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isInSetlist ? Icons.check_circle_rounded : Icons.queue_music_rounded,
                                color: isInSetlist ? const Color(0xFF4F46E5) : Colors.grey[600],
                                size: 20,
                              ),
                            ),
                            title: Text(
                              setlist.title,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${setlist.hymnIds.length} cantos • ${setlist.date}',
                              style: GoogleFonts.nunito(fontSize: 12),
                            ),
                            trailing: isInSetlist
                                ? TextButton(
                                    onPressed: () async {
                                      final updatedIds = List<String>.from(setlist.hymnIds)..remove(key);
                                      final updatedSetlist = setlist.copyWith(hymnIds: updatedIds);
                                      await ref.read(setlistsProvider.notifier).updateSetlist(updatedSetlist);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Removido de "${setlist.title}"'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Quitar', style: TextStyle(color: Colors.redAccent)),
                                  )
                                : ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Agregar'),
                                    onPressed: () async {
                                      final updatedIds = List<String>.from(setlist.hymnIds)..add(key);
                                      final updatedSetlist = setlist.copyWith(hymnIds: updatedIds);
                                      await ref.read(setlistsProvider.notifier).updateSetlist(updatedSetlist);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Agregado a "${setlist.title}"'),
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
                      child: const Icon(Icons.add_rounded, color: Color(0xFF4F46E5)),
                    ),
                    title: Text('Crear Nuevo Repertorio', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5))),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreateSetlistDialog(context, ref, key);
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
          error: (err, _) => SizedBox(height: 150, child: Center(child: Text('Error: $err'))),
        );
      },
    );
  }
}

class AutoScrollingAppBarTitle extends StatefulWidget {
  final String badgeText;
  final String titleText;
  final Color primaryColor;

  const AutoScrollingAppBarTitle({
    super.key,
    required this.badgeText,
    required this.titleText,
    required this.primaryColor,
  });

  @override
  State<AutoScrollingAppBarTitle> createState() => _AutoScrollingAppBarTitleState();
}

class _AutoScrollingAppBarTitleState extends State<AutoScrollingAppBarTitle> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMarqueeLoop();
    });
  }

  @override
  void didUpdateWidget(covariant AutoScrollingAppBarTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.titleText != widget.titleText) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMarqueeLoop();
      });
    }
  }

  void _startMarqueeLoop() async {
    if (_isScrolling || !mounted) return;
    _isScrolling = true;

    while (mounted && _scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 5) {
        // Si el título cabe holgadamente en el AppBar, se detiene el bucle para evitar fugas de memoria
        break;
      }

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) break;

      final durationMs = (maxExtent * 40).clamp(2000, 10000).toInt();

      await _scrollController.animateTo(
        maxExtent,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeInOut,
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) break;

      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeInOut,
      );
    }
    _isScrolling = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();

    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.badgeText.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: widget.primaryColor,
            ),
          ),
          Text(
            widget.titleText,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
            softWrap: false,
          ),
        ],
      ),
    );
  }
}
