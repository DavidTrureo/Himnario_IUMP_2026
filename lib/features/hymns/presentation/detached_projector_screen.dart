import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../domain/hymn.dart';
import '../../../core/utils/web_window_helper.dart';

class DetachedProjectorScreen extends StatefulWidget {
  final String collection;
  final String hymnId;

  const DetachedProjectorScreen({super.key, required this.collection, required this.hymnId});

  @override
  State<DetachedProjectorScreen> createState() => _DetachedProjectorScreenState();
}

class _DetachedProjectorScreenState extends State<DetachedProjectorScreen> {
  Hymn? _hymn;
  List<String> _blocks = [];
  int _currentPage = 0;
  String _currentTheme = 'darkPremium';
  double _fontSize = 42.0;
  bool _isBlank = false;

  @override
  void initState() {
    super.initState();
    _loadHymn();

    // Listen to changes from the main window via BroadcastChannel
    WebWindowHelper.listenToProjectorState((newIndex, theme, fontSize, isBlank, newHymnId, newCollection) {
      if (mounted) {
        if (newHymnId != null && newCollection != null && (newHymnId != widget.hymnId || newCollection != widget.collection)) {
          // El himno ha cambiado, redirigimos la ruta para recargar la vista con el nuevo himno.
          context.go('/projector-view/$newCollection/$newHymnId');
          return;
        }

        setState(() {
          if (newIndex >= 0 && newIndex < _blocks.length) {
            _currentPage = newIndex;
          }
          _currentTheme = theme;
          _fontSize = fontSize;
          _isBlank = isBlank;
        });
      }
    });
  }

  Future<void> _loadHymn() async {
    Hymn? parsedHymn;
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString('projector_hymn_${widget.collection}_${widget.hymnId}');
      if (storedJson != null) {
        final jsonMap = jsonDecode(storedJson);
        parsedHymn = Hymn.fromJson(jsonMap, widget.collection);
      }
    } catch (_) {}

    if (parsedHymn == null) {
      final hymns = Hymn.getCachedBaseHymns(widget.collection);
      try {
        parsedHymn = hymns.firstWhere((h) => h.id.toString() == widget.hymnId);
      } catch (_) {}
    }

    if (parsedHymn != null) {
      setState(() {
        _hymn = parsedHymn;
        _blocks = _getMergedBlocksWithoutChords(parsedHymn!.lyrics);
        if (_currentPage >= _blocks.length) {
          _currentPage = 0;
        }
      });
    }
  }

  @override
  void didUpdateWidget(DetachedProjectorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hymnId != oldWidget.hymnId || widget.collection != oldWidget.collection) {
      _loadHymn();
    }
  }

  @override
  void dispose() {
    WebWindowHelper.dispose();
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
      r'^(coro\s*[ivx]*|coro\s*\d*|puente|final|solista|estrofa\s+\d+|\d+\.|[ivx]+\.)\s*:?\s*', 
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
          if (i != chorusStartIndex && (fl.startsWith('coro') || fl.startsWith('puente') || fl.startsWith('final') || RegExp(r'^(estrofa\s+\d+|\d+\.|[ivx]+\.)', caseSensitive: false).hasMatch(fl))) {
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
          if (RegExp(r'^(estrofa\s+\d+|\d+\.|[ivx]+\.)', caseSensitive: false).hasMatch(fl)) {
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
                              RegExp(r'^(estrofa\s+\d+|\d+\.|[ivx]+\.)', caseSensitive: false).hasMatch(nextBlockFirstLine);
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
        finalBlocks.add(blockLines.sublist(0, mid).join('\n'));
        finalBlocks.add(blockLines.sublist(mid).join('\n'));
      } else {
        finalBlocks.add(block);
      }
    }
    
    // 3. Agregar la diapositiva de Portada (Título) al principio
    finalBlocks.insert(0, '[TITLE]');

    return finalBlocks;
  }

  BoxDecoration _getThemeDecoration() {
    switch (_currentTheme) {
      case 'darkPremium':
      case 'PresentationTheme.darkPremium':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        );
      case 'vitralChurch':
      case 'PresentationTheme.vitralChurch':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1B4B), Color(0xFF31103F), Color(0xFF0F172A)],
          ),
        );
      case 'highContrast':
      case 'PresentationTheme.highContrast':
        return const BoxDecoration(color: Colors.black);
      case 'whiteProjector':
      case 'PresentationTheme.whiteProjector':
        return const BoxDecoration(color: Colors.white);
      default:
        return const BoxDecoration(color: Colors.black);
    }
  }

  Color _getThemeTextColor(bool isChorus) {
    switch (_currentTheme) {
      case 'darkPremium':
      case 'PresentationTheme.darkPremium':
        return isChorus ? const Color(0xFFFDE047) : Colors.white;
      case 'vitralChurch':
      case 'PresentationTheme.vitralChurch':
        return isChorus ? const Color(0xFFF472B6) : const Color(0xFFE2E8F0);
      case 'highContrast':
      case 'PresentationTheme.highContrast':
        return isChorus ? Colors.yellowAccent : Colors.white;
      case 'whiteProjector':
      case 'PresentationTheme.whiteProjector':
        return isChorus ? const Color(0xFF1E3A8A) : Colors.black;
      default:
        return Colors.white;
    }
  }

  Widget _buildBlockSlide(int index, String blockText) {
    final lines = blockText.split('\n');
    final firstLine = lines.first.trim();
    
    final RegExp tagRegExp = RegExp(
      r'^(coro\s+[ivx]+|coro\s+\d+|coro|est\.\s*\d+|estrofa\s+\d+|\d+\.|\d+)\s*:?\s*', 
      caseSensitive: false
    );

    bool isChorus = false;
    for (int i = index; i >= 0; i--) {
      final b = _blocks[i];
      if (b == '[TITLE]') continue;
      final fl = b.split('\n').first.trim().toLowerCase();
      if (fl.startsWith('coro')) {
        isChorus = true;
        break;
      }
      if (fl.startsWith('puente') || fl.startsWith('final') || RegExp(r'^(estrofa\s+\d+|\d+\.|[ivx]+\.)', caseSensitive: false).hasMatch(fl)) {
        break;
      }
    }
    
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
    
    if (blockText == '[TITLE]' && _hymn != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                _hymn!.title,
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
            if (widget.collection == 'iump')
              Text(
                'Himno ${_hymn!.id}',
                style: TextStyle(fontFamily: 'Nunito', 
                  fontSize: _fontSize * 0.7,
                  color: _getThemeTextColor(false).withValues(alpha: 0.6),
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      );
    }

    final textColor = _getThemeTextColor(isChorus);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
        constraints: const BoxConstraints(maxWidth: 1000),
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
                        'CORO',
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
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
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (_hymn != null)
              Text(
                widget.collection == 'iump' ? '${_hymn!.id}. ${_hymn!.title}' : _hymn!.title,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hymn == null || _blocks.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isBlank 
        ? Container(color: Colors.black) // Pantalla totalmente negra
        : Container(
            decoration: _getThemeDecoration(),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildBlockSlide(_currentPage, _blocks[_currentPage]),
            ),
          ),
    );
  }
}
