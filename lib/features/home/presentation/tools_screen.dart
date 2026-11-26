import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../hymns/domain/hymn.dart';

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAdmin = ref.watch(adminModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fondo base gradiente (consistente con el Home)
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
          
          // Círculo decorativo aurora superior derecha
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: isDark 
                  ? const Color(0xFF6366F1).withValues(alpha: 0.18) 
                  : const Color(0xFF818CF8).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Círculo decorativo aurora inferior izquierda (Ámbar eclesiástico)
          Positioned(
            bottom: -80,
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

          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 8.0),
                  child: Text(
                    'Herramientas',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      color: isDark ? Colors.white : theme.colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 140.0),
                    physics: const BouncingScrollPhysics(),
                    children: [
          if (!kIsWeb && !isAdmin) ...[
            _ToolCard(
              title: 'Escáner Inteligente',
              subtitle: 'Transcribe un canto con IA a partir de una foto',
              icon: Icons.document_scanner_rounded,
              iconColor: const Color(0xFF8B5CF6),
              onTap: () {
                context.push('/scanner');
              },
            ),
            const SizedBox(height: 16),
          ],
          _ToolCard(
            title: 'Unirme a Culto en Vivo',
            subtitle: 'Escanea el código QR proyectado para seguir el culto',
            icon: Icons.qr_code_scanner_rounded,
            iconColor: const Color(0xFFEAB308),
            onTap: () => context.push('/scan-qr'),
          ),
          const SizedBox(height: 16),
          _ToolCard(
            title: 'Pantalla de Proyección (Receptor)',
            subtitle: 'Abre esta pantalla en tu TV/PC y contrólala desde el móvil',
            icon: Icons.tv_rounded,
            iconColor: const Color(0xFF0EA5E9),
            onTap: () async {
              if (kIsWeb) {
                final targetUrl = '${Uri.base.origin}/tv';
                final url = Uri.parse(targetUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, webOnlyWindowName: '_blank');
                } else {
                  context.push('/tv');
                }
              } else {
                context.push('/tv');
              }
            },
          ),
          const SizedBox(height: 16),
          _ToolCard(
            title: 'Guía: Las 2 Formas de Proyectar',
            subtitle: 'Aprende a proyectar con cable HDMI (PC) o inalámbrico (Smart TV)',
            icon: Icons.cast_connected_rounded,
            iconColor: const Color(0xFF38BDF8),
            onTap: () => _showProjectionGuideSheet(context, isDark, theme),
          ),
          const SizedBox(height: 16),

          if (!isAdmin) ...[
            _ToolCard(
              title: 'Mis Sugerencias al Catálogo',
              subtitle: 'Revisa el estado de los cantos enviados al administrador',
              icon: Icons.mark_email_read_rounded,
              iconColor: const Color(0xFF6366F1),
              onTap: () {
                context.push('/my-suggestions');
              },
            ),
            const SizedBox(height: 16),
          ],
          _ToolCard(
            title: 'Guía Rápida de Funciones',
            subtitle: 'Descubre todo lo que puedes hacer con la app',
            icon: Icons.tips_and_updates_rounded,
            iconColor: const Color(0xFF10B981),
            onTap: () {
              context.push('/guide');
            },
          ),
          const SizedBox(height: 16),
          _ToolCard(
            title: 'Himnario Web (PC y iPhone)',
            subtitle: 'Enlace interactivo para usuarios sin la app instalada',
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF06B6D4),
            onTap: () => _showWebPortalModal(context, isDark, theme),
          ),
          const SizedBox(height: 16),
          _ToolCard(
            title: 'Nuestra Iglesia',
            subtitle: 'Templo, historia, ubicación y redes oficiales',
            icon: Icons.church_rounded,
            iconColor: const Color(0xFFEAB308),
            onTap: () {
              context.push('/tools/church');
            },
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

  void _showProjectionGuideSheet(BuildContext context, bool isDark, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cast_connected_rounded, color: Color(0xFF0EA5E9), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Las 2 Formas de Proyectar',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Guía oficial para cabina multimedia o púlpito',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildModeGuideCard(
                          isDark: isDark,
                          badgeText: 'MODO 1 • CONEXIÓN POR CABLE',
                          badgeColor: const Color(0xFF3B82F6),
                          icon: Icons.laptop_mac_rounded,
                          title: 'Proyector Directo (PC / Mac / HDMI / OBS)',
                          description: 'Diseñado para cuando una laptop en cabina está conectada físicamente por cable HDMI o VGA al proyector.',
                          steps: [
                            'Conecta tu laptop o PC al proyector por cable HDMI.',
                            'Abre el Himnario Web en: himnario-vito-2026.web.app',
                            'Entra a cualquier canto y en el menú de 3 puntos pulsa "Modo Proyector (PC/Mac)".',
                            'Presiona el botón "Despegar Proyector" (icono de ventana externa en la barra superior) y arrastra la ventana limpia al proyector.',
                            'Desde tu laptop controlas las estrofas, fuentes, temas y el botón de Pantalla Negra (Blank).',
                          ],
                          tipText: 'Ventaja: Cero latencia e independencia de internet durante el servicio.',
                        ),
                        const SizedBox(height: 18),
                        _buildModeGuideCard(
                          isDark: isDark,
                          badgeText: 'MODO 2 • CONEXIÓN INALÁMBRICA',
                          badgeColor: const Color(0xFF10B981),
                          icon: Icons.connected_tv_rounded,
                          title: 'Control Remoto en Vivo (Smart TV / Nube)',
                          description: 'Diseñado para proyectar sin cables desde tu celular o tablet caminando por el templo.',
                          steps: [
                            'En el televisor Smart TV o computador frente al templo abre: himnario-vito-2026.web.app/tv',
                            'En la pantalla gigante aparecerá un Código de Sala de 4 dígitos (ej: 8492).',
                            'En tu celular, abre el canto, toca los 3 puntos y pulsa "Control Remoto (Smart TV)".',
                            'Ingresa el código de 4 dígitos y toma el control inalámbrico de estrofas y cantos.',
                          ],
                          tipText: 'Ventaja: Libertad total de movimiento para el pastor o director de coro.',
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.check_circle_rounded, size: 18),
                            label: Text('Entendido', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeGuideCard({
    required bool isDark,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required String title,
    required String description,
    required List<String> steps,
    required String tipText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.outfit(
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Icon(icon, color: badgeColor, size: 22),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2, right: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$idx',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step,
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        height: 1.35,
                        color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 15, color: badgeColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    tipText,
                    style: GoogleFonts.nunito(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
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

  void _showWebPortalModal(BuildContext context, bool isDark, ThemeData theme) {
    const webUrl = 'https://himnario-vito-2026.web.app';
    const webPortalMessage = '''🏛️ *Himnario Oficial IUMP 2026 - Versión Web*

¿No tienes Android o estás desde un computador o iPhone?
Accede al portal interactivo sin instalar nada:
$webUrl

ℹ️ *Nota:* La versión web permite consultar letras, acordes y reproducir audios vía streaming. El modo 100% sin internet, descargas y transmisión a pantallas están disponibles en la App para celulares.

✨ ¡A Dios sea la Gloria!''';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).padding.bottom),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.language_rounded, color: Color(0xFF06B6D4), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Himnario Web Interactivo',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Acceso universal desde cualquier navegador',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enlace oficial del portal:',
                          style: GoogleFonts.outfit(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          webUrl,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Funcionalidades de la versión Web vs App:',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureBullet(
                    Icons.check_circle_outline_rounded,
                    Colors.green,
                    'Disponible en Web: Letras completas, acordes y transporte, búsqueda rápida y streaming de audio.',
                    isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildFeatureBullet(
                    Icons.info_outline_rounded,
                    Colors.amber,
                    'Exclusivo en la App Móvil: Modo 100% sin conexión, descargas de MP3 a la memoria, transmisión a pantallas/OBS y pantalla siempre activa.',
                    isDark,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            'Compartir',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          onPressed: () async {
                            final box = context.findRenderObject() as RenderBox?;
                            final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
                            if (ctx.mounted) Navigator.pop(ctx);

                            if (kIsWeb) {
                              await Clipboard.setData(const ClipboardData(text: webUrl));
                              final whatsappUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(webPortalMessage)}');
                              // ignore: deprecated_member_use
                              if (await canLaunchUrl(whatsappUrl)) {
                                await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                              }
                            } else {
                              // ignore: deprecated_member_use
                              await Share.share(
                                webPortalMessage,
                                subject: 'Himnario IUMP - Versión Web',
                                sharePositionOrigin: rect,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text(
                            'Copiar Enlace',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () async {
                            await Clipboard.setData(const ClipboardData(text: webUrl));
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                                      SizedBox(width: 8),
                                      Text('¡Enlace web copiado al portapapeles!'),
                                    ],
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureBullet(IconData icon, Color color, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final dynamic icon;
  final Color iconColor;
  final VoidCallback onTap;
  final int badgeCount;

  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text(badgeCount.toString()),
              backgroundColor: Colors.red,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
