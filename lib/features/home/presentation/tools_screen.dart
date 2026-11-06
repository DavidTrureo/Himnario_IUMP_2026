import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          ],
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
