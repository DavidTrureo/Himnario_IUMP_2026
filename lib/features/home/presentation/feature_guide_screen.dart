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
    audience: 'Congregación',
    title: 'Más de 2.900 cantos siempre contigo',
    description:
        'Encuentra rápidamente cualquier himno o alabanza, incluso sin internet durante el culto.',
    bullets: [
      'Busca por número, título, frase de la letra o por tema con IA.',
      'Guarda tus cantos preferidos en Favoritos con un toque.',
      'Consulta Himnario IUMP, Alabanzas Especiales y Coros de Avivamiento.',
    ],
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFF38BDF8),
  ),
  _GuideSlide(
    audience: 'Lectura en el culto',
    title: 'Desliza y fija el canto en pantalla',
    description:
        'Pensado para leer cómodo sin cambios accidentales mientras sostienes tu teléfono o iPad.',
    bullets: [
      'Desliza izquierda o derecha para hojear al canto anterior o siguiente.',
      'Activa "Fijar canto" cuando estés en el púlpito para bloquear el swipe.',
      'Ajusta el tamaño de letra a tu vista con persistencia automática.',
    ],
    icon: Icons.swipe_rounded,
    accentColor: Color(0xFF818CF8),
  ),
  _GuideSlide(
    audience: 'Músicos y Coro',
    title: 'Acordes, tono ajustable y partituras',
    description:
        'Todo lo necesario para ensayar y ministrar con instrumento en un solo lugar.',
    bullets: [
      'Cambia la tonalidad (transposición) y alterna notación C D E / Do Re Mi.',
      'Visualiza Partitura Oficial cuando esté disponible en el canto.',
      'Escucha el audio de referencia o abre el video de YouTube integrado.',
    ],
    icon: Icons.music_note_rounded,
    accentColor: Color(0xFF10B981),
  ),
  _GuideSlide(
    audience: 'Compartir e Imprimir',
    title: 'Hermoso diseño PDF: con o sin acordes',
    description:
        'Comparte por WhatsApp o imprime cantos y repertorios con diagramación editorial impecable.',
    bullets: [
      'Comparte cantos individuales en PDF con acordes y notas musicales o en modo "Solo letra".',
      'Desde Listas, imprime el programa completo con 1 y hasta 2 cantos por página.',
      'Diseño limpio, elegante y autoajustado sin cortar estrofas ni desbordar la hoja.',
    ],
    icon: Icons.picture_as_pdf_rounded,
    accentColor: Color(0xFFF43F5E),
  ),
  _GuideSlide(
    audience: 'Culto en Vivo',
    title: 'Listas de culto sincronizadas por QR',
    description:
        'Prepara el repertorio del servicio y compártelo en tiempo real con músicos y hermanos.',
    bullets: [
      'Crea listas ordenadas en la pestaña Listas para cada reunión.',
      'Inicia un Culto en Vivo y muestra el QR para que todos se unan.',
      'Al cambiar de canto como director, la pantalla de los conectados avanza contigo.',
    ],
    icon: Icons.qr_code_2_rounded,
    accentColor: Color(0xFFF59E0B),
  ),
  _GuideSlide(
    audience: 'Proyección y Herramientas',
    title: 'TV / PC, Escáner IA y Himnario Web',
    description:
        'Conecta pantallas grandes o digitaliza nuevos cantos en segundos desde Herramientas.',
    bullets: [
      'Usa Pantalla de Proyección en una TV o computador como receptor remoto.',
      'Transcribe un canto impreso tomando una foto con el Escáner Inteligente.',
      'Comparte el Himnario Web para abrirlo desde cualquier navegador.',
      'Revisa periódicamente Google Play para recibir nuevas mejoras y cantos actualizados.',
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
