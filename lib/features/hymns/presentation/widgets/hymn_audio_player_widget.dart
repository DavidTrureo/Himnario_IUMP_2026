import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HymnAudioPlayerWidget extends StatefulWidget {
  final String collection;
  final int hymnId;

  const HymnAudioPlayerWidget({
    super.key,
    required this.collection,
    required this.hymnId,
  });

  @override
  State<HymnAudioPlayerWidget> createState() => _HymnAudioPlayerWidgetState();
}

class _HymnAudioPlayerWidgetState extends State<HymnAudioPlayerWidget> {
  bool _isPlaying = false;
  bool _isRecording = false;
  double _progress = 0.0;
  String? _audioNote;

  @override
  void initState() {
    super.initState();
    _loadAudioNote();
  }

  Future<void> _loadAudioNote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'audio_note_${widget.collection}_${widget.hymnId}';
      setState(() {
        _audioNote = prefs.getString(key);
      });
    } catch (_) {}
  }

  Future<void> _toggleRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'audio_note_${widget.collection}_${widget.hymnId}';

    if (_isRecording) {
      // Detener grabación
      setState(() {
        _isRecording = false;
        _audioNote = 'Audio de Ensayo IUMP (Grabado)';
      });
      await prefs.setString(key, 'Audio de Ensayo IUMP (Grabado)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎙️ Audio de ensayo guardado exitosamente')),
        );
      }
    } else {
      // Iniciar grabación
      setState(() {
        _isRecording = true;
      });
    }
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _simulateProgress();
      }
    });
  }

  void _simulateProgress() async {
    while (_isPlaying && _progress < 1.0) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && _isPlaying) {
        setState(() {
          _progress += 0.05;
          if (_progress >= 1.0) {
            _progress = 0.0;
            _isPlaying = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                onPressed: _togglePlay,
                tooltip: _isPlaying ? 'Pausar Pista' : 'Reproducir Pista de Ensayo',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _audioNote ?? 'Pista de Referencia IUMP',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      _isRecording ? '🎙️ Grabando voz de ensayo...' : 'Acompañamiento y voces de coro',
                      style: GoogleFonts.nunito(fontSize: 11, color: _isRecording ? Colors.redAccent : null),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                  color: _isRecording ? Colors.redAccent : theme.colorScheme.primary,
                ),
                onPressed: _toggleRecord,
                tooltip: _isRecording ? 'Detener Grabación' : 'Grabar Audio de Ensayo',
              ),
            ],
          ),
          if (_isPlaying) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}
