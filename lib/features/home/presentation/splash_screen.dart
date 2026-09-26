import 'package:flutter/foundation.dart';
import 'web_helper.dart' if (dart.library.html) 'web_helper_web.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import '../../hymns/presentation/widgets/metronome_audio_synth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  AudioPlayer? _player;
  bool _hasRedirected = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        final String hash = initialWebHash;
        if (hash.startsWith('#/')) {
          final path = hash.substring(1); 
          if (path.isNotEmpty && path != '/') {
            _hasRedirected = true;
            context.go(path);
            return; 
          }
        }
      }
      _playSplashSound();
    });

    // Aumentamos a 3.5s para apreciar la animacion
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted && !_hasRedirected) {
        context.go('/home');
      }
    });
  }

  Future<void> _playSplashSound() async {
    try {
      prepareAudioContext();
      _player = AudioPlayer();
      await _player!.setAsset('assets/audio/ivan_luzan-beautiful-piano.mp3');
      await _player!.setVolume(1.0);
      await _player!.play();
    } catch (e) {
      debugPrint('>>> Autoplay del navegador omitido o audio no disponible: $e');
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _player?.stop();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Deep slate black
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Auroras decorativas difuminadas
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ).animate()
               .fadeIn(delay: 500.ms, duration: 1500.ms),
            ),
            Positioned(
              bottom: -150,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ).animate()
               .fadeIn(delay: 800.ms, duration: 1500.ms),
            ),
            
            // Contenido Central
            SafeArea(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                
                // Alineacion de los dos logos
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    final glow1 = const Color(0xFF6366F1).withValues(alpha: 0.15 + (_glowController.value * 0.25));
                    final glow2 = const Color(0xFFEC4899).withValues(alpha: 0.1 + (_glowController.value * 0.2));
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo Misión (Izquierda)
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: glow1, blurRadius: 30 + (_glowController.value * 15), offset: const Offset(0, 5)),
                            ],
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/images/mission_logo_v3.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.church_rounded, size: 42, color: Colors.indigo),
                          ),
                        ),
                        const SizedBox(width: 25),
                        // Logo Iglesia (Derecha)
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: glow2, blurRadius: 30 + (_glowController.value * 15), offset: const Offset(0, 5)),
                            ],
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/images/church_logo_clean.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note_rounded, size: 42, color: Colors.indigo),
                          ),
                        ),
                      ],
                    );
                  },
                )
                .animate()
                .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                .scaleXY(begin: 0.8, end: 1.0, duration: 1000.ms, curve: Curves.elasticOut)
                .then(delay: 1200.ms)
                .moveY(begin: 0, end: -10, duration: 800.ms, curve: Curves.easeInOut),
                
                const SizedBox(height: 64),
                
                // Texto Principal
                Text(
                  'HIMNARIO IUMP',
                  style: GoogleFonts.outfit(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                )
                .animate()
                .fadeIn(delay: 600.ms, duration: 800.ms)
                .shimmer(delay: 1200.ms, duration: 1500.ms, color: Colors.white54)
                .slideY(begin: 0.2, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),
                
                const SizedBox(height: 8),
                
                // Cancionero
                Text(
                  'Cancionero Digital 2026',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.amber[400],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                )
                .animate()
                .fadeIn(delay: 1000.ms, duration: 800.ms)
                .slideY(begin: 0.3, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),
                
                const SizedBox(height: 24),
                
                // Iglesia Info
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Iglesia Primera',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'San Bernardo',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
                .animate()
                .fadeIn(delay: 1200.ms, duration: 800.ms)
                .slideY(begin: 0.5, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),
                
                const Spacer(flex: 2),
                
                // Indicador de carga
                SizedBox(
                  width: 100,
                  height: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  ),
                ).animate().fadeIn(delay: 1800.ms, duration: 600.ms),
                
                const SizedBox(height: 20),
                Text(
                  'Desarrollado por David Trureo Ahumada',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ).animate().fadeIn(delay: 2000.ms, duration: 600.ms),
                
                const SizedBox(height: 64),
              ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
