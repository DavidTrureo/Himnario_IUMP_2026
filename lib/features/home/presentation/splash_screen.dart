import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navegar a la pantalla principal después de 3 segundos
    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)], // Fondo oscuro premium
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
                  
                  // 1. Ambos Logos en el Centro (Misión y Iglesia Local)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo de la Misión (IUMP)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/mission_logo_v3.png',
                            height: 130,
                            width: 130,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Logo de la Iglesia Local (Vitral y Cruz - Sin Texto para el Círculo)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/church_logo_clean.png',
                            height: 130,
                            width: 130,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
                  
                  const SizedBox(height: 32),
                  
                  // Texto de la misión
                  Text(
                    'Himnario Oficial',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: Colors.white38,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 4),
                  Text(
                    'IGLESIA UNIDA\nMETODISTA PENTECOSTAL',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                      height: 1.2,
                    ),
                  ).animate().fadeIn(delay: 800.ms),
                  
                  const SizedBox(height: 24),
                  
                  // Identificación de la Iglesia Local
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
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.white24,
                      fontWeight: FontWeight.w600,
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
