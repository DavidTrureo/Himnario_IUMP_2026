import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/hymn.dart';
import '../../../core/utils/web_window_helper.dart';

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
  double _fontSize = 40.0;
  PresentationTheme _currentTheme = PresentationTheme.darkPremium;
  bool _showControls = true;
  bool _isBlank = false;

  void _broadcastState([int? slideIndex]) {
    WebWindowHelper.broadcastProjectorState(
      slideIndex ?? _currentPage, 
      _currentTheme.name, 
      _fontSize, 
      isBlank: _isBlank,
      hymnId: widget.hymn.id.toString(),
      collection: widget.hymn.collection,
    );
  }

  Future<void> _saveToPrefsAndBroadcast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'projector_hymn_${widget.hymn.collection}_${widget.hymn.id}', 
        jsonEncode(widget.hymn.toJson())
      );
    } catch (_) {}
    if (mounted) {
      _broadcastState();
    }
  }

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
      _saveToPrefsAndBroadcast();
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
    
    // Eliminar acordes y las líneas que solo contienen barras (/, //, ///)
    String cleanLyrics = lyrics.replaceAll(chordRegex, '');
    cleanLyrics = cleanLyrics.split('\n').where((line) {
      return !RegExp(r'^/+$').hasMatch(line.trim());
    }).join('\n');
    
    final List<String> lines = cleanLyrics.split('\n');
    final List<String> rawBlocks = [];
    List<String> currentBlock = [];
    
    final headerRegex = RegExp(
      r'^(coro\s*[ivx]*|coro\s*\d*|puente|final|solista|estrofa\s+\d+|\d+\.|(?:xii|xi|x|ix|viii|vii|vi|v|iv|iii|ii|i)(?:\s|\.|$))\s*:?\s*', 
      caseSensitive: false
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (currentBlock.isNotEmpty) {
          rawBlocks.add(currentBlock.join('\n'));
          currentBlock = [];
        }
        continue;
      }

      final match = headerRegex.firstMatch(line);
      if (match != null) {
        if (currentBlock.isNotEmpty) {
          rawBlocks.add(currentBlock.join('\n'));
          currentBlock = [];
        }
        currentBlock.add(line);
      } else {
        currentBlock.add(line);
      }
    }
    if (currentBlock.isNotEmpty) {
      rawBlocks.add(currentBlock.join('\n'));
    }

    // 1. Regla Litúrgica: Intercalar el coro único respetando trozos (saltos de línea)
    final chorusBlocksCount = rawBlocks.where((b) {
      final firstLine = b.split('\n').first.trim().toLowerCase();
      return firstLine.startsWith('coro');
    }).length;

    List<String> sequencedBlocks = [];
    if (chorusBlocksCount == 1) {
      final List<String> chorusFragments = [];
      int chorusStartIndex = -1;
      for (int i = 0; i < rawBlocks.length; i++) {
        final fl = rawBlocks[i].split('\n').first.trim().toLowerCase();
        if (fl.startsWith('coro')) {
          chorusStartIndex = i;
          break;
        }
      }
      
      if (chorusStartIndex != -1) {
        for (int i = chorusStartIndex; i < rawBlocks.length; i++) {
          final fl = rawBlocks[i].split('\n').first.trim().toLowerCase();
          if (i != chorusStartIndex && (fl.startsWith('coro') || fl.startsWith('puente') || fl.startsWith('final') || RegExp(r'^(estrofa\s+\d+|\d+\.|(?:xii|xi|x|ix|viii|vii|vi|v|iv|iii|ii|i)(?:\s|\.|$))', caseSensitive: false).hasMatch(fl))) {
            break;
          }
          chorusFragments.add(rawBlocks[i]);
        }
      }

      for (int i = 0; i < rawBlocks.length; i++) {
        final current = rawBlocks[i];
        sequencedBlocks.add(current);

        String? currentHeader;
        for (int j = i; j >= 0; j--) {
          final b = rawBlocks[j];
          final fl = b.split('\n').first.trim().toLowerCase();
          if (fl.startsWith('coro')) { currentHeader = 'coro'; break; }
          if (fl.startsWith('puente')) { currentHeader = 'puente'; break; }
          if (fl.startsWith('final')) { currentHeader = 'final'; break; }
          if (RegExp(r'^(estrofa\s+\d+|\d+\.|(?:xii|xi|x|ix|viii|vii|vi|v|iv|iii|ii|i)(?:\s|\.|$))', caseSensitive: false).hasMatch(fl)) {
            currentHeader = 'estrofa'; break;
          }
        }

        if (currentHeader == 'estrofa') {
          bool isLastFragment = true;
          if (i < rawBlocks.length - 1) {
            final nextBlockFirstLine = rawBlocks[i + 1].split('\n').first.trim().toLowerCase();
            final hasHeader = nextBlockFirstLine.startsWith('coro') || 
                              nextBlockFirstLine.startsWith('puente') || 
                              nextBlockFirstLine.startsWith('final') || 
                              RegExp(r'^(estrofa\s+\d+|\d+\.|(?:xii|xi|x|ix|viii|vii|vi|v|iv|iii|ii|i)(?:\s|\.|$))', caseSensitive: false).hasMatch(nextBlockFirstLine);
            if (!hasHeader) {
              isLastFragment = false;
            }
          }
          
          if (isLastFragment) {
            bool nextIsChorus = false;
            if (i < rawBlocks.length - 1) {
              final nextBlockFirstLine = rawBlocks[i + 1].split('\n').first.trim().toLowerCase();
              if (nextBlockFirstLine.startsWith('coro')) {
                nextIsChorus = true;
              }
            }
            if (!nextIsChorus) {
              sequencedBlocks.addAll(chorusFragments);
            }
          }
        }
      }
    } else {
      sequencedBlocks = List.from(rawBlocks);
    }

    // 2. Dividir automáticamente bloques muy extensos en 2 fragmentos
    final List<String> finalBlocks = [];
    for (var block in sequencedBlocks) {
      final blockLines = block.split('\n');
      if (blockLines.length > 8) {
        final mid = (blockLines.length / 2).ceil();
        
        final firstPart = blockLines.sublist(0, mid).join('\n');
        String secondPart = blockLines.sublist(mid).join('\n');
        
        final headerMatch = RegExp(r'^(\d+\.|[Cc][Oo][Rr][Oo]:?|[Pp][Uu][Ee][Nn][Tt][Ee]:?|[Ff][Ii][Nn][Aa][Ll]:?)\s+').firstMatch(blockLines.first);
        if (headerMatch != null) {
          secondPart = '${headerMatch.group(1)} $secondPart';
        }
        
        finalBlocks.add(firstPart);
        finalBlocks.add(secondPart);
      } else {
        finalBlocks.add(block);
      }
    }

    // 3. Agregar la diapositiva de Portada (Título) al principio
    finalBlocks.insert(0, '[TITLE]');

    return finalBlocks.map((b) {
      if (b == '[TITLE]') return b;
      final text = b.trim();
      final match = RegExp(r'^(\d+\.|[Cc][Oo][Rr][Oo]:?)\s+').firstMatch(text);
      if (match != null) {
        final prefix = match.group(1)!;
        final rest = text.substring(match.end);
        return '$prefix\n$rest';
      }
      return text;
    }).toList();
  }

  String _getBlockLabel(int index) {
    if (index >= _blocks.length) return '';
    final block = _blocks[index];
    if (block == '[TITLE]') return 'Título';

    final alphabet = ['A', 'B', 'C', 'D', 'E', 'F'];
    String? foundHeader;
    int blocksSinceHeader = 0;

    for (int i = index; i >= 0; i--) {
      final b = _blocks[i];
      if (b == '[TITLE]') continue;
      final firstLine = b.split('\n').first.trim().toLowerCase();
      
      if (firstLine.startsWith('coro')) {
        foundHeader = 'Coro ';
        break;
      }
      if (firstLine.startsWith('puente')) {
        foundHeader = 'Puente ';
        break;
      }
      if (firstLine.startsWith('final')) {
        foundHeader = 'Final ';
        break;
      }
      final match = RegExp(r'^(estrofa\s+\d+|\d+\.|([ivx]+))(\s*\.\s*|\s*\-\s*|\s+|$)(.*)', caseSensitive: false).firstMatch(firstLine);
      if (match != null) {
        final group1 = match.group(1)!;
        final romanStr = match.group(2);
        final separator = match.group(3) ?? '';
        final restText = match.group(4) ?? '';
        
        bool isRoman = false;
        String textToParse = group1;
        
        if (romanStr != null) {
          if (romanStr.toLowerCase() == 'vi' && !separator.contains('.') && !separator.contains('-') && restText.trim().isNotEmpty) {
             // False positive for "vi "
          } else {
             isRoman = true;
             textToParse = romanStr;
          }
        } else {
          isRoman = true; // estrofa X or X.
        }

        if (isRoman) {
          final text = textToParse.trim().replaceAll('.', '');
          final numMatch = RegExp(r'\d+').firstMatch(text);
          if (numMatch != null) {
            foundHeader = 'E${numMatch.group(0)}';
          } else {
            final cleanRoman = text.toUpperCase();
            const map = {
              'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5, 
              'VI': 6, 'VII': 7, 'VIII': 8, 'IX': 9, 'X': 10, 'XI': 11, 'XII': 12
            };
            final numRoman = map[cleanRoman];
            if (numRoman != null) {
              foundHeader = 'E$numRoman';
            } else {
              foundHeader = 'E?';
            }
          }
          break;
        }
      }
      
      blocksSinceHeader++;
    }

    if (foundHeader == null) {
        foundHeader = 'E1'; 
        blocksSinceHeader = index;
    }

    int totalFragments = 0;
    int groupStart = index - blocksSinceHeader;
    for (int i = groupStart; i < _blocks.length; i++) {
        final block = _blocks[i];
        if (block == '[TITLE]') continue;
        final firstLine = block.split('\n').first.trim().toLowerCase();
        if (i != groupStart && (firstLine.startsWith('coro') || firstLine.startsWith('puente') || firstLine.startsWith('final') || RegExp(r'^(estrofa\s+\d+|\d+\.|(?:xii|xi|x|ix|viii|vii|vi|v|iv|iii|ii|i)(?:\s|\.|$))', caseSensitive: false).hasMatch(firstLine))) {
            break;
        }
        totalFragments++;
    }

    if (totalFragments > 1 || blocksSinceHeader > 0) {
        if (blocksSinceHeader < alphabet.length) {
            return '$foundHeader${alphabet[blocksSinceHeader]}';
        } else {
            return '$foundHeader-${blocksSinceHeader + 1}';
        }
    }
    
    return foundHeader;
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
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showControls = !_showControls;
                    });
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _blocks.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                      _broadcastState(index);
                    },
                    itemBuilder: (context, index) {
                      final blockText = _blocks[index];
                      return _buildBlockSlide(index, blockText);
                    },
                  ),
                ),
              ),

              // Controles de UI superpuestos
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Stack(
                      children: [

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
                              _broadcastState(_currentPage);
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
                                _broadcastState(_currentPage);
                              }
                            },
                          ),
                          Text(
                            '${_fontSize.toInt()}pt',
                            style: TextStyle(fontFamily: 'Nunito', color: _themeUiMutedColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          // Aumentar Letra
                          IconButton(
                            icon: Icon(Icons.add_circle_outline_rounded, color: _themeUiMutedColor, size: 20),
                            onPressed: () {
                              if (_fontSize < 250) {
                                setState(() => _fontSize += 2);
                                _broadcastState(_currentPage);
                              }
                            },
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 1,
                            height: 24,
                            color: _themeUiMutedColor.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Pantalla Negra',
                            child: IconButton(
                              icon: Icon(
                                _isBlank ? Icons.desktop_access_disabled : Icons.desktop_windows,
                                color: _isBlank ? Colors.redAccent : _themeUiMutedColor,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isBlank = !_isBlank;
                                });
                                _broadcastState();
                              },
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          // Botón Despegar (Siempre visible para depuración)
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, color: Colors.blueAccent, size: 28),
                            tooltip: 'Despegar Proyector',
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString(
                                'projector_hymn_${widget.hymn.collection}_${widget.hymn.id}', 
                                jsonEncode(widget.hymn.toJson())
                              );
                              WebWindowHelper.openProjectorWindow('/#/projector-view/${widget.hymn.collection}/${widget.hymn.id}');
                            },
                          ),
                          const SizedBox(width: 8),
                          // Botón Cerrar
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: _themeUiColor, size: 26),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Grid/Lista Horizontal de Diapositivas (Navegación no lineal)
              Positioned(
                left: 0,
                right: 0,
                bottom: 60, // Encima del título
                child: SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _blocks.length,
                    itemBuilder: (context, index) {
                      final isSelected = _currentPage == index;
                      final blockText = _blocks[index];
                      final firstLine = blockText.split('\n').first.trim().toLowerCase();
                      final isChorus = firstLine.startsWith('coro');
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0, top: 5, bottom: 5),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected ? Colors.blueAccent : _themeUiButtonBgColor,
                            foregroundColor: isSelected ? Colors.white : _themeUiColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                          child: Text(
                            _getBlockLabel(index),
                            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      );
                    },
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
                          style: TextStyle(fontFamily: 'Nunito', 
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
                          style: TextStyle(fontFamily: 'Nunito', 
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockSlide(int index, String blockText) {
    final lines = blockText.split('\n');
    final firstLine = lines.first.trim();
    
    final RegExp tagRegExp = RegExp(
      r'^(coro\s+[ivx]+|coro\s+\d+|coro|puente|final|est\.\s*\d+|estrofa\s+\d+|\d+\.|\d+|(?:xii|xi|x|ix|viii|vii|vi|v|iv|iii|ii|i)(?:\s|\.|$))\s*:?\s*', 
      caseSensitive: false
    );
    final activeHeader = _getBlockLabel(index);
    final isChorus = activeHeader.toLowerCase().startsWith('coro') || 
                     activeHeader.toLowerCase().startsWith('puente') || 
                     activeHeader.toLowerCase().startsWith('final');
    
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
    
    if (blockText == '[TITLE]') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                widget.hymn.title,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Nunito', 
                  fontSize: _fontSize * 1.5,
                  fontWeight: FontWeight.bold,
                  color: _getThemeTextColor(false),
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (widget.hymn.collection == 'iump')
              Text(
                'Himno ${widget.hymn.id}',
                style: TextStyle(fontFamily: 'Nunito', 
                  fontSize: _fontSize * 0.7,
                  color: _getThemeTextColor(false).withValues(alpha: 0.6),
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms);
    }

    final textColor = _getThemeTextColor(isChorus);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Spacer(),
            SingleChildScrollView(
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
                        activeHeader.split(' ').first.toUpperCase(),
                        style: TextStyle(fontFamily: 'Nunito', 
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    displayText,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Nunito', 
                      fontSize: _fontSize,
                      fontWeight: FontWeight.bold,
                      fontStyle: isChorus ? FontStyle.italic : FontStyle.normal,
                      color: textColor,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              widget.hymn.collection == 'iump' ? '${widget.hymn.id}. ${widget.hymn.title}' : widget.hymn.title,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito', 
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _getThemeTextColor(false).withValues(alpha: 0.25),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

