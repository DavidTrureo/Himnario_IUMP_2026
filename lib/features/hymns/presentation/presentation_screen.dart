import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/hymn.dart';

enum PresentationTheme {
  darkPremium,
  vitralChurch,
  highContrast,
  whiteProjector,
}

class PresentationScreen extends StatefulWidget {
  final Hymn hymn;

  const PresentationScreen({super.key, required this.hymn});

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen> {
  late List<String> _blocks;
  final PageController _pageController = PageController();
  final FocusNode _focusNode = FocusNode();
  int _currentPage = 0;
  double _fontSize = 32.0;
  PresentationTheme _currentTheme = PresentationTheme.darkPremium;

  @override
  void initState() {
    super.initState();
    // Forzar pantalla completa e inicio en horizontal
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _blocks = _getMergedBlocksWithoutChords(widget.hymn.lyrics);
    
    // Auto-enfocar para captura de eventos de teclado/D-pad
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> _getMergedBlocksWithoutChords(String lyrics) {
    final RegExp chordRegex = RegExp(r'\[[^\]]+\]');
    final cleanLyrics = lyrics.replaceAll(chordRegex, '');
    
    final List<String> rawBlocks = cleanLyrics.split('\n\n');
    final List<String> initialBlocks = [];
    
    for (var i = 0; i < rawBlocks.length; i++) {
      final block = rawBlocks[i].trim();
      if (block.isEmpty) continue;
      
      final lines = block.split('\n');
      if (lines.isEmpty) continue;
      
      final firstLine = lines.first.trim();
      final isChorus = firstLine.toLowerCase().startsWith('coro');
      final isBridge = firstLine.toLowerCase().startsWith('puente');
      final isStanza = RegExp(r'^(stanza|\d+|i+v*x*|v\.?\s*\d+)', caseSensitive: false).hasMatch(firstLine);
      
      if (isChorus || isStanza || isBridge) {
        initialBlocks.add(block);
      } else {
        if (initialBlocks.isNotEmpty) {
          initialBlocks[initialBlocks.length - 1] = '${initialBlocks[initialBlocks.length - 1]}\n\n$block';
        } else {
          initialBlocks.add(block);
        }
      }
    }

    // Regla Litúrgica: Si el canto posee 1 único Coro, intercalarlo automáticamente después de cada estrofa en la proyección
    final chorusBlocks = initialBlocks.where((b) {
      final firstLine = b.split('\n').first.trim().toLowerCase();
      return firstLine.startsWith('coro');
    }).toList();

    if (chorusBlocks.length == 1) {
      final singleChorus = chorusBlocks.first;
      final List<String> sequencedBlocks = [];

      for (int i = 0; i < initialBlocks.length; i++) {
        final current = initialBlocks[i];
        if (current == singleChorus) continue; // Intercalamos manualmente después de cada estrofa

        sequencedBlocks.add(current);
        
        final firstLine = current.split('\n').first.trim();
        final isStanza = RegExp(r'^(stanza|\d+|i+v*x*|v\.?\s*\d+)', caseSensitive: false).hasMatch(firstLine);
        if (isStanza) {
          sequencedBlocks.add(singleChorus);
        }
      }

      if (sequencedBlocks.isNotEmpty) {
        return sequencedBlocks;
      }
    }

    return initialBlocks;
  }

  void _nextPage() {
    if (_currentPage < _blocks.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.pageDown) {
        _nextPage();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.pageUp) {
        _previousPage();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      }
    }
  }

  BoxDecoration _getThemeDecoration() {
    switch (_currentTheme) {
      case PresentationTheme.darkPremium:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        );
      case PresentationTheme.vitralChurch:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1B4B), Color(0xFF31103F), Color(0xFF0F172A)],
          ),
        );
      case PresentationTheme.highContrast:
        return const BoxDecoration(color: Colors.black);
      case PresentationTheme.whiteProjector:
        return const BoxDecoration(color: Colors.white);
    }
  }

  Color _getThemeTextColor(bool isChorus) {
    switch (_currentTheme) {
      case PresentationTheme.darkPremium:
        return isChorus ? const Color(0xFFFDE047) : Colors.white;
      case PresentationTheme.vitralChurch:
        return isChorus ? const Color(0xFFF472B6) : const Color(0xFFE2E8F0);
      case PresentationTheme.highContrast:
        return isChorus ? Colors.yellowAccent : Colors.white;
      case PresentationTheme.whiteProjector:
        return isChorus ? const Color(0xFF1E3A8A) : Colors.black;
    }
  }

  Color get _themeUiColor {
    return _currentTheme == PresentationTheme.whiteProjector ? Colors.black87 : Colors.white70;
  }

  Color get _themeUiMutedColor {
    return _currentTheme == PresentationTheme.whiteProjector ? Colors.black54 : Colors.white54;
  }

  Color get _themeUiFooterMutedColor {
    return _currentTheme == PresentationTheme.whiteProjector ? Colors.black45 : Colors.white38;
  }

  Color get _themeUiButtonBgColor {
    return _currentTheme == PresentationTheme.whiteProjector 
      ? Colors.black.withValues(alpha: 0.08) 
      : Colors.white.withValues(alpha: 0.12);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Container(
          decoration: _getThemeDecoration(),
          child: Stack(
            children: [
              // PageView de Letras
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _blocks.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final blockText = _blocks[index];
                    return _buildBlockSlide(blockText);
                  },
                ),
              ),

              // Botones de Navegación Lateral (Flecha Izquierda)
              if (_currentPage > 0)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 24),
                      style: IconButton.styleFrom(
                        backgroundColor: _themeUiButtonBgColor,
                        foregroundColor: _themeUiColor,
                      ),
                      onPressed: _previousPage,
                    ),
                  ),
                ),

              // Botones de Navegación Lateral (Flecha Derecha)
              if (_currentPage < _blocks.length - 1)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 24),
                      style: IconButton.styleFrom(
                        backgroundColor: _themeUiButtonBgColor,
                        foregroundColor: _themeUiColor,
                      ),
                      onPressed: _nextPage,
                    ),
                  ),
                ),

              // Barra de Control Superior (Temas + Tamaño Letra + Cerrar)
              Positioned(
                top: 16,
                left: 20,
                right: 20,
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Controles de Tema y Tamaño
                      Row(
                        children: [
                          // Cambiar Tema Visual
                          PopupMenuButton<PresentationTheme>(
                            icon: Icon(Icons.palette_rounded, color: _themeUiMutedColor, size: 22),
                            tooltip: 'Cambiar Tema Proyector',
                            onSelected: (theme) {
                              setState(() {
                                _currentTheme = theme;
                              });
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: PresentationTheme.darkPremium,
                                child: Text('Oscuro Premium'),
                              ),
                              const PopupMenuItem(
                                value: PresentationTheme.vitralChurch,
                                child: Text('Vitral Iglesia'),
                              ),
                              const PopupMenuItem(
                                value: PresentationTheme.highContrast,
                                child: Text('Alto Contraste (Negro/Amarillo)'),
                              ),
                              const PopupMenuItem(
                                value: PresentationTheme.whiteProjector,
                                child: Text('Blanco Proyector'),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          // Disminuir Letra
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline_rounded, color: _themeUiMutedColor, size: 20),
                            onPressed: () {
                              if (_fontSize > 20) {
                                setState(() => _fontSize -= 2);
                              }
                            },
                          ),
                          Text(
                            '${_fontSize.toInt()}pt',
                            style: GoogleFonts.outfit(color: _themeUiMutedColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          // Aumentar Letra
                          IconButton(
                            icon: Icon(Icons.add_circle_outline_rounded, color: _themeUiMutedColor, size: 20),
                            onPressed: () {
                              if (_fontSize < 60) {
                                setState(() => _fontSize += 2);
                              }
                            },
                          ),
                        ],
                      ),

                      // Botón Cerrar
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: _themeUiColor, size: 26),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),

              // Barra Guía Inferior (Título e Indicador de Diapositiva)
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '📺 MODO PROYECTOR • ' + (widget.hymn.collection == 'iump'
                              ? 'Himno ${widget.hymn.id} - ${widget.hymn.title}'
                              : widget.hymn.title),
                          style: GoogleFonts.outfit(
                            color: _themeUiFooterMutedColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _themeUiButtonBgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_currentPage + 1} / ${_blocks.length}',
                          style: GoogleFonts.outfit(
                            color: _themeUiColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockSlide(String blockText) {
    final lines = blockText.split('\n');
    final firstLine = lines.first.trim();
    
    final RegExp tagRegExp = RegExp(
      r'^(coro\s+[ivx]+|coro\s+\d+|coro|est\.\s*\d+|estrofa\s+\d+|\d+\.|\d+)\s*:?\s*', 
      caseSensitive: false
    );
    final isChorus = RegExp(r'^(coro\s+[ivx]+|coro\s+\d+|coro)', caseSensitive: false).hasMatch(firstLine);
    
    String displayText = blockText;
    if (tagRegExp.hasMatch(firstLine)) {
      final lineWithoutTag = firstLine.replaceFirst(tagRegExp, '').trim();
      if (lineWithoutTag.isEmpty) {
        displayText = lines.skip(1).join('\n').trim();
      } else {
        final rest = lines.skip(1).join('\n');
        displayText = '$lineWithoutTag\n$rest'.trim();
      }
    }
    
    final textColor = _getThemeTextColor(isChorus);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
        constraints: const BoxConstraints(maxWidth: 1000),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isChorus) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    'CORO',
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.bold,
                    fontStyle: isChorus ? FontStyle.italic : FontStyle.normal,
                    color: textColor,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
