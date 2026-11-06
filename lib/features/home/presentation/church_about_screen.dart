import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class ChurchAboutScreen extends StatelessWidget {
  const ChurchAboutScreen({super.key});

  static const String churchAddress = 'Vecinal Norte 740, El Bosque';
  static const String churchAddressFull = 'Vecinal Norte 740, El Bosque, Región Metropolitana, Chile';
  static const String youtubeUrl = 'https://youtube.com/@primeradesanbernardo?si=q_AxgRp8jPWItiW4';
  static const String instagramUrl = 'https://www.instagram.com/iglesia.primerasanbernardo?igsh=MTFoa2M4YjRiczVheg==';

  Future<void> _openChurchMap() async {
    final encodedQuery = Uri.encodeComponent(churchAddressFull);
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedQuery');
    final appleMapsUrl = Uri.parse('maps://?q=$encodedQuery');
    final appleMapsWebUrl = Uri.parse('https://maps.apple.com/?q=$encodedQuery');

    try {
      if (kIsWeb) {
        if (await canLaunchUrl(googleMapsUrl)) {
          await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
        }
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        if (await canLaunchUrl(appleMapsUrl)) {
          await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
          return;
        } else if (await canLaunchUrl(appleMapsWebUrl)) {
          await launchUrl(appleMapsWebUrl, mode: LaunchMode.externalApplication);
          return;
        }
      }
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error al abrir mapas: $e');
    }
  }

  void _copyAddress(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: churchAddressFull));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Dirección copiada al portapapeles',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error al abrir enlace: $e');
    }
  }

  void _showFullLogo(BuildContext context, String assetPath) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      pageBuilder: (context, anim1, anim2) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Hero(
                tag: assetPath,
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.asset(assetPath, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBgColor = isDark 
        ? const Color(0xFF1E293B).withValues(alpha: 0.72) 
        : Colors.white.withValues(alpha: 0.90);
    final cardBorderColor = isDark 
        ? Colors.white.withValues(alpha: 0.08) 
        : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Fondo base gradiente (idéntico al Home)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
              ),
            ),
          ),

          // 2. Círculo decorativo aurora superior derecha (Índigo)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF6366F1).withValues(alpha: 0.18)
                    : const Color(0xFF818CF8).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 3. Círculo decorativo aurora inferior izquierda (Ámbar eclesiástico)
          Positioned(
            bottom: 40,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.10)
                    : const Color(0xFFFBBF24).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 4. Círculo decorativo central suave (Rosa / Carmesí)
          Positioned(
            top: 380,
            left: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFFEC4899).withValues(alpha: 0.08)
                    : const Color(0xFFF472B6).withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 5. Contenido principal con SafeArea
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // AppBar personalizada y traslúcida
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: primaryTextColor,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Text(
                        'Nuestra Iglesia',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de contenido con padding inferior holgado para evitar el menú flotante
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
                        children: [
                          // ==========================================
                          // 1. HEADER INSTITUCIONAL (LOGOS Y TÍTULO)
                          // ==========================================
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: cardBorderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Logos circulares emblemáticos con divisor ornamental
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildLogoItem(
                                      context: context,
                                      assetPath: 'assets/images/church_logo_clean.png',
                                      isDark: isDark,
                                      tooltip: 'Escudo de la Iglesia (Toca para ampliar)',
                                      label: 'Iglesia Local',
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 1.5,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  isDark ? Colors.amber.withValues(alpha: 0.5) : Colors.amber.shade400,
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            child: Icon(
                                              Icons.church_rounded,
                                              size: 16,
                                              color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                                            ),
                                          ),
                                          Container(
                                            width: 1.5,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  isDark ? Colors.amber.withValues(alpha: 0.5) : Colors.amber.shade400,
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildLogoItem(
                                      context: context,
                                      assetPath: 'assets/images/mission_logo_v3.png',
                                      isDark: isDark,
                                      tooltip: 'Logo de la Misión (Toca para ampliar)',
                                      label: 'Misión IUMP',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),

                                Text(
                                  'Iglesia Primera San Bernardo',
                                  style: GoogleFonts.outfit(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w800,
                                    color: primaryTextColor,
                                    letterSpacing: -0.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Iglesia Unida Metodista Pentecostal (IUMP)',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.amber.withValues(alpha: 0.14)
                                        : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.amber.withValues(alpha: 0.35)
                                          : Colors.amber.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.history_rounded, size: 16, color: Colors.amber.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Fundada el 01 de Septiembre de 1971',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ==========================================
                          // 2. TARJETA DESTACADA: NUESTRO TEMPLO (MAPA)
                          // ==========================================
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF0C4A6E).withValues(alpha: 0.40), const Color(0xFF1E293B).withValues(alpha: 0.85)]
                                    : [const Color(0xFFE0F2FE), Colors.white],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF38BDF8).withValues(alpha: 0.35)
                                    : const Color(0xFF0284C7).withValues(alpha: 0.25),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.16 : 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0284C7).withValues(alpha: 0.45),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.location_on_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Nuestro Templo',
                                            style: GoogleFonts.outfit(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                          Text(
                                            'Te invitamos a congregarte con nosotros',
                                            style: GoogleFonts.nunito(
                                              fontSize: 13,
                                              color: secondaryTextColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _copyAddress(context),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.black.withValues(alpha: 0.28) : Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.place_outlined,
                                            size: 22,
                                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  churchAddress,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: primaryTextColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Región Metropolitana, Chile • Toca para copiar',
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 12,
                                                    color: secondaryTextColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.copy_rounded,
                                              size: 19,
                                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                            ),
                                            tooltip: 'Copiar dirección',
                                            onPressed: () => _copyAddress(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: _openChurchMap,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      foregroundColor: Colors.white,
                                      elevation: 3,
                                      shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: const Icon(Icons.map_rounded, size: 20),
                                    label: Text(
                                      'Cómo Llegar en Mapas',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ==========================================
                          // 3. CITA BÍBLICA
                          // ==========================================
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.format_quote_rounded,
                                  color: isDark
                                      ? const Color(0xFF38BDF8).withValues(alpha: 0.6)
                                      : const Color(0xFF0284C7).withValues(alpha: 0.4),
                                  size: 34,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '«Cantaré a Jehová en mi vida;\nCantaré salmos a mi Dios mientras viva.»',
                                  style: GoogleFonts.lora(
                                    fontSize: 16.5,
                                    fontStyle: FontStyle.italic,
                                    color: primaryTextColor,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                                        : const Color(0xFF0284C7).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Salmos 104:33',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ==========================================
                          // 4. HISTORIA Y PROPÓSITO
                          // ==========================================
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader(
                                  icon: Icons.church_rounded,
                                  iconColor: Colors.amber,
                                  title: 'Nuestra Historia',
                                  isDark: isDark,
                                  primaryTextColor: primaryTextColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Nuestra amada Iglesia Primera San Bernardo fue fundada el 01 de Septiembre de 1971 y forma parte de la Iglesia Unida Metodista Pentecostal (IUMP), una institución cristiana dedicada a proclamar el evangelio de Jesucristo.',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14.5,
                                    color: secondaryTextColor,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Divider(
                                  height: 1,
                                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                ),
                                const SizedBox(height: 22),
                                _buildSectionHeader(
                                  icon: Icons.favorite_rounded,
                                  iconColor: Colors.pinkAccent,
                                  title: 'Propósito del Himnario',
                                  isDark: isDark,
                                  primaryTextColor: primaryTextColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Esta aplicación oficial ha sido creada para ser un instrumento de bendición y adoración tanto para la congregación local como para todos nuestros hermanos esparcidos en Chile y el mundo.',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14.5,
                                    color: secondaryTextColor,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ==========================================
                          // 5. REDES SOCIALES Y TRANSMISIONES
                          // ==========================================
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transmisiones y Redes Sociales',
                                  style: GoogleFonts.outfit(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sigue nuestras actividades y conéctate a los cultos en vivo',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _buildSocialTile(
                                  icon: FontAwesomeIcons.youtube,
                                  iconColor: const Color(0xFFFF0000),
                                  title: 'Canal de YouTube',
                                  subtitle: '@primeradesanbernardo • Cultos en directo',
                                  onTap: () => _launchExternalUrl(youtubeUrl),
                                  isDark: isDark,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                ),
                                const SizedBox(height: 12),
                                _buildSocialTile(
                                  icon: FontAwesomeIcons.instagram,
                                  iconColor: const Color(0xFFE1306C),
                                  title: 'Instagram Oficial',
                                  subtitle: '@iglesia.primerasanbernardo • Noticias y eventos',
                                  onTap: () => _launchExternalUrl(instagramUrl),
                                  isDark: isDark,
                                  primaryTextColor: primaryTextColor,
                                  secondaryTextColor: secondaryTextColor,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ==========================================
                          // 6. PIE INSTITUCIONAL Y CRÉDITOS (ELEGANTE, SIN "VERSIÓN 2.0")
                          // ==========================================
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFF1F5F9).withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                                        : const Color(0xFF0284C7).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Himnario Cristiano • IUMP',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Desarrollado con dedicación por David Trureo Ahumada',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: secondaryTextColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.all_inclusive_rounded,
                                  size: 16,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '«Solamente a Dios sea la Gloria»',
                                  style: GoogleFonts.lora(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: secondaryTextColor.withValues(alpha: 0.8),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoItem({
    required BuildContext context,
    required String assetPath,
    required bool isDark,
    required String tooltip,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => _showFullLogo(context, assetPath),
              customBorder: const CircleBorder(),
              child: Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.65)
                        : Colors.amber.shade400,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                          : Colors.amber.shade200.withValues(alpha: 0.5),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFF0284C7).withValues(alpha: 0.25)
                          : const Color(0xFF0284C7).withValues(alpha: 0.12),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Hero(
                  tag: assetPath,
                  child: ClipOval(
                    child: Image.asset(assetPath, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isDark,
    required Color primaryTextColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialTile({
    required dynamic icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: FaIcon(icon, color: iconColor, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: secondaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
