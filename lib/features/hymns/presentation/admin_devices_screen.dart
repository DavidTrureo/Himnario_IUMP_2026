import 'dart:ui' as dart_ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/hymn.dart';

class _DeviceStatsSummary {
  final int totalRegistered;
  final int activeLast30Days;
  final int inactiveOver30Days;
  final int uninstalledFcm;
  final int androidCount;
  final int iosCount;
  final int webCount;
  final Map<String, int> versionBreakdown;

  const _DeviceStatsSummary({
    required this.totalRegistered,
    required this.activeLast30Days,
    required this.inactiveOver30Days,
    required this.uninstalledFcm,
    required this.androidCount,
    required this.iosCount,
    required this.webCount,
    required this.versionBreakdown,
  });
}

class AdminDevicesScreen extends ConsumerStatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  ConsumerState<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends ConsumerState<AdminDevicesScreen> {
  Future<_DeviceStatsSummary>? _statsFuture;
  bool _isCheckingFcm = false;
  String? _fcmCheckResultMessage;
  bool _fcmCheckWasError = false;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_DeviceStatsSummary> _loadStats() async {
    final installsRef = FirebaseFirestore.instance.collection('device_installs');
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 30)),
    );

    final countFutures = await Future.wait<AggregateQuerySnapshot>([
      installsRef.count().get(),
      installsRef
          .where('installStatus', isEqualTo: 'active')
          .where('lastSeenAt', isGreaterThanOrEqualTo: cutoff)
          .count()
          .get(),
      installsRef
          .where('installStatus', isEqualTo: 'active')
          .where('lastSeenAt', isLessThan: cutoff)
          .count()
          .get(),
      installsRef
          .where('installStatus', isEqualTo: 'uninstalled_fcm')
          .count()
          .get(),
      installsRef.where('platform', isEqualTo: 'android').count().get(),
      installsRef.where('platform', isEqualTo: 'ios').count().get(),
      installsRef.where('platform', isEqualTo: 'web').count().get(),
    ]);

    final recentSnap = await installsRef
        .orderBy('lastSeenAt', descending: true)
        .limit(50)
        .get();

    final versions = <String, int>{};
    for (final doc in recentSnap.docs) {
      final version = (doc.data()['appVersion'] as String?) ?? 'desconocida';
      versions[version] = (versions[version] ?? 0) + 1;
    }

    return _DeviceStatsSummary(
      totalRegistered: countFutures[0].count ?? 0,
      activeLast30Days: countFutures[1].count ?? 0,
      inactiveOver30Days: countFutures[2].count ?? 0,
      uninstalledFcm: countFutures[3].count ?? 0,
      androidCount: countFutures[4].count ?? 0,
      iosCount: countFutures[5].count ?? 0,
      webCount: countFutures[6].count ?? 0,
      versionBreakdown: versions,
    );
  }

  void _refreshStats() {
    setState(() {
      _statsFuture = _loadStats();
    });
  }

  Future<void> _runFcmUninstallCheck() async {
    setState(() {
      _isCheckingFcm = true;
      _fcmCheckResultMessage = null;
      _fcmCheckWasError = false;
    });

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('checkInactiveDeviceUninstalls');
      final response = await callable.call(<String, dynamic>{'maxToCheck': 500});
      final data = Map<String, dynamic>.from(response.data as Map);

      final checked = data['checked'] ?? 0;
      final activeVerified = data['activeVerified'] ?? 0;
      final newlyUninstalled = data['newlyDetectedUninstalled'] ?? 0;

      if (!mounted) return;
      setState(() {
        _fcmCheckResultMessage =
            'Chequeo completado: $checked tokens revisados · $activeVerified activos · $newlyUninstalled bajas nuevas detectadas.';
        _fcmCheckWasError = false;
      });
      _refreshStats();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fcmCheckResultMessage = 'No se pudo completar el chequeo FCM: $e';
        _fcmCheckWasError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isCheckingFcm = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(adminModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Dispositivos e Instalaciones',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Actualizar contadores',
              onPressed: _refreshStats,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.16 : 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: !isAdmin
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Inicia sesión como Administrador para ver las estadísticas de dispositivos.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  )
                : FutureBuilder<_DeviceStatsSummary>(
                    future: _statsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_rounded,
                                    size: 48, color: Colors.amber),
                                const SizedBox(height: 12),
                                Text(
                                  'Error cargando estadísticas:\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(fontSize: 14),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _refreshStats,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final stats = snapshot.data!;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        children: [
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.42,
                            children: [
                              _StatCard(
                                label: 'Instalaciones',
                                value: stats.totalRegistered.toString(),
                                icon: Icons.devices_rounded,
                                color: const Color(0xFF0EA5E9),
                              ),
                              _StatCard(
                                label: 'Activos (30d)',
                                value: stats.activeLast30Days.toString(),
                                icon: Icons.check_circle_rounded,
                                color: const Color(0xFF10B981),
                              ),
                              _StatCard(
                                label: 'Inactivos (+30d)',
                                value: stats.inactiveOver30Days.toString(),
                                icon: Icons.hourglass_bottom_rounded,
                                color: const Color(0xFFF59E0B),
                              ),
                              _StatCard(
                                label: 'Bajas (FCM)',
                                value: stats.uninstalledFcm.toString(),
                                icon: Icons.phonelink_erase_rounded,
                                color: const Color(0xFFEF4444),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionCard(
                            title: 'Por plataforma',
                            isDark: isDark,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _PlatformPill(
                                    label: 'Android',
                                    count: stats.androidCount,
                                    icon: Icons.android_rounded,
                                    color: const Color(0xFF22C55E),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PlatformPill(
                                    label: 'iOS / iPad',
                                    count: stats.iosCount,
                                    icon: Icons.apple_rounded,
                                    color: const Color(0xFF38BDF8),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PlatformPill(
                                    label: 'Web',
                                    count: stats.webCount,
                                    icon: Icons.language_rounded,
                                    color: const Color(0xFFA78BFA),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (stats.versionBreakdown.isNotEmpty) ...[
                            _SectionCard(
                              title: 'Versiones recientes (últimos 50 dispositivos)',
                              isDark: isDark,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: stats.versionBreakdown.entries
                                    .map(
                                      (entry) => Chip(
                                        label: Text(
                                          '${entry.key}: ${entry.value}',
                                          style: GoogleFonts.outfit(fontSize: 12.5),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _SectionCard(
                            title: 'Verificación de desinstalaciones',
                            isDark: isDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ejecuta una comprobación silenciosa (sin enviar notificaciones) contra los tokens FCM registrados para detectar apps desinstaladas.',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isCheckingFcm
                                        ? null
                                        : _runFcmUninstallCheck,
                                    icon: _isCheckingFcm
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.verified_user_rounded),
                                    label: Text(
                                      _isCheckingFcm
                                          ? 'Verificando tokens...'
                                          : 'Verificar desinstalaciones (FCM)',
                                    ),
                                  ),
                                ),
                                if (_fcmCheckResultMessage != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    _fcmCheckResultMessage!,
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _fcmCheckWasError
                                          ? Colors.redAccent
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Alcance del conteo',
                            isDark: isDark,
                            child: Text(
                              '• Cuenta dispositivos registrados desde la versión 1.0.37+42 en adelante.\n'
                              '• El conteo por FCM aplica a dispositivos que aceptaron notificaciones.\n'
                              '• Para el historial oficial completo de Play Store / App Store y Firebase Analytics (first_open / app_remove), revisa sus respectivas consolas web.',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                height: 1.45,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 12.5,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isDark;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _PlatformPill({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

