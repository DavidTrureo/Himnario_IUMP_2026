import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/obs_server_service.dart';
import '../../hymns/domain/hymn.dart';

class ObsRemoteScreen extends ConsumerStatefulWidget {
  final Hymn hymn;

  const ObsRemoteScreen({Key? key, required this.hymn}) : super(key: key);

  @override
  ConsumerState<ObsRemoteScreen> createState() => _ObsRemoteScreenState();
}

class _ObsRemoteScreenState extends ConsumerState<ObsRemoteScreen> {
  int _activeLineIndex = -1;
  late List<String> _lyricLines;

  @override
  void initState() {
    super.initState();
    _prepareLyrics();
    
    // Start server if not running
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final obsService = ref.read(obsServerProvider);
      if (!obsService.isRunning) {
        await obsService.startServer();
        setState(() {}); // Refresh to show IP
      }
    });
  }

  void _prepareLyrics() {
    // Dividir la letra en líneas y limpiar acordes/tags
    final rawLines = widget.hymn.lyrics.split('\n');
    _lyricLines = [];
    
    for (var line in rawLines) {
      // Remover acordes [C], tags {Coro}, etc
      var cleanLine = line.replaceAll(RegExp(r'\[.*?\]'), '');
      cleanLine = cleanLine.replaceAll(RegExp(r'\{.*?\}'), '');
      cleanLine = cleanLine.trim();
      
      if (cleanLine.isNotEmpty) {
        _lyricLines.add(cleanLine);
      } else if (_lyricLines.isNotEmpty && _lyricLines.last != "") {
        // Preservar espacios entre estrofas, pero solo 1
        _lyricLines.add("");
      }
    }
  }

  void _sendLine(int index) {
    setState(() {
      _activeLineIndex = index;
    });
    
    final obsService = ref.read(obsServerProvider);
    if (index >= 0 && index < _lyricLines.length) {
      obsService.broadcastLyric(_lyricLines[index]);
    } else {
      // Clear
      obsService.broadcastLyric("");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obsService = ref.watch(obsServerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transmisión OBS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Limpiar Pantalla (Quitar letra)',
            onPressed: () => _sendLine(-1),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with instructions
          Container(
            width: double.infinity,
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_tethering, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Conexión OBS (Browser Source)',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  obsService.isRunning && obsService.currentIp != null
                      ? 'http://${obsService.currentIp}:8080'
                      : 'Iniciando servidor...',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Agrega esta URL como una "Fuente de Navegador" en OBS. Ancho recomendado: 1920, Alto: 1080.',
                  style: GoogleFonts.nunito(fontSize: 14),
                ),
              ],
            ),
          ),
          
          // Lyrics List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _lyricLines.length,
              itemBuilder: (context, index) {
                final line = _lyricLines[index];
                final isActive = _activeLineIndex == index;
                final isStanzaBreak = line.isEmpty;

                if (isStanzaBreak) {
                  return const SizedBox(height: 24);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _sendLine(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: isActive 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? theme.colorScheme.primary : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isActive ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ] : null,
                      ),
                      child: Text(
                        line,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                          color: isActive ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
