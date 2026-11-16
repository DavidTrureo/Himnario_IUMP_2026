import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kFeatureGuideSeenKey = 'feature_guide_seen_v1';

class _GuideSlide {
  final String audience;
  final String title;
  final String description;
  final List<String> bullets;
  final IconData icon;
  final Color accentColor;

  const _GuideSlide({
    required this.audience,
    required this.title,
    required this.description,
    required this.bullets,
    required this.icon,
    required this.accentColor,
  });
}

const List<_GuideSlide> _kGuideSlides = [
  _GuideSlide(
    audience: 'Congregación y Culto',
    title: 'Más de 2.900 cantos siempre contigo',
    description:
        'Encuentra cualquier himno o alabanza al instante, incluso sin conexión a internet durante el servicio.',
    bullets: [
      'Búsqueda inteligente: por número, título, frase de la letra o temática con IA (ej: "fe en la prueba", "Pedro en el mar").',
      'Historial Inteligente en Inicio: retoma al instante los cantos entonados en el culto con su tono guardado.',
      'Himnario IUMP, Alabanzas Especiales y Coros de Avivamiento disponibles 100% offline.',
      'Guarda tus himnos y alabanzas más entonados en Favoritos con un solo toque.',
    ],
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFF38BDF8),
  ),
  _GuideSlide(
    audience: 'Lectura en el culto',
    title: 'Desliza y fija el canto en pantalla',
    description:
        'Diseñado para leer con total comodidad en el púlpito, coro o bancas sin toques accidentales.',
    bullets: [
      'Desliza a la izquierda o derecha para hojear con fluidez al canto anterior o siguiente.',
      'Activa "Fijar canto" cuando estés en el púlpito para bloquear el deslizamiento involuntario.',
      'Gestos rápidos Swipe: en tus Listas, desliza un canto hacia el costado para agregarlo a otro repertorio o retirarlo.',
      'Ajusta el tamaño de letra a tu vista con guardado automático permanente.',
    ],
    icon: Icons.swipe_rounded,
    accentColor: Color(0xFF818CF8),
  ),
  _GuideSlide(
    audience: 'Músicos y Coro',
    title: 'Acordes, tono ajustable y partituras',
    description:
        'Todo lo necesario para ensayar, acompañar y ministrar con tu instrumento en un solo lugar.',
    bullets: [
      'Transposición instantánea de tono y alternancia entre notación C D E y Do Re Mi.',
      'Mini-reproductor persistente: escucha el audio con controles de retroceso (-10s / +10s) y bucle.',
      'Modo Atril / Culto: pantalla completa sin distracciones para apoyar tu dispositivo en el atril.',
      'Visualiza Partitura Oficial (cuando esté disponible) o accede al video de YouTube integrado.',
    ],
    icon: Icons.music_note_rounded,
    accentColor: Color(0xFF10B981),
  ),
  _GuideSlide(
    audience: 'Compartir e Imprimir',
    title: 'Exportación a PDF con o sin acordes',
    description:
        'Comparte por WhatsApp o imprime cantos y programas de culto al instante con diseño profesional.',
    bullets: [
      'Envío directo por WhatsApp o impresión con 1 toque sin saturar la memoria con archivos temporales.',
      'Exporta en PDF profesional: con acordes para músicos o formato "Solo letra" para la congregación.',
      'Desde Listas, imprime el programa completo del servicio con 1 o 2 cantos por página optimizados.',
      'Diseño limpio y autoajustable que evita cortar estrofas o desbordar la hoja de papel.',
    ],
    icon: Icons.picture_as_pdf_rounded,
    accentColor: Color(0xFFF43F5E),
  ),
  _GuideSlide(
    audience: 'Culto en Vivo',
    title: 'Repertorios sincronizados en vivo',
    description:
        'Prepara el orden del servicio y conéctate en tiempo real con músicos y la congregación.',
    bullets: [
      'Organiza listas ordenadas para cultos y ensayos en la pestaña "Listas".',
      'Modo Director: proyecta el código QR para que músicos y hermanos se sincronicen al servicio.',
      'Unirme a Culto en Vivo (en pestaña Más): los asistentes escanean el QR y su pantalla avanza sola con el director.',
      'Sincronización fluida en tiempo real para cantar al unísono sin buscar canto por canto.',
    ],
    icon: Icons.qr_code_2_rounded,
    accentColor: Color(0xFFF59E0B),
  ),
  _GuideSlide(
    audience: 'Proyección y Herramientas',
    title: 'TV / Proyector, Escáner IA y Web',
    description:
        'Herramientas avanzadas en la pestaña "Más" para proyectar y enriquecer el servicio.',
    bullets: [
      'Pantalla de Proyección: abre el receptor en una Smart TV o PC con código de sala y contrólalo desde el móvil.',
      'Escáner Inteligente con IA: toma una foto de un cancionero o papel para transcribirlo a texto limpio y acordes.',
      'Himnario Web Oficial: comparte el enlace directo para usuarios de PC o dispositivos sin la app instalada.',
      'Sección "Nuestra Iglesia": consulta horarios, historia, ubicación del templo y canales oficiales.',
    ],
    icon: Icons.tv_rounded,
    accentColor: Color(0xFFEC4899),
  ),
];

class FeatureGuideScreen extends StatefulWidget {
  final bool isOnboarding;

  const FeatureGuideScreen({
    super.key,
    this.isOnboarding = false,
  });

  @override
  State<FeatureGuideScreen> createState() => _FeatureGuideScreenState();
}

class _FeatureGuideScreenState extends State<FeatureGuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kFeatureGuideSeenKey, true);
    } catch (_) {}

    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (widget.isOnboarding) {
        router.go('/home');
      } else if (router.canPop()) {
        router.pop();
      } else {
        router.go('/tools');
      }
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSlide = _kGuideSlides[_currentPage];
    final isLastPage = _currentPage == _kGuideSlides.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [Color(0xFF0F172A), Color(0xFF020617)]
                    : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -90,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: activeSlide.accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Guía rápida',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      TextButton(
                        onPressed: _finishGuide,
                        child: Text(
                          widget.isOnboarding ? 'Omitir' : 'Cerrar',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _kGuideSlides.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final slide = _kGuideSlides[index];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: slide.accentColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: slide.accentColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Icon(
                                  slide.icon,
                                  size: 46,
                                  color: slide.accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: slide.accentColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  slide.audience.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                    color: slide.accentColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  height: 1.18,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                slide.description,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Column(
                                children: slide.bullets
                                    .map(
                                      (bullet) => Padding(
                                        padding:
                                            const EdgeInsets.symmetric(vertical: 7),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 19,
                                              color: slide.accentColor,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                bullet,
                                                style: GoogleFonts.nunito(
                                                  fontSize: 14.5,
                                                  height: 1.38,
                                                  color: isDark
                                                      ? Colors.white.withValues(alpha: 0.9)
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _kGuideSlides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? activeSlide.accentColor
                                  : (isDark ? Colors.white24 : Colors.black26),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          if (_currentPage > 0) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Anterior'),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (isLastPage) {
                                  _finishGuide();
                                } else {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeSlide.accentColor,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                isLastPage
                                    ? (widget.isOnboarding
                                        ? '¡Listo, empezar!'
                                        : 'Entendido')
                                    : 'Siguiente',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
