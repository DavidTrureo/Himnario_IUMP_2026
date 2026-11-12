import 'dart:ui' as dart_ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/hymn.dart';
import 'hymn_list_screen.dart';

FirebaseFirestore? _safeFirestore() {
  try {
    if (Firebase.apps.isNotEmpty) {
      return FirebaseFirestore.instance;
    }
  } catch (_) {}
  return null;
}

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String _appVersion = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.buildNumber.isNotEmpty
            ? '${info.version} (build ${info.buildNumber})'
            : info.version;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appVersion = '1.0.38+43';
      });
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Cerrar sesión de Administrador',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '¿Deseas salir del Modo Administrador? Las opciones de gestión quedarán ocultas hasta que vuelvas a iniciar sesión.',
            style: GoogleFonts.nunito(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(adminModeProvider.notifier).deactivate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión de Administrador cerrada correctamente.'),
          backgroundColor: Colors.indigo,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(adminModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final iumpList = ref.watch(hymnsProvider('iump')).value ?? [];
    final espList = ref.watch(hymnsProvider('especiales')).value ?? [];
    final corosList = ref.watch(hymnsProvider('coros')).value ?? [];
    final allHymns = ref.watch(allHymnsGlobalProvider).value ?? [];
    final acordesCount = allHymns.where((h) => h.lyrics.contains('[')).length;
    final totalHymns = iumpList.length + espList.length + corosList.length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_rounded, color: Colors.amber, size: 22),
            const SizedBox(width: 8),
            Text(
              'Panel de Control Oficial',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Cerrar sesión de Administrador',
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: _confirmLogout,
            ),
        ],
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Auroras decorativas doradas / cian
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.16 : 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.14 : 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: !isAdmin
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded, size: 54, color: Colors.amber),
                          const SizedBox(height: 16),
                          Text(
                            'Acceso Restringido',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Inicia sesión con la cuenta oficial admin@himnario.com para acceder al Centro de Control.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/home');
                              }
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Volver al Inicio'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                    children: [
                      // Encabezado de identidad Admin
                      _AdminHeaderCard(
                        isDark: isDark,
                        appVersion: _appVersion,
                      ),
                      const SizedBox(height: 18),

                      // KPIs en Vivo (Sugerencias, Dispositivos, Cantos)
                      Text(
                        'Pulso del Himnario en Tiempo Real',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LiveKpiGrid(isDark: isDark, totalHymns: totalHymns),
                      const SizedBox(height: 22),

                      // Módulo 1: Gestión de Cantos & Sugerencias IA
                      Text(
                        'Gestión de Contenido y Cantos',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ContentManagementSection(
                        isDark: isDark,
                        acordesCount: acordesCount,
                        totalHymns: totalHymns,
                      ),
                      const SizedBox(height: 22),

                      // Módulo 2: Telemetría y Dispositivos
                      Text(
                        'Dispositivos e Infraestructura',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DevicesManagementSection(isDark: isDark),
                      const SizedBox(height: 22),

                      // Módulo 3: Proyección y Transmisión en Vivo
                      Text(
                        'Salas de Culto y Proyección',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LiveWorshipManagementSection(isDark: isDark),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminHeaderCard extends StatelessWidget {
  final bool isDark;
  final String appVersion;

  const _AdminHeaderCard({
    required this.isDark,
    required this.appVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF1F5F9)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Color(0xFFF59E0B),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Administrador Oficial',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'ACTIVO',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'admin@himnario.com',
                  style: GoogleFonts.nunito(
                    fontSize: 13.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Versión de la app: $appVersion',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
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

class _LiveKpiGrid extends StatelessWidget {
  final bool isDark;
  final int totalHymns;

  const _LiveKpiGrid({
    required this.isDark,
    required this.totalHymns,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = _safeFirestore();
    final installsRef = firestore?.collection('device_installs');
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)));

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        // KPI 1: Sugerencias Pendientes
        StreamBuilder<QuerySnapshot>(
          stream: firestore != null
              ? firestore
                  .collection('cantos_sugeridos')
                  .where('status', isEqualTo: 'pending')
                  .snapshots()
              : null,
          builder: (context, snapshot) {
            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return _KpiCard(
              isDark: isDark,
              title: 'Sugerencias IA',
              value: count.toString(),
              subtitle: count == 0 ? 'Al día (0 pendientes)' : 'Requieren revisión',
              icon: Icons.mark_email_unread_rounded,
              color: count > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
              onTap: () => context.push('/admin-suggestions'),
            );
          },
        ),

        // KPI 2: Dispositivos Instalados
        FutureBuilder<AggregateQuerySnapshot>(
          future: installsRef?.count().get(),
          builder: (context, snapshot) {
            final count = snapshot.hasData ? snapshot.data!.count ?? 0 : 0;
            return _KpiCard(
              isDark: isDark,
              title: 'Instalaciones',
              value: count.toString(),
              subtitle: 'Dispositivos registrados',
              icon: Icons.devices_rounded,
              color: const Color(0xFF0EA5E9),
              onTap: () => context.push('/admin-devices'),
            );
          },
        ),

        // KPI 3: Activos en 30 días
        FutureBuilder<AggregateQuerySnapshot>(
          future: installsRef != null
              ? installsRef
                  .where('installStatus', isEqualTo: 'active')
                  .where('lastSeenAt', isGreaterThanOrEqualTo: cutoff)
                  .count()
                  .get()
              : null,
          builder: (context, snapshot) {
            final count = snapshot.hasData ? snapshot.data!.count ?? 0 : 0;
            return _KpiCard(
              isDark: isDark,
              title: 'Activos (30d)',
              value: count.toString(),
              subtitle: 'Uso reciente en el mes',
              icon: Icons.bolt_rounded,
              color: const Color(0xFF10B981),
              onTap: () => context.push('/admin-devices'),
            );
          },
        ),

        // KPI 4: Total de Cantos en Base de Datos
        _KpiCard(
          isDark: isDark,
          title: 'Repertorio Total',
          value: totalHymns > 0 ? totalHymns.toString() : '2.996',
          subtitle: 'IUMP + Especiales + Coros',
          icon: Icons.library_music_rounded,
          color: const Color(0xFF8B5CF6),
          onTap: () => context.push('/home/hymns'),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _KpiCard({
    required this.isDark,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentManagementSection extends StatelessWidget {
  final bool isDark;
  final int acordesCount;
  final int totalHymns;

  const _ContentManagementSection({
    required this.isDark,
    required this.acordesCount,
    required this.totalHymns,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          // 1. Revisión de sugerencias pendientes
          StreamBuilder<QuerySnapshot>(
            stream: _safeFirestore() != null
                ? _safeFirestore()!
                    .collection('cantos_sugeridos')
                    .where('status', isEqualTo: 'pending')
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return _ActionListTile(
                icon: Icons.rule_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Aprobar o Descartar Sugerencias',
                subtitle: count == 0
                    ? 'No hay cantos pendientes en la cola'
                    : '$count sugerencia(s) esperando revisión oficial',
                badgeText: count > 0 ? '$count NUEVAS' : null,
                onTap: () => context.push('/admin-suggestions'),
              );
            },
          ),
          const Divider(height: 1),

          // 2. Digitalizar canto nuevo con Escáner IA
          _ActionListTile(
            icon: Icons.document_scanner_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Digitalizar Canto con Escáner IA',
            subtitle: 'Toma una foto de un papel o cancionero y publícalo oficial',
            onTap: () => context.push('/scanner'),
          ),
          const Divider(height: 1),

          // 3. Auditoría de Acordes y Cifrados
          _ActionListTile(
            icon: Icons.music_note_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Auditoría de Acordes Musicales',
            subtitle: '$acordesCount de $totalHymns cantos ya cuentan con acordes',
            onTap: () => context.push('/home/hymns'),
          ),
          const Divider(height: 1),

          // 4. Navegación y Edición del Catálogo Oficial
          _ActionListTile(
            icon: Icons.format_list_bulleted_rounded,
            iconColor: const Color(0xFF0EA5E9),
            title: 'Explorador y Edición del Catálogo',
            subtitle: 'Revisa y edita títulos, letras o acordes directamente',
            onTap: () => context.push('/home/hymns'),
          ),
        ],
      ),
    );
  }
}

class _DevicesManagementSection extends StatelessWidget {
  final bool isDark;

  const _DevicesManagementSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          _ActionListTile(
            icon: Icons.phone_android_rounded,
            iconColor: const Color(0xFF0EA5E9),
            title: 'Detalle de Dispositivos e Instalaciones',
            subtitle: 'Desglose por plataforma (Android / iOS / Web) y versiones',
            onTap: () => context.push('/admin-devices'),
          ),
          const Divider(height: 1),
          _ActionListTile(
            icon: Icons.phonelink_erase_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'Chequeo de Bajas y Desinstalaciones FCM',
            subtitle: 'Verificación silenciosa sin enviar notificaciones',
            onTap: () => context.push('/admin-devices'),
          ),
        ],
      ),
    );
  }
}

class _LiveWorshipManagementSection extends StatelessWidget {
  final bool isDark;

  const _LiveWorshipManagementSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          _ActionListTile(
            icon: Icons.tv_rounded,
            iconColor: const Color(0xFF06B6D4),
            title: 'Abrir Pantalla Receptora TV / Proyector',
            subtitle: 'Genera una sala receptora para recibir cantos a distancia',
            onTap: () => context.push('/tv'),
          ),
          const Divider(height: 1),
          _ActionListTile(
            icon: Icons.language_rounded,
            iconColor: const Color(0xFFA78BFA),
            title: 'Portal Himnario Web Oficial',
            subtitle: 'Abrir himnario-vito-2026.web.app en navegador',
            onTap: () async {
              final uri = Uri.parse('https://himnario-vito-2026.web.app');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ActionListTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badgeText;
  final VoidCallback onTap;

  const _ActionListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText!,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.nunito(
          fontSize: 12.5,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? Colors.white30 : Colors.black26,
      ),
      onTap: onTap,
    );
  }
}
