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
    title: 'Más de 2.990 cantos siempre contigo',
    description:
        'Accede al repertorio oficial de la IUMP al instante, 100% disponible sin conexión a internet durante el servicio.',
    bullets: [
      'Búsqueda inteligente: encuentra cantos por número, título, frases de la letra o temática con IA (ej: "fe en la prueba", "Pedro en el mar").',
      'Himnario Oficial IUMP, Alabanzas Especiales y Coros de Avivamiento completos y offline.',
      'Historial Inteligente en Inicio: retoma al instante los cantos entonados en el culto con el tono musical que utilizaste.',
      'Favoritos instantáneos: guarda y organiza tus himnos y alabanzas predilectos con un solo toque.',
    ],
    icon: Icons.auto_awesome_rounded,
    accentColor: Color(0xFF38BDF8),
  ),
  _GuideSlide(
    audience: 'Lectura en el Altar y Coro',
    title: 'Lectura fluida y Modo Atril',
    description:
        'Diseñado para cantar y ministrar con total comodidad en el púlpito, coro o bancas sin toques accidentales.',
    bullets: [
      'Navegación por deslizamiento: desliza a la izquierda o derecha para pasar al canto anterior o siguiente con suavidad.',
      'Fijar canto en pantalla: bloquea el gesto táctil cuando estés en el púlpito para evitar cambios involuntarios de página.',
      'Modo Atril / Culto: lectura a pantalla completa sin distracciones, ideal para apoyar tu dispositivo en el atril de adoración.',
      'Ajuste personalizado de tamaño de letra y brillo, memorizados automáticamente para proteger tu vista.',
    ],
    icon: Icons.menu_book_rounded,
    accentColor: Color(0xFF818CF8),
  ),
  _GuideSlide(
    audience: 'Músicos, Coro y Directores',
    title: 'Partituras HD, Acordes y Diagramas',
    description:
        'Herramientas profesionales para ensayar, transportar tonalidades y visualizar partituras musicales oficiales.',
    bullets: [
      'Visor de Partituras Oficiales: previsualización de alta definición de la música original de cada alabanza y coro.',
      'Zoom interactivo y paginación: pellizca o haz doble toque para ampliar notas y compases con navegación por páginas.',
      'Diagramas de Acordes al instante: toca cualquier acorde en la letra para ver la posición exacta en guitarra y teclas de piano.',
      'Transposición y Metrónomo: transporta tonos en semitonos (+/-) al vuelo y ensaya con guía de tempo visual y auditiva.',
    ],
    icon: Icons.queue_music_rounded,
    accentColor: Color(0xFF10B981),
  ),
  _GuideSlide(
    audience: 'Compartir e Imprimir',
    title: 'Partituras y PDF en Formato Carta',
    description:
        'Comparte partituras e imprime programas de culto con diagramación profesional optimizada para impresoras.',
    bullets: [
      'Compartir Partituras al instante: botón nativo optimizado para enviar la música por WhatsApp, AirDrop o correo en Android e iPadOS.',
      'Formato Carta (Letter) automático: documentos PDF ajustados a las dimensiones estándar de papel sin cortes de márgenes.',
      'Exportación versátil: genera PDF con acordes para los instrumentistas o en formato "Solo Letra" para la congregación.',
      'Impresión de programas completos: imprime repertorios enteros desde Listas con opción de 1 o 2 cantos por hoja.',
    ],
    icon: Icons.picture_as_pdf_rounded,
    accentColor: Color(0xFFF43F5E),
  ),
  _GuideSlide(
    audience: 'Músicos y Alabanza en Vivo',
    title: 'Culto en Vivo y Modo Director QR',
    description:
        'Sincroniza a los instrumentistas, coro y congregación para cantar en perfecta armonía durante el servicio.',
    bullets: [
      'Modo Director con Código QR: genera una sala en vivo para que el coro y los músicos se sincronicen al instante desde el altar.',
      'Sincronización en tiempo real: los dispositivos conectados siguen automáticamente el cambio de cantos y el avance de estrofas.',
      'Listas de Culto (Setlists): organiza el programa completo de alabanzas del domingo, expórtalo a PDF o compártelo en la nube.',
      'Himnario Web Oficial: enlace interactivo universal accesible desde navegadores en computadoras o iPhone sin instalar nada.',
    ],
    icon: Icons.qr_code_scanner_rounded,
    accentColor: Color(0xFFEAB308),
  ),
  _GuideSlide(
    audience: 'Multimedia y Pantallas Gigantes',
    title: 'Las 2 Formas de Proyectar (PC vs TV)',
    description:
        'Proyecta las letras en el templo con dos métodos adaptados a la tecnología de tu congregación.',
    bullets: [
      'Modo 1: Proyector Directo (PC/Mac/OBS): ideal con cable HDMI. Desde el canto elige "Modo Proyector (PC/Mac)" y pulsa "Despegar Proyector" para abrir una ventana limpia en la segunda pantalla.',
      'Modo 2: Control Remoto en Vivo (Smart TV): ideal para proyectar sin cables. En la TV abre himnario-vito-2026.web.app/tv, mira el código de 4 dígitos y contrólalo desde tu celular caminando por el templo.',
      'Ventana Despegada Independiente: proyección 100% limpia sin barras, menús ni botones visibles para la congregación.',
      'Pantalla Negra (Blackout) en 1 toque: oculta la letra al instante durante la oración o la predicación sin apagar el proyector.',
    ],
    icon: Icons.tv_rounded,
    accentColor: Color(0xFF0EA5E9),
  ),
  _GuideSlide(
    audience: 'Edición y Asistencia IA',
    title: 'Escáner IA, Corrector y Secciones',
    description:
        'Digitaliza cantos físicos y perfecciona las letras con herramientas avanzadas de inteligencia artificial.',
    bullets: [
      'Escáner Inteligente con IA: toma una foto a cualquier cancionero o papel impreso y transcríbelo con letra y acordes limpios.',
      'Corrector Ortográfico con IA: detecta y corrige automáticamente tildes, mayúsculas, puntuación y rima litúrgica.',
      'Nuevas indicaciones litúrgicas: soporte oficial para secciones de "Recitado", "Pre-coro" y estrofas numeradas (1, 2, 3...).',
      'Auditoría y sugerencias: envía nuevos cantos o mejoras al catálogo para revisión y aprobación del administrador.',
    ],
    icon: Icons.auto_fix_high_rounded,
    accentColor: Color(0xFF8B5CF6),
  ),
  _GuideSlide(
    audience: 'Administración y Liderazgo',
    title: 'Panel Ejecutivo y Métricas en Vivo',
    description:
        'Supervisa la adopción congregacional, el repertorio oficial y la salud técnica de todo el ecosistema.',
    bullets: [
      'Pulso del Himnario en Tiempo Real: total de instalaciones registradas, cantos catalogados y usuarios activos del último mes.',
      'Ecosistema y Distribución: visualización proporcional de la comunidad en Android, iOS / iPad y la versión Himnario Web.',
      'Salud y Retención Congregacional: índice de actividad continua que supera el 96% de fidelidad de uso en el culto.',
      'Adopción de Versiones: control de actualizaciones con insignias inteligentes "OFICIAL AL DÍA" y auditoría técnica de dispositivos.',
    ],
    icon: Icons.analytics_rounded,
    accentColor: Color(0xFF06B6D4),
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
