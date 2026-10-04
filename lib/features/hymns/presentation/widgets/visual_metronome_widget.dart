import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/app_music_icons.dart';
import 'metronome_audio_synth.dart';

class VisualMetronomeWidget extends StatefulWidget {
  final int hymnId;
  final int initialBpm;
  final bool isTopPosition;
  final bool isVerticalLayout;
  final VoidCallback onClose;
  final VoidCallback onTogglePosition;
  final VoidCallback onToggleOrientation;

  const VisualMetronomeWidget({
    super.key,
    required this.hymnId,
    this.initialBpm = 80,
    this.isTopPosition = true,
    this.isVerticalLayout = false,
    required this.onClose,
    required this.onTogglePosition,
    required this.onToggleOrientation,
  });

  @override
  State<VisualMetronomeWidget> createState() => _VisualMetronomeWidgetState();
}

class _VisualMetronomeWidgetState extends State<VisualMetronomeWidget> with SingleTickerProviderStateMixin {
  late int _bpm;
  bool _isPlaying = false;
  bool _soundEnabled = true;
  int _beatsPerMeasure = 4; // Métrica por defecto 4/4
  int _subdivision = 1; // 1=Negras, 2=Corcheas, 3=Tresillos, 4=Semicorcheas
  int _beatCount = 0;
  int _subTick = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  final List<DateTime> _tapTimes = [];

  @override
  void initState() {
    super.initState();
    _bpm = widget.initialBpm;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _loadSavedBpm();
  }
  
  Future<void> _loadSavedBpm() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBpm = prefs.getInt('metronome_bpm_${widget.hymnId}');
    if (savedBpm != null && mounted) {
      setState(() {
        _bpm = savedBpm;
      });
    }
  }

  Future<void> _saveBpm(int bpmToSave) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('metronome_bpm_${widget.hymnId}', bpmToSave);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    prepareAudioContext();
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _beatCount = 0;
        _subTick = 0;
        _playClickSound(isMainBeat: true);
        _pulseController.forward(from: 0.0).then((_) {
          if (mounted) _pulseController.reverse();
        });
        _subTick++;
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _playClickSound({required bool isMainBeat}) {
    if (isMainBeat) {
      final isAccent = _beatsPerMeasure > 1 && (_beatCount % _beatsPerMeasure) == 0;
      playAudioTick(soundEnabled: _soundEnabled, accent: isAccent, subdivision: false);
    } else {
      playAudioTick(soundEnabled: _soundEnabled, accent: false, subdivision: true);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final intervalMs = (60000 / _bpm / _subdivision).round();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (mounted && _isPlaying) {
        bool isMainBeat = (_subTick % _subdivision) == 0;
        
        setState(() {
          if (isMainBeat) {
            _beatCount++;
          }
        });
        
        _playClickSound(isMainBeat: isMainBeat);
        
        if (isMainBeat) {
          _pulseController.forward(from: 0.0).then((_) {
            if (mounted) _pulseController.reverse();
          });
        }
        
        _subTick++;
      }
    });
  }

  void _setBpm(int newBpm) {
    setState(() {
      _bpm = newBpm.clamp(40, 240);
      _saveBpm(_bpm);
      if (_isPlaying) {
        _startTimer();
      }
    });
  }

  void _handleTapTempo() {
    prepareAudioContext();
    final now = DateTime.now();

    // 1. Si pasaron más de 2.5s desde la última pulsación, reiniciar registro TAP
    if (_tapTimes.isNotEmpty && now.difference(_tapTimes.last).inMilliseconds > 2500) {
      _tapTimes.clear();
    }

    _tapTimes.add(now);

    if (_tapTimes.length > 4) {
      _tapTimes.removeAt(0);
    }

    // 2. Animación de pulso visual inmediata al pulsar TAP
    _pulseController.forward(from: 0.0).then((_) {
      if (mounted) _pulseController.reverse();
    });

    // 3. Emitir el golpe de audio en el momento exacto del toque de TAP
    _playClickSound(isMainBeat: true);

    if (_tapTimes.length >= 2) {
      final differences = <int>[];
      for (int i = 0; i < _tapTimes.length - 1; i++) {
        differences.add(_tapTimes[i + 1].difference(_tapTimes[i]).inMilliseconds);
      }
      final avgDifference = differences.reduce((a, b) => a + b) / differences.length;
      if (avgDifference > 0) {
        final calculatedBpm = (60000 / avgDifference).round().clamp(40, 240);
        setState(() {
          _bpm = calculatedBpm;
          _saveBpm(_bpm);
          if (_isPlaying) {
            // Cancelar el temporizador anterior y reiniciar desde cero para evitar mezclas o solapamientos
            _timer?.cancel();
            _beatCount = 0;
            _startTimer();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseColor = Color.lerp(
          isDark ? const Color(0xFF1E293B) : Colors.white,
          theme.colorScheme.primary.withValues(alpha: 0.35),
          _pulseController.value,
        );

        if (widget.isVerticalLayout) {
          // Barra Vertical Lateral Compacta 100% Contenida
          return Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(20),
            color: Colors.transparent,
            child: Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: pulseColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3 * _pulseController.value),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Play / Pause
                  IconButton.filledTonal(
                    icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24),
                    onPressed: _togglePlay,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.25),
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  GestureDetector(
                    onTap: _handleTapTempo,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        Text(
                          '$_bpm',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'BPM',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Selector de Métrica en Modo Vertical
                  DropdownButton<int>(
                    value: _beatsPerMeasure,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down_rounded, size: 14),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: theme.colorScheme.primary,
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1/1')),
                      DropdownMenuItem(value: 2, child: Text('2/4')),
                      DropdownMenuItem(value: 3, child: Text('3/4')),
                      DropdownMenuItem(value: 4, child: Text('4/4')),
                      DropdownMenuItem(value: 5, child: Text('5/4')),
                      DropdownMenuItem(value: 6, child: Text('6/8')),
                      DropdownMenuItem(value: 9, child: Text('9/8')),
                      DropdownMenuItem(value: 12, child: Text('12/8')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _beatsPerMeasure = val;
                          _beatCount = 0;
                        });
                      }
                    },
                  ),
                  
                  // Selector de Subdivisión en Modo Vertical
                  DropdownButton<int>(
                    value: _subdivision,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down_rounded, size: 14),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: theme.colorScheme.primary,
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1/4')),
                      DropdownMenuItem(value: 2, child: Text('1/8')),
                      DropdownMenuItem(value: 3, child: Text('3/8')),
                      DropdownMenuItem(value: 4, child: Text('1/16')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _subdivision = val;
                          _subTick = 0;
                          if (_isPlaying) _startTimer();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 6),

                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                    onPressed: () => _setBpm(_bpm + 2),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                    onPressed: () => _setBpm(_bpm - 2),
                  ),
                  const Divider(height: 12),

                  // Position / Orientation / Sound / Close Toggles
                  IconButton(
                    icon: Icon(
                      widget.isTopPosition ? Icons.vertical_align_bottom_rounded : Icons.vertical_align_top_rounded,
                      size: 18,
                    ),
                    tooltip: widget.isTopPosition ? 'Mover Abajo' : 'Mover Arriba',
                    onPressed: widget.onTogglePosition,
                  ),
                  IconButton(
                    icon: const Icon(Icons.view_headline_rounded, size: 18),
                    tooltip: 'Modo Horizontal',
                    onPressed: widget.onToggleOrientation,
                  ),
                  IconButton(
                    icon: Icon(
                      _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      size: 18,
                      color: _soundEnabled ? theme.colorScheme.primary : Colors.grey,
                    ),
                    onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
          );
        }

        // Modo Horizontal 100% Contenido con Botones Fijos a la Derecha
        return Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pulseColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3 * _pulseController.value),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Row(
              children: [
                // Play / Pause (Fijo a la Izquierda)
                IconButton.filledTonal(
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 22),
                  onPressed: _togglePlay,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.25),
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),

                // Controles Centrales Desplazables (BPM, Métrica, -/+, TAP, Posición, Orientación)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _handleTapTempo,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_bpm',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'BPM',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Selector de Métrica
                        DropdownButton<int>(
                          value: _beatsPerMeasure,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down_rounded, size: 16),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1/1')),
                            DropdownMenuItem(value: 2, child: Text('2/4')),
                            DropdownMenuItem(value: 3, child: Text('3/4')),
                            DropdownMenuItem(value: 4, child: Text('4/4')),
                            DropdownMenuItem(value: 5, child: Text('5/4')),
                            DropdownMenuItem(value: 6, child: Text('6/8')),
                            DropdownMenuItem(value: 9, child: Text('9/8')),
                            DropdownMenuItem(value: 12, child: Text('12/8')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _beatsPerMeasure = val;
                                _beatCount = 0;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 2),

                        // Selector de Subdivisión en Modo Horizontal
                        DropdownButton<int>(
                          value: _subdivision,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down_rounded, size: 16),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1/4')),
                            DropdownMenuItem(value: 2, child: Text('1/8')),
                            DropdownMenuItem(value: 3, child: Text('3/8')),
                            DropdownMenuItem(value: 4, child: Text('1/16')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _subdivision = val;
                                _subTick = 0;
                                if (_isPlaying) _startTimer();
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 2),

                        // Botones Ajuste - / +
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          onPressed: () => _setBpm(_bpm - 2),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          onPressed: () => _setBpm(_bpm + 2),
                        ),
                        const SizedBox(width: 4),

                        // Cambiar Posición (Arriba / Abajo)
                        IconButton(
                          icon: Icon(
                            widget.isTopPosition ? Icons.vertical_align_bottom_rounded : Icons.vertical_align_top_rounded,
                            size: 18,
                          ),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          tooltip: widget.isTopPosition ? 'Mover Abajo' : 'Mover Arriba',
                          onPressed: widget.onTogglePosition,
                        ),

                        // Cambiar Orientación (Vertical / Horizontal)
                        IconButton(
                          icon: const Icon(Icons.view_column_rounded, size: 18),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          tooltip: 'Modo Vertical Lateral',
                          onPressed: widget.onToggleOrientation,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 2),

                // Icono de Sonido (Fijo a la Derecha dentro del Cuadro)
                IconButton(
                  icon: Icon(
                    _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    size: 18,
                    color: _soundEnabled ? theme.colorScheme.primary : Colors.grey,
                  ),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  tooltip: _soundEnabled ? 'Silenciar Beat' : 'Activar Sonido Beat',
                  onPressed: () {
                    setState(() {
                      _soundEnabled = !_soundEnabled;
                    });
                  },
                ),

                // Botón Rojo Fijo Cerrar X (Fijo a la Derecha dentro del Cuadro)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
