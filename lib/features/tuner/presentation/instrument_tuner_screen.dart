import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/app_music_icons.dart';
import '../../hymns/presentation/widgets/metronome_audio_synth.dart';

class InstrumentPreset {
  final String name;
  final String category;
  final IconData icon;
  final List<String> notes;
  final List<double> frequenciesHz;

  const InstrumentPreset({
    required this.name,
    required this.category,
    required this.icon,
    required this.notes,
    required this.frequenciesHz,
  });
}

final List<InstrumentPreset> kInstrumentPresets = [
  const InstrumentPreset(
    name: 'Guitarra Acústica',
    category: 'Cuerdas',
    icon: Icons.music_note_rounded,
    notes: ['6ª Mi (E2)', '5ª La (A2)', '4ª Re (D3)', '3ª Sol (G3)', '2ª Si (B3)', '1ª Mi (E4)'],
    frequenciesHz: [82.41, 110.00, 146.83, 196.00, 246.94, 329.63],
  ),
  const InstrumentPreset(
    name: 'Mandolina',
    category: 'Cuerdas',
    icon: Icons.grid_view_rounded,
    notes: ['4ª Sol (G3)', '3ª Re (D4)', '2ª La (A4)', '1ª Mi (E5)'],
    frequenciesHz: [196.00, 293.66, 440.00, 659.25],
  ),
  const InstrumentPreset(
    name: 'Violín',
    category: 'Cuerdas Frotadas',
    icon: Icons.graphic_eq_rounded,
    notes: ['4ª Sol (G3)', '3ª Re (D4)', '2ª La (A4)', '1ª Mi (E5)'],
    frequenciesHz: [196.00, 293.66, 440.00, 659.25],
  ),
  const InstrumentPreset(
    name: 'Bajo Eléctrico',
    category: 'Bajo',
    icon: Icons.speaker_rounded,
    notes: ['4ª Mi (E1)', '3ª La (A1)', '2ª Re (D2)', '1ª Sol (G2)'],
    frequenciesHz: [41.20, 55.00, 73.42, 98.00],
  ),
  const InstrumentPreset(
    name: 'Trompeta (Sib)',
    category: 'Viento Metal',
    icon: Icons.campaign_rounded,
    notes: ['Do (C4)', 'Re (D4)', 'Mi (E4)', 'Fa (F4)', 'Sol (G4)', 'La (A4)'],
    frequenciesHz: [261.63, 293.66, 329.63, 349.23, 392.00, 440.00],
  ),
  const InstrumentPreset(
    name: 'Saxofón Alto (Mib)',
    category: 'Viento Madera',
    icon: Icons.wb_incandescent_rounded,
    notes: ['La (A3)', 'Do (C4)', 'Re (D4)', 'Mi (E4)', 'Sol (G4)'],
    frequenciesHz: [220.00, 261.63, 293.66, 329.63, 392.00],
  ),
  const InstrumentPreset(
    name: 'Ukulele / Charango',
    category: 'Cuerdas',
    icon: Icons.tune_rounded,
    notes: ['4ª Sol (G4)', '3ª Do (C4)', '2ª Mi (E4)', '1ª La (A4)'],
    frequenciesHz: [392.00, 261.63, 329.63, 440.00],
  ),
];

class InstrumentTunerScreen extends StatefulWidget {
  const InstrumentTunerScreen({super.key});

  @override
  State<InstrumentTunerScreen> createState() => _InstrumentTunerScreenState();
}

class _InstrumentTunerScreenState extends State<InstrumentTunerScreen> {
  InstrumentPreset _selectedPreset = kInstrumentPresets[0];
  int _selectedNoteIndex = 0;
  bool _isAutoMode = true;
  bool _isPlayingReferenceTone = false;
  bool _hasMicrophonePermission = false;
  
  double _tuneCentsOffset = 0.0;
  double _detectedHz = 0.0;
  double _smoothedHz = 0.0;
  String _detectedNoteName = '';

  final List<double> _pitchHistory = [];
  int _lastCandidateIndex = -1;
  int _candidateMatchCount = 0;

  @override
  void initState() {
    super.initState();
    _checkAndRequestMicrophonePermission();
  }

  @override
  void dispose() {
    stopPitchDetector();
    super.dispose();
  }

  Future<void> _checkAndRequestMicrophonePermission() async {
    if (kIsWeb) {
      setState(() {
        _hasMicrophonePermission = true;
      });
      _startMicPitchDetector();
      return;
    }

    final status = await Permission.microphone.status;
    if (status.isGranted) {
      setState(() {
        _hasMicrophonePermission = true;
      });
      _startMicPitchDetector();
    } else {
      final result = await Permission.microphone.request();
      setState(() {
        _hasMicrophonePermission = result.isGranted;
      });
      if (result.isGranted) {
        _startMicPitchDetector();
      }
    }
  }

  void _processPitchInput(double rawPitchHz) {
    if (!mounted || _isPlayingReferenceTone || rawPitchHz <= 30.0) return;

    // 1. Historial de Mediana de Frecuencias (Elimina saltos por armónicos)
    _pitchHistory.add(rawPitchHz);
    if (_pitchHistory.length > 5) {
      _pitchHistory.removeAt(0);
    }
    
    final sortedPitches = List<double>.from(_pitchHistory)..sort();
    final medianHz = sortedPitches[sortedPitches.length ~/ 2];

    // 2. Filtro de Suavizado Exponencial Estable (EMA 70/30)
    if (_smoothedHz == 0.0 || (_smoothedHz - medianHz).abs() > 80) {
      _smoothedHz = medianHz;
    } else {
      _smoothedHz = (_smoothedHz * 0.70) + (medianHz * 0.30);
    }
    final currentPitch = _smoothedHz;

    // Nota cromática universal según A4 = 440Hz
    final noteNames = ['Do (C)', 'Do# (C#)', 'Re (D)', 'Re# (D#)', 'Mi (E)', 'Fa (F)', 'Fa# (F#)', 'Sol (G)', 'Sol# (G#)', 'La (A)', 'La# (A#)', 'Si (B)'];
    final semitonesFromA4 = (12 * (math.log(currentPitch / 440.0) / math.ln2)).round();
    final noteIdx = ((semitonesFromA4 + 9) % 12 + 12) % 12;
    final octave = 4 + ((semitonesFromA4 + 9) / 12.0).floor();
    final exactNoteName = '${noteNames[noteIdx]} $octave';

    int targetStringIndex = _selectedNoteIndex;

    if (_isAutoMode) {
      // 3. Detección Inteligente de Cuerda con Bloqueo de Histeresis
      double minDiff = 999999.0;
      int closestIdx = 0;

      for (int i = 0; i < _selectedPreset.frequenciesHz.length; i++) {
        final targetF = _selectedPreset.frequenciesHz[i];
        double diff = (targetF - currentPitch).abs();
        if ((targetF * 2 - currentPitch).abs() < diff) {
          diff = (targetF * 2 - currentPitch).abs();
        }
        if (diff < minDiff) {
          minDiff = diff;
          closestIdx = i;
        }
      }

      if (closestIdx == _lastCandidateIndex) {
        _candidateMatchCount++;
      } else {
        _lastCandidateIndex = closestIdx;
        _candidateMatchCount = 1;
      }

      if (_candidateMatchCount >= 2 || _selectedNoteIndex < 0) {
        targetStringIndex = closestIdx;
      }
    }

    final targetFreq = _selectedPreset.frequenciesHz[targetStringIndex];
    final cents = (1200 * (math.log(currentPitch / targetFreq) / math.ln2)).clamp(-50.0, 50.0);

    setState(() {
      _selectedNoteIndex = targetStringIndex;
      _detectedHz = currentPitch;
      _tuneCentsOffset = cents;
      _detectedNoteName = exactNoteName;
    });
  }

  void _startMicPitchDetector() {
    listenToPitch((pitchHz) {
      _processPitchInput(pitchHz);
    });
  }

  void _playReferenceTone() {
    prepareAudioContext();
    final freq = _selectedPreset.frequenciesHz[_selectedNoteIndex];
    setState(() {
      _isPlayingReferenceTone = true;
      _tuneCentsOffset = 0.0;
      _detectedHz = freq;
    });

    playTonePitch(freq, durationSeconds: 2.5);

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _isPlayingReferenceTone = false;
        });
      }
    });
  }

  Color _getTuningColor(double offsetCents) {
    if (_detectedHz <= 30.0) return Colors.grey;
    final absOffset = offsetCents.abs();
    if (absOffset < 5) {
      return const Color(0xFF10B981); // Verde (AFINADO)
    } else if (absOffset < 15) {
      return const Color(0xFFF59E0B); // Ámbar / Amarillo (CERCA)
    } else {
      return const Color(0xFFEF4444); // Rojo (DESAFINADO)
    }
  }

  String _getTuningStatusInstruction(double offsetCents) {
    if (_detectedHz <= 30.0) return '🎙️ Haz sonar una cuerda frente al micrófono...';
    if (offsetCents.abs() < 5) {
      return '🎯 Perfecto • Cuerda Afinada';
    } else if (offsetCents > 0) {
      return '🔴 Demasiado Alto! Afloje la cuerda';
    } else {
      return '🔴 Demasiado Bajo! Apriete la cuerda';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentNoteFull = _selectedPreset.notes[_selectedNoteIndex];
    final currentTargetFreq = _selectedPreset.frequenciesHz[_selectedNoteIndex];
    final noteSymbol = _detectedHz > 30.0
        ? _detectedNoteName.split(' ')[0]
        : currentNoteFull.split(' ').last.replaceAll('(', '').replaceAll(')', '');
    final tuningColor = _getTuningColor(_tuneCentsOffset);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TuningForkIcon(size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Afinador Cromático Profesional',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isAutoMode = !_isAutoMode;
              });
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isAutoMode
                      ? '🤖 Modo Auto Inteligente: Detecta automáticamente la cuerda que tocas.'
                      : '👆 Modo Manual Fijo: Toca la cuerda deseada en la lista.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(
              _isAutoMode ? Icons.auto_awesome_rounded : Icons.touch_app_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            label: Text(
              _isAutoMode ? 'AUTO' : 'MANUAL',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Permiso Micrófono
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _hasMicrophonePermission
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _hasMicrophonePermission
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : Colors.amber,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasMicrophonePermission ? Icons.mic_rounded : Icons.mic_off_rounded,
                    size: 16,
                    color: _hasMicrophonePermission ? const Color(0xFF10B981) : Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasMicrophonePermission
                          ? (_isAutoMode ? '🤖 Detección Auto Inteligente • Captando Sonido Real' : '🎙️ Micrófono Escuchando en Vivo')
                          : '⚠️ Permiso de Micrófono Requerido',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _hasMicrophonePermission
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selector de Instrumento con Tarjetas de Alto Contraste 100% Visibles
            Container(
              height: 52,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kInstrumentPresets.length,
                itemBuilder: (context, index) {
                  final preset = kInstrumentPresets[index];
                  final isSelected = preset.name == _selectedPreset.name;

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _selectedPreset = preset;
                            _selectedNoteIndex = 0;
                            _pitchHistory.clear();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.primary.withValues(alpha: 0.85),
                                    ],
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : (isDark ? const Color(0xFF1E293B) : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : (isDark ? Colors.white24 : Colors.black12),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                preset.icon,
                                size: 18,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? theme.colorScheme.primary : Colors.black87),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                preset.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Selector de Cuerdas del Instrumento
            Container(
              height: 40,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedPreset.notes.length,
                itemBuilder: (context, index) {
                  final noteStr = _selectedPreset.notes[index];
                  final isNoteSelected = index == _selectedNoteIndex;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: isNoteSelected,
                      showCheckmark: false,
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                      label: Text(
                        noteStr,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: isNoteSelected ? FontWeight.bold : FontWeight.w500,
                          color: isNoteSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedNoteIndex = index;
                            _isAutoMode = false;
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            const Spacer(),

            // Puntero y Visualización de la Nota
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: tuningColor.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: tuningColor.withValues(alpha: 0.6),
                  width: 2.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cuerda Seleccionada / Detectada
                  Text(
                    'Cuerda Target: $currentNoteFull (${currentTargetFreq.toStringAsFixed(1)} Hz)',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Círculo Grande con el Símbolo de la Nota
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tuningColor.withValues(alpha: 0.15),
                      border: Border.all(color: tuningColor, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: tuningColor.withValues(alpha: 0.35),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            noteSymbol,
                            style: GoogleFonts.outfit(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: tuningColor,
                            ),
                          ),
                          if (_detectedHz > 30.0)
                            Text(
                              '${_detectedHz.toStringAsFixed(1)} Hz',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Mensaje de Instrucción
                  Text(
                    _getTuningStatusInstruction(_tuneCentsOffset),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: tuningColor,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Indicador de Aguja Dial (-50 a +50 cents)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.red,
                              Colors.amber,
                              Color(0xFF10B981),
                              Colors.amber,
                              Colors.red,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 60),
                        alignment: Alignment((_tuneCentsOffset / 50.0).clamp(-1.0, 1.0), 0),
                        child: Container(
                          height: 26,
                          width: 6,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.black87, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Botón Tono de Referencia
                  ElevatedButton.icon(
                    onPressed: _playReferenceTone,
                    icon: Icon(
                      _isPlayingReferenceTone ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _isPlayingReferenceTone
                          ? 'Reproduciendo Tono Real...'
                          : 'Escuchar Tono de Referencia',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
