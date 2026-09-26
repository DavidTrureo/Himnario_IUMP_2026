import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../hymns/domain/hymn.dart';
import '../../hymns/presentation/admin_suggestions_screen.dart';
import '../../hymns/presentation/hymn_scanner_screen.dart';
import 'home_screen.dart'; // Para reutilizar proveedores o adminMode si están ahí

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAdmin = ref.watch(adminModeProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 24,
        title: Text(
          'Herramientas',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: isDark ? Colors.white : theme.colorScheme.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 140.0),
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
                final currentUrl = Uri.base.toString();
                final baseUrl = currentUrl.split('#')[0];
                final url = Uri.parse('$baseUrl#/tv');
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
          ],
          _ToolCard(
            title: 'Acerca de',
            subtitle: 'Información de la aplicación',
            icon: Icons.info_outline_rounded,
            iconColor: Colors.blueGrey,
            onTap: () {
              showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: 'Cerrar',
                barrierColor: Colors.black.withValues(alpha: 0.6),
                transitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (context, anim1, anim2) {
                  return const SizedBox();
                },
                transitionBuilder: (context, anim1, anim2, child) {
                  final curvedValue = Curves.easeOutQuint.transform(anim1.value);
                  return Transform.scale(
                    scale: 0.95 + (0.05 * curvedValue),
                    child: Opacity(
                      opacity: anim1.value,
                      child: _PremiumAboutDialog(),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
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

class _SocialButton extends StatelessWidget {
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.05),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FaIcon(icon, color: color, size: 32),
        ),
      ),
    );
  }
}

class _PremiumAboutDialog extends ConsumerWidget {
  const _PremiumAboutDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: true,
      child: _buildDialog(context, ref),
    );
  }

  Widget _buildDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2C) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // Fondo con brillo sutil superior
              Positioned(
                top: -100,
                left: -100,
                right: -100,
                height: 200,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.blueAccent.withValues(alpha: isDark ? 0.15 : 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logos hermoseados
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLogoBox(context, 'assets/images/church_logo_clean.png', isDark),
                        const SizedBox(width: 16),
                        Container(
                          width: 1.5,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                isDark ? Colors.white24 : Colors.black26,
                                Colors.transparent,
                              ]
                            )
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildLogoBox(context, 'assets/images/mission_logo_v3.png', isDark),
                      ],
                    ),
                    const SizedBox(height: 28),
                    
                    // Título con Gradiente
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: isDark 
                          ? [Colors.white, Colors.blue.shade200]
                          : [const Color(0xFF1E293B), Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        'Himnario IUMP',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blueAccent.withValues(alpha: 0.15) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Versión 2.0',
                        style: GoogleFonts.nunito(
                          fontSize: 13, 
                          color: isDark ? Colors.blueAccent.shade100 : Colors.blue.shade700, 
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Cita Bíblica (Destacada Premium)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark 
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [const Color(0xFFF8FAFC), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.format_quote_rounded, color: isDark ? Colors.blueAccent.withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.2), size: 36),
                          const SizedBox(height: 8),
                          Text(
                            '"Cantaré a Jehová en mi vida;\nCantaré salmos a mi Dios mientras viva."\nSalmos 104:33',
                            style: GoogleFonts.lora(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              height: 1.5,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Sección de Historia y Propósito (Cards Elegantes)
                    _buildInfoCard(
                      isDark: isDark,
                      icon: Icons.auto_awesome_rounded,
                      iconColor: Colors.amber,
                      title: 'Nuestra Historia',
                      content: 'Nuestra Iglesia Primera San Bernardo fue fundada el 01 de Septiembre de 1971 y es parte de la gran familia de la Iglesia Unida Metodista Pentecostal (IUMP).',
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      isDark: isDark,
                      icon: Icons.favorite_rounded,
                      iconColor: Colors.pinkAccent,
                      title: 'Propósito de la App',
                      content: 'Esta aplicación ha sido creada como una herramienta para la bendición de la congregación local y todos nuestros hermanos alrededor del mundo.',
                    ),
                    const SizedBox(height: 32),
                    
                    // Autor (Sleek Badge)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark 
                            ? [Colors.blueAccent.withValues(alpha: 0.2), Colors.purpleAccent.withValues(alpha: 0.1)]
                            : [Colors.blue.shade50, Colors.purple.shade50],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))
                              ]
                            ),
                            child: Icon(Icons.code_rounded, size: 20, color: isDark ? Colors.blueAccent.shade100 : Colors.blue.shade700),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Desarrollado por',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12, 
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'David Trureo Ahumada',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    const Divider(height: 1),
                    const SizedBox(height: 24),
                    
                    // Redes Sociales
                    Text(
                      'Síguenos en nuestras redes',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PremiumSocialButton(
                          icon: FontAwesomeIcons.youtube,
                          gradient: const LinearGradient(colors: [Color(0xFFFF0000), Color(0xFFFF4D4D)]),
                          onTap: () => launchUrl(Uri.parse('https://youtube.com/@primeradesanbernardo?si=q_AxgRp8jPWItiW4')),
                        ),
                        const SizedBox(width: 24),
                        _PremiumSocialButton(
                          icon: FontAwesomeIcons.instagram,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF56040)],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                          ),
                          onTap: () => launchUrl(Uri.parse('https://www.instagram.com/iglesia.primerasanbernardo?igsh=MTFoa2M4YjRiczVheg==')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Botón Cerrar
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('Cerrar', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
  }

  Widget _buildLogoBox(BuildContext context, String path, bool isDark) {
    return GestureDetector(
      onTap: () {
        showGeneralDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.9),
          barrierDismissible: true,
          barrierLabel: 'Cerrar',
          pageBuilder: (context, animation, secondaryAnimation) {
            return GestureDetector(
              onTap: () => Navigator.pop(context),
              child: SafeArea(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 120.0),
                      child: Image.asset(path, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      child: Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(path, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                content,
                style: GoogleFonts.nunito(
                  fontSize: 14.5, 
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumSocialButton extends StatefulWidget {
  final dynamic icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _PremiumSocialButton({
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_PremiumSocialButton> createState() => _PremiumSocialButtonState();
}

class _PremiumSocialButtonState extends State<_PremiumSocialButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.gradient,
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(alpha: _isHovered ? 0.4 : 0.2),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          alignment: Alignment.center,
          child: Center(child: FaIcon(widget.icon, color: Colors.white, size: 24)),
        ),
      ),
    );
  }
}
