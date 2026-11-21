import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feature_guide_screen.dart';
import 'web_helper.dart' if (dart.library.html) 'web_helper_web.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _hasRedirected = false;
  late AnimationController _glowController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
    });

    // Duración ágil de 1.4s (equilibrio perfecto entre elegancia visual y rapidez)
    _timer = Timer(const Duration(milliseconds: 1400), _navigateToHome);
  }

  Future<void> _navigateToHome() async {
    if (_hasRedirected || !mounted) return;
    _hasRedirected = true;
    _timer?.cancel();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final lastHymnId = prefs.getString('last_hymn_id');
      final lastHymnTime = prefs.getInt('last_hymn_time') ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastHymnTime;
      // Si el usuario estaba viendo un himno hace menos de 2 horas (e.g. app en segundo plano)
      if (lastHymnId != null &&
          lastHymnId.isNotEmpty &&
          elapsed < 2 * 60 * 60 * 1000) {
        context.go('/home/hymn/$lastHymnId');
        return;
      }
      final seenGuide = prefs.getBool(kFeatureGuideSeenKey) ?? false;
      if (!seenGuide) {
        context.go('/guide?onboarding=1');
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    context.go('/home');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Deep slate black
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToHome, // Tap to skip instantáneo
        child: SizedBox.expand(
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
                ).animate().fadeIn(delay: 150.ms, duration: 600.ms),
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
                ).animate().fadeIn(delay: 250.ms, duration: 600.ms),
              ),

              // Contenido Central
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Alineación de los dos logos
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        final glow1 = const Color(0xFF6366F1).withValues(
                            alpha: 0.15 + (_glowController.value * 0.25));
                        final glow2 = const Color(0xFFEC4899).withValues(
                            alpha: 0.1 + (_glowController.value * 0.2));

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo Misión (Izquierda)
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: glow1,
                                    blurRadius:
                                        30 + (_glowController.value * 15),
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                'assets/images/mission_logo_v3.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.church_rounded,
                                        size: 42, color: Colors.indigo),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Logo Iglesia (Derecha)
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: glow2,
                                    blurRadius:
                                        30 + (_glowController.value * 15),
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                'assets/images/church_logo_clean.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.music_note_rounded,
                                        size: 42, color: Colors.indigo),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                        .scaleXY(
                            begin: 0.88,
                            end: 1.0,
                            duration: 500.ms,
                            curve: Curves.easeOutBack),

                    const SizedBox(height: 48),

                    // Texto Principal
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
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(
                            begin: 0.15,
                            end: 0,
                            duration: 400.ms,
                            curve: Curves.easeOutCubic),

                    const SizedBox(height: 6),

                    // Cancionero
                    Text(
                      'Cancionero Digital 2026',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        color: Colors.amber[400],
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms)
                        .slideY(
                            begin: 0.2,
                            end: 0,
                            duration: 400.ms,
                            curve: Curves.easeOutCubic),

                    const SizedBox(height: 20),

                    // Iglesia Info
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Iglesia Primera',
                          style: GoogleFonts.nunito(
                            fontSize: 17,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'San Bernardo',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(delay: 350.ms, duration: 400.ms)
                        .slideY(
                            begin: 0.2,
                            end: 0,
                            duration: 400.ms,
                            curve: Curves.easeOutCubic),

                    const Spacer(flex: 2),

                    // Indicador sutil de carga
                    SizedBox(
                      width: 90,
                      height: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const LinearProgressIndicator(
                          backgroundColor: Colors.white10,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                    const SizedBox(height: 14),
                    Text(
                      'Desarrollado por David Trureo Ahumada',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
