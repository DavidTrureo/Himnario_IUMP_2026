import 'package:cloud_firestore/cloud_firestore.dart';
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
          if (!kIsWeb || isAdmin) ...[
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
          if (isAdmin) ...[
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cantos_sugeridos')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                int count = 0;
                if (snapshot.hasData) {
                  count = snapshot.data!.docs.length;
                }
                
                return _ToolCard(
                  title: 'Sugerencias de Cantos (Admin)',
                  subtitle: 'Revisa y aprueba los cantos sugeridos por IA',
                  icon: Icons.admin_panel_settings_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  badgeCount: count,
                  onTap: () {
                    context.push('/admin-suggestions');
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            _ToolCard(
              title: 'Dispositivos e Instalaciones (Admin)',
              subtitle: 'Conteo por plataforma, actividad y bajas FCM',
              icon: Icons.devices_other_rounded,
              iconColor: const Color(0xFF0EA5E9),
              onTap: () {
                context.push('/admin-devices');
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
