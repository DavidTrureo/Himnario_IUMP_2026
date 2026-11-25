import 'dart:ui' as dart_ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDevices;

  const _DeviceStatsSummary({
    required this.totalRegistered,
    required this.activeLast30Days,
    required this.inactiveOver30Days,
    required this.uninstalledFcm,
    required this.androidCount,
    required this.iosCount,
    required this.webCount,
    required this.versionBreakdown,
    required this.allDevices,
  });
}

class AdminDevicesScreen extends ConsumerStatefulWidget {
  final String initialFilter;

  const AdminDevicesScreen({
    super.key,
    this.initialFilter = 'all',
  });

  @override
  ConsumerState<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends ConsumerState<AdminDevicesScreen> {
  Future<_DeviceStatsSummary>? _statsFuture;
  late String _currentFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isCheckingFcm = false;
  String? _fcmCheckResultMessage;
  bool _fcmCheckWasError = false;
  bool _showTechnicalDeviceList = false;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _statsFuture = _loadStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    // Obtenemos los dispositivos para mostrarlos en el explorador interactivo
    final recentSnap = await installsRef
        .orderBy('lastSeenAt', descending: true)
        .limit(150)
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
      allDevices: recentSnap.docs,
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

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Hace instantes';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    if (diff.inDays < 30) return 'Hace ${(diff.inDays / 7).floor()} sem';
    if (diff.inDays < 365) return 'Hace ${(diff.inDays / 30).floor()} mes(es)';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatFullDate(DateTime? date) {
    if (date == null) return 'No registrado';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDevices(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> devices,
    DateTime cutoffDate,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    return devices.where((doc) {
      final data = doc.data();
      final status = (data['installStatus'] as String?) ?? 'active';
      final platform = (data['platform'] as String?) ?? 'other';
      final lastSeenTs = data['lastSeenAt'] as Timestamp?;
      final lastSeenDate = lastSeenTs?.toDate();

      final isUninstalled = status == 'uninstalled_fcm';
      final isActive = !isUninstalled && lastSeenDate != null && lastSeenDate.isAfter(cutoffDate);
      final isInactive = !isUninstalled && (lastSeenDate == null || lastSeenDate.isBefore(cutoffDate));

      // Filtro de categoría
      bool matchesCategory = true;
      switch (_currentFilter) {
        case 'active':
          matchesCategory = isActive;
          break;
        case 'inactive':
          matchesCategory = isInactive;
          break;
        case 'uninstalled':
          matchesCategory = isUninstalled;
          break;
        case 'android':
          matchesCategory = platform == 'android';
          break;
        case 'ios':
          matchesCategory = platform == 'ios';
          break;
        case 'web':
          matchesCategory = platform == 'web';
          break;
        case 'all':
        default:
          matchesCategory = true;
          break;
      }

      if (!matchesCategory) return false;

      // Filtro de búsqueda
      if (query.isNotEmpty) {
        final deviceId = (data['deviceId'] as String? ?? doc.id).toLowerCase();
        final appVersion = (data['appVersion'] as String? ?? '').toLowerCase();
        final plat = platform.toLowerCase();
        return deviceId.contains(query) ||
            appVersion.contains(query) ||
            plat.contains(query);
      }

      return true;
    }).toList();
  }

  void _showDeviceDetailModal({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool isDark,
    required DateTime cutoffDate,
  }) {
    final data = doc.data();
    final deviceId = (data['deviceId'] as String?) ?? doc.id;
    final platform = (data['platform'] as String?) ?? 'desconocida';
    final appVersion = (data['appVersion'] as String?) ?? 'Sin versión';
    final status = (data['installStatus'] as String?) ?? 'active';
    final hasFcm = (data['hasFcmToken'] as bool?) ?? false;
    final firstSeenTs = data['firstSeenAt'] as Timestamp?;
    final lastSeenTs = data['lastSeenAt'] as Timestamp?;

    final isUninstalled = status == 'uninstalled_fcm';
    final isActive = !isUninstalled && lastSeenTs != null && lastSeenTs.toDate().isAfter(cutoffDate);

    Color statusColor;
    String statusLabel;
    if (isUninstalled) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'BAJA FCM (Desinstalado / Token inválido)';
    } else if (isActive) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'ACTIVO (Uso en últimos 30 días)';
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'INACTIVO (+30 días sin uso)';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
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
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        platform == 'android'
                            ? Icons.android_rounded
                            : platform == 'ios'
                                ? Icons.apple_rounded
                                : Icons.language_rounded,
                        color: statusColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalle del Dispositivo',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            statusLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 12.5,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _modalInfoRow('Plataforma', platform.toUpperCase(), isDark),
                _modalInfoRow('Versión de App', appVersion, isDark),
                _modalInfoRow('Primera Conexión', _formatFullDate(firstSeenTs?.toDate()), isDark),
                _modalInfoRow('Último Uso', _formatFullDate(lastSeenTs?.toDate()), isDark),
                _modalInfoRow('Notificaciones FCM', hasFcm ? 'Registrado y activo' : 'Sin notificaciones', isDark),
                _modalInfoRow('ID Interno', deviceId.length > 24 ? '${deviceId.substring(0, 24)}...' : deviceId, isDark),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: deviceId));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ID del dispositivo copiado al portapapeles.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copiar ID'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _modalInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(adminModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

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
              tooltip: 'Actualizar datos',
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
                      final filteredDevices = _filterDevices(stats.allDevices, cutoffDate);

                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                            children: [
                              // 1. Grid interactivo de KPIs (Filtros Principales)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 600;
                                  return GridView.count(
                                    crossAxisCount: isWide ? 4 : 2,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: isWide ? 1.45 : 1.30,
                                    children: [
                                      _InteractiveStatCard(
                                        label: 'Instalaciones',
                                        value: stats.totalRegistered.toString(),
                                        icon: Icons.devices_rounded,
                                        color: const Color(0xFF0EA5E9),
                                        isSelected: _currentFilter == 'all',
                                        subtitle: 'Todas las registradas',
                                        onTap: () => setState(() => _currentFilter = 'all'),
                                      ),
                                      _InteractiveStatCard(
                                        label: 'Activos (30d)',
                                        value: stats.activeLast30Days.toString(),
                                        icon: Icons.bolt_rounded,
                                        color: const Color(0xFF10B981),
                                        isSelected: _currentFilter == 'active',
                                        subtitle: 'Uso reciente en el mes',
                                        onTap: () => setState(() => _currentFilter = 'active'),
                                      ),
                                      _InteractiveStatCard(
                                        label: 'Inactivos (+30d)',
                                        value: stats.inactiveOver30Days.toString(),
                                        icon: Icons.hourglass_bottom_rounded,
                                        color: const Color(0xFFF59E0B),
                                        isSelected: _currentFilter == 'inactive',
                                        subtitle: 'Sin uso en > 30 días',
                                        onTap: () => setState(() => _currentFilter = 'inactive'),
                                      ),
                                      _InteractiveStatCard(
                                        label: 'Bajas (FCM)',
                                        value: stats.uninstalledFcm.toString(),
                                        icon: Icons.phonelink_erase_rounded,
                                        color: const Color(0xFFEF4444),
                                        isSelected: _currentFilter == 'uninstalled',
                                        subtitle: 'App desinstalada / Token off',
                                        onTap: () => setState(() => _currentFilter = 'uninstalled'),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // 2. Ecosistema y Distribución de Plataformas
                              _SectionCard(
                                title: 'Ecosistema y Distribución de Plataformas',
                                isDark: isDark,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _PlatformDistributionBar(
                                      androidCount: stats.androidCount,
                                      iosCount: stats.iosCount,
                                      webCount: stats.webCount,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _InteractivePlatformPill(
                                            label: 'Android',
                                            count: stats.androidCount,
                                            icon: Icons.android_rounded,
                                            color: const Color(0xFF22C55E),
                                            isSelected: _currentFilter == 'android',
                                            onTap: () => setState(() => _currentFilter = 'android'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _InteractivePlatformPill(
                                            label: 'iOS / iPad',
                                            count: stats.iosCount,
                                            icon: Icons.apple_rounded,
                                            color: const Color(0xFF38BDF8),
                                            isSelected: _currentFilter == 'ios',
                                            onTap: () => setState(() => _currentFilter = 'ios'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _InteractivePlatformPill(
                                            label: 'Web',
                                            count: stats.webCount,
                                            icon: Icons.language_rounded,
                                            color: const Color(0xFFA78BFA),
                                            isSelected: _currentFilter == 'web',
                                            onTap: () => setState(() => _currentFilter = 'web'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 3. Salud y Retención Congregacional
                              _SectionCard(
                                title: 'Salud y Retención Congregacional',
                                isDark: isDark,
                                child: _RetentionHealthCard(
                                  active: stats.activeLast30Days,
                                  inactive: stats.inactiveOver30Days,
                                  uninstalled: stats.uninstalledFcm,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 4. Adopción de Versiones
                              if (stats.versionBreakdown.isNotEmpty) ...[
                                _SectionCard(
                                  title: 'Adopción de Versiones',
                                  isDark: isDark,
                                  child: _VersionAdoptionChart(
                                    versionBreakdown: stats.versionBreakdown,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // 3. Módulo FCM (Destacado cuando se filtra por Bajas FCM o se selecciona)
                              if (_currentFilter == 'uninstalled') ...[
                                _SectionCard(
                                  title: 'Chequeo y Detección de Desinstalaciones FCM',
                                  isDark: isDark,
                                  accentColor: const Color(0xFFEF4444),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Se muestran los dispositivos cuyo token de Firebase Cloud Messaging fue invalidado o cuya app fue desinstalada. Puedes ejecutar una verificación silenciosa para auditar el estado actual de los dispositivos.',
                                        style: GoogleFonts.nunito(
                                          fontSize: 13.5,
                                          height: 1.45,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFEF4444),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: _isCheckingFcm ? null : _runFcmUninstallCheck,
                                          icon: _isCheckingFcm
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : const Icon(Icons.phonelink_erase_rounded),
                                          label: Text(
                                            _isCheckingFcm
                                                ? 'Ejecutando auditoría silenciosa...'
                                                : 'Verificar Desinstalaciones FCM en Vivo',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                              ],

                              // 5. Auditoría Técnica de Dispositivos (Colapsable)
                              _SectionCard(
                                title: 'Auditoría Técnica de Dispositivos',
                                isDark: isDark,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () => setState(() => _showTechnicalDeviceList = !_showTechnicalDeviceList),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isDark ? Colors.white10 : Colors.black12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  _showTechnicalDeviceList
                                                      ? Icons.keyboard_arrow_up_rounded
                                                      : Icons.keyboard_arrow_down_rounded,
                                                  color: isDark ? Colors.white70 : Colors.black87,
                                                  size: 22,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _showTechnicalDeviceList
                                                      ? 'Ocultar listado de registros'
                                                      : 'Ver listado de registros (${filteredDevices.length})',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white : Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getFilterColor(_currentFilter).withValues(alpha: 0.16),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _getFilterLabel(_currentFilter),
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getFilterColor(_currentFilter),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_showTechnicalDeviceList) ...[
                                      const SizedBox(height: 14),
                                      // Campo de Búsqueda rápida
                                      TextField(
                                        controller: _searchController,
                                        onChanged: (val) => setState(() => _searchQuery = val),
                                        decoration: InputDecoration(
                                          hintText: 'Buscar por versión o ID...',
                                          hintStyle: GoogleFonts.nunito(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                          suffixIcon: _searchQuery.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() => _searchQuery = '');
                                                  },
                                                )
                                              : null,
                                          isDense: true,
                                          filled: true,
                                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      // Lista de Dispositivos o Empty State
                                      if (filteredDevices.isEmpty)
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isDark ? Colors.white10 : Colors.black12,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                _currentFilter == 'inactive'
                                                    ? Icons.check_circle_outline_rounded
                                                    : Icons.devices_other_rounded,
                                                size: 40,
                                                color: _currentFilter == 'inactive'
                                                    ? const Color(0xFF10B981)
                                                    : Colors.amber,
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                _currentFilter == 'inactive'
                                                    ? '¡Excelente! No hay dispositivos inactivos'
                                                    : 'No se encontraron dispositivos',
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _currentFilter == 'inactive'
                                                    ? 'Toda la congregación registrada ha utilizado la app en los últimos 30 días.'
                                                    : 'Prueba cambiando el filtro o limpiando el término de búsqueda.',
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.nunito(
                                                  fontSize: 13,
                                                  color: isDark ? Colors.white60 : Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: filteredDevices.length,
                                          separatorBuilder: (_, index) => const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final doc = filteredDevices[index];
                                            final data = doc.data();
                                            final deviceId = (data['deviceId'] as String?) ?? doc.id;
                                            final platform = (data['platform'] as String?) ?? 'other';
                                            final appVersion = (data['appVersion'] as String?) ?? '1.0.60';
                                            final status = (data['installStatus'] as String?) ?? 'active';
                                            final lastSeenTs = data['lastSeenAt'] as Timestamp?;
                                            final lastSeenDate = lastSeenTs?.toDate();

                                            final isUninstalled = status == 'uninstalled_fcm';
                                            final isActive = !isUninstalled && lastSeenDate != null && lastSeenDate.isAfter(cutoffDate);

                                            Color platColor;
                                            IconData platIcon;
                                            String platName;
                                            if (platform == 'android') {
                                              platColor = const Color(0xFF22C55E);
                                              platIcon = Icons.android_rounded;
                                              platName = 'Android';
                                            } else if (platform == 'ios') {
                                              platColor = const Color(0xFF38BDF8);
                                              platIcon = Icons.apple_rounded;
                                              platName = 'iOS / iPad';
                                            } else {
                                              platColor = const Color(0xFFA78BFA);
                                              platIcon = Icons.language_rounded;
                                              platName = 'Web';
                                            }

                                            final shortId = deviceId.length > 6
                                                ? deviceId.substring(deviceId.length - 6)
                                                : deviceId;

                                            return ListTile(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              leading: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: platColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(platIcon, color: platColor, size: 20),
                                              ),
                                              title: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '$platName · Disp. #$shortId',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isUninstalled)
                                                    _badge('BAJA FCM', const Color(0xFFEF4444))
                                                  else if (isActive)
                                                    _badge('ACTIVO', const Color(0xFF10B981))
                                                  else
                                                    _badge('INACTIVO', const Color(0xFFF59E0B)),
                                                ],
                                              ),
                                              subtitle: Text(
                                                'v$appVersion · ${_formatTimeAgo(lastSeenDate)}',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white60 : Colors.black54,
                                                ),
                                              ),
                                              trailing: const Icon(
                                                Icons.chevron_right_rounded,
                                                size: 18,
                                                color: Colors.grey,
                                              ),
                                              onTap: () => _showDeviceDetailModal(
                                                context: context,
                                                doc: doc,
                                                isDark: isDark,
                                                cutoffDate: cutoffDate,
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 6. Alcance del conteo
                              _SectionCard(
                                title: 'Alcance del Conteo de Telemetría',
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
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'active':
        return const Color(0xFF10B981);
      case 'inactive':
        return const Color(0xFFF59E0B);
      case 'uninstalled':
        return const Color(0xFFEF4444);
      case 'android':
        return const Color(0xFF22C55E);
      case 'ios':
        return const Color(0xFF38BDF8);
      case 'web':
        return const Color(0xFFA78BFA);
      case 'all':
      default:
        return const Color(0xFF0EA5E9);
    }
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'active':
        return 'FILTRO: ACTIVOS (30d)';
      case 'inactive':
        return 'FILTRO: INACTIVOS (+30d)';
      case 'uninstalled':
        return 'FILTRO: BAJAS FCM';
      case 'android':
        return 'FILTRO: ANDROID';
      case 'ios':
        return 'FILTRO: IOS / IPAD';
      case 'web':
        return 'FILTRO: WEB';
      case 'all':
      default:
        return 'FILTRO: TODAS LAS INSTALACIONES';
    }
  }
}

class _InteractiveStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _InteractiveStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.18 : 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACTIVO',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.filter_list_rounded,
                    size: 14,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 1),
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
      ),
    );
  }
}

class _InteractivePlatformPill extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _InteractivePlatformPill({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.18)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isDark;
  final Color? accentColor;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor ??
              (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06)),
          width: accentColor != null ? 1.5 : 1.0,
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
              color: accentColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PlatformDistributionBar extends StatelessWidget {
  final int androidCount;
  final int iosCount;
  final int webCount;
  final bool isDark;

  const _PlatformDistributionBar({
    required this.androidCount,
    required this.iosCount,
    required this.webCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total = androidCount + iosCount + webCount;
    if (total == 0) return const SizedBox.shrink();

    final androidPct = (androidCount / total) * 100;
    final iosPct = (iosCount / total) * 100;
    final webPct = (webCount / total) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                if (androidCount > 0)
                  Expanded(
                    flex: androidCount,
                    child: Container(color: const Color(0xFF22C55E)),
                  ),
                if (iosCount > 0)
                  Expanded(
                    flex: iosCount,
                    child: Container(color: const Color(0xFF38BDF8)),
                  ),
                if (webCount > 0)
                  Expanded(
                    flex: webCount,
                    child: Container(color: const Color(0xFFA78BFA)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _legendItem('Android', '${androidPct.toStringAsFixed(1)}%', '($androidCount)', const Color(0xFF22C55E)),
            _legendItem('iOS / iPad', '${iosPct.toStringAsFixed(1)}%', '($iosCount)', const Color(0xFF38BDF8)),
            _legendItem('Web', '${webPct.toStringAsFixed(1)}%', '($webCount)', const Color(0xFFA78BFA)),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(String name, String pct, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$name: ',
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        Text(
          '$pct $count',
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RetentionHealthCard extends StatelessWidget {
  final int active;
  final int inactive;
  final int uninstalled;
  final bool isDark;

  const _RetentionHealthCard({
    required this.active,
    required this.inactive,
    required this.uninstalled,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total = active + inactive + uninstalled;
    final retentionRate = total > 0 ? (active / total) * 100 : 0.0;

    Color rateColor = const Color(0xFF10B981);
    String rateStatus = 'Excelente Retención';
    if (retentionRate < 60) {
      rateColor = const Color(0xFFEF4444);
      rateStatus = 'Baja Actividad';
    } else if (retentionRate < 80) {
      rateColor = const Color(0xFFF59E0B);
      rateStatus = 'Actividad Moderada';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${retentionRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: rateColor,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Tasa de Uso Activo Congregacional',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: rateColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: rateColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                rateStatus,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: rateColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (active > 0)
                  Expanded(
                    flex: active,
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                if (inactive > 0)
                  Expanded(
                    flex: inactive,
                    child: Container(color: const Color(0xFFF59E0B)),
                  ),
                if (uninstalled > 0)
                  Expanded(
                    flex: uninstalled,
                    child: Container(color: const Color(0xFFEF4444)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _healthMetric('Activos (30d)', active, const Color(0xFF10B981), isDark),
            _healthMetric('En pausa (+30d)', inactive, const Color(0xFFF59E0B), isDark),
            _healthMetric('Bajas (FCM)', uninstalled, const Color(0xFFEF4444), isDark),
          ],
        ),
      ],
    );
  }

  Widget _healthMetric(String label, int count, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _VersionAdoptionChart extends StatelessWidget {
  final Map<String, int> versionBreakdown;
  final bool isDark;

  const _VersionAdoptionChart({
    required this.versionBreakdown,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (versionBreakdown.isEmpty) return const SizedBox.shrink();

    final total = versionBreakdown.values.fold<int>(0, (acc, val) => acc + val);
    final sortedEntries = versionBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final latestVersion = sortedEntries.isNotEmpty ? sortedEntries.first.key : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Muestra de los últimos $total dispositivos conectados:',
          style: GoogleFonts.nunito(fontSize: 12.5, color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 12),
        ...sortedEntries.take(5).map((entry) {
          final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
          final isLatest = entry.key == latestVersion;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'v${entry.key}',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isLatest
                                ? const Color(0xFF10B981)
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        if (isLatest) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ÚLTIMA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${entry.value} disp. (${pct.toStringAsFixed(1)}%)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 7,
                    backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLatest
                          ? const Color(0xFF10B981)
                          : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
