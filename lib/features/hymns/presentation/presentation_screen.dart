import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/hymn.dart';

class PresentationScreen extends StatefulWidget {
  final Hymn hymn;

  const PresentationScreen({super.key, required this.hymn});

  @override
  State<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends State<PresentationScreen> {
  late List<String> _blocks;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Forzar pantalla completa e inicio en horizontal
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Obtener los bloques de la alabanza limpios de corchetes de acordes
    _blocks = _getMergedBlocksWithoutChords(widget.hymn.lyrics);
  }

  @override
  void dispose() {
    // Restaurar orientación y UI del sistema
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _pageController.dispose();
    super.dispose();
  }

  List<String> _getMergedBlocksWithoutChords(String lyrics) {
    // Quitar acordes en formato [Do]
    final RegExp chordRegex = RegExp(r'\[[^\]]+\]');
    final cleanLyrics = lyrics.replaceAll(chordRegex, '');
    
    final List<String> rawBlocks = cleanLyrics.split('\n\n');
    final List<String> merged = [];
    
    for (var i = 0; i < rawBlocks.length; i++) {
      final block = rawBlocks[i].trim();
      if (block.isEmpty) continue;
      
      final lines = block.split('\n');
      if (lines.isEmpty) continue;
      
      final firstLine = lines.first.trim();
      final isChorus = firstLine.toLowerCase().startsWith('coro');
      final isStanza = RegExp(r'^(stanza|\d+|i+v*x*|v\.?\s*\d+)', caseSensitive: false).hasMatch(firstLine);
      
      if (isChorus || isStanza) {
        merged.add(block);
      } else {
        if (merged.isNotEmpty) {
          merged[merged.length - 1] = '${merged[merged.length - 1]}\n\n$block';
        } else {
          merged.add(block);
        }
      }
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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

          // Botón de Salida Flotante (Esquina superior derecha)
          Positioned(
            top: 20,
            right: 20,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 28),
                hoverColor: Colors.white10,
                splashRadius: 24,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Barra Guía Inferior (Sutil)
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.hymn.collection == 'iump'
                          ? 'Himno ${widget.hymn.id} - ${widget.hymn.title}'
                          : widget.hymn.title,
                      style: GoogleFonts.outfit(
                        color: Colors.white24,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_currentPage + 1} / ${_blocks.length}',
                    style: GoogleFonts.outfit(
                      color: Colors.white30,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockSlide(String blockText) {
    final lines = blockText.split('\n');
    final firstLine = lines.first.trim();
    
    // Identificar si es Coro
    final RegExp keywordRegExp = RegExp(
      r'^(coro\s+[ivx]+|coro\s+\d+|coro)', 
      caseSensitive: false
    );
    final isChorus = keywordRegExp.hasMatch(firstLine);
    
    String displayText = blockText;
    if (isChorus || RegExp(r'^\d+\s*$', caseSensitive: false).hasMatch(firstLine)) {
      displayText = lines.skip(1).join('\n').trim();
    }
    
    // Formatear cada línea con las mayúsculas especiales
    if (isChorus || widget.hymn.collection == 'coros') {
      displayText = displayText.split('\n').map((l) => Hymn.formatLineCasing(l)).join('\n');
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
        constraints: const BoxConstraints(maxWidth: 850),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isChorus) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    'CORO',
                    style: GoogleFonts.outfit(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                displayText,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontStyle: isChorus ? FontStyle.italic : FontStyle.normal,
                  color: isChorus ? Colors.amber[100] : Colors.white,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
