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

class _SplashScreenState extends State<SplashScreen> {
  AudioPlayer? _player;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    // Iniciar audio asíncronamente respetando las políticas de Autoplay del navegador
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Manejar compatibilidad con enlaces antiguos (con #)
      if (kIsWeb) {
        final String hash = initialWebHash;
        if (hash.startsWith('#/')) {
          final path = hash.substring(1); // Quitamos el '#'
          if (path.isNotEmpty && path != '/') {
            _hasRedirected = true;
            context.go(path);
            return; // Detenemos la ejecución del splash y saltamos directo
          }
        }
      }

      // _playSplashSound();
    });

    // Auto-navegación automática después de 4.8s tanto en Web como en App Móvil
    Timer(const Duration(milliseconds: 2500), () {
      // Verificar de nuevo si se debe navegar al home o si ya redirigimos
      if (mounted && !_hasRedirected) {
        context.go('/home');
      }
    });
  }

  Future<void> _playSplashSound() async {
    try {
      prepareAudioContext();
      _player = AudioPlayer();
      await _player!.setAsset('assets/audio/splash_chime.mp3');
      await _player!.setVolume(0.85);
      await _player!.play();
    } catch (e) {
      debugPrint('>>> Autoplay del navegador omitido o audio no disponible: $e');
    }
  }

  @override
  void dispose() {
    _player?.stop();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          ),
        ),
        child: Stack(
          children: [
            // Auroras decorativas difuminadas
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            // Contenido Central
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  
                  // Alineación Horizontal de Ambos Logos (IZQUIERDA: Logo Oficial IUMP | DERECHA: Logo Primera San Bernardo)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Oficial IUMP (Izquierda) — fondo blanco para contraste
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          'assets/images/mission_logo_v3.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.church_rounded, size: 42, color: Colors.indigo),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Logo IUMP Primera en San Bernardo (Derecha) — fondo blanco para contraste
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC4899).withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
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
                  )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
                  
                  const SizedBox(height: 28),
                  
                  Text(
                    'HIMNARIO IUMP',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 400.ms)
                  .slideY(begin: 0.3, end: 0, duration: 600.ms),
                  
                  const SizedBox(height: 6),
                  
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
                  .fadeIn(delay: 700.ms),
                  
                  const SizedBox(height: 24),
                  
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
                  .fadeIn(delay: 1000.ms)
                  .slideY(begin: 0.2, end: 0, duration: 500.ms),
                  
                  const Spacer(),
                  
                  // Indicador de carga sutil
                  const SizedBox(
                    width: 32,
                    height: 3,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  ).animate().fadeIn(delay: 1200.ms),
                  
                  const SizedBox(height: 16),
                  Text(
                    'Desarrollado por David Trureo Ahumada',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white60,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ).animate().fadeIn(delay: 1400.ms),
                  
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
