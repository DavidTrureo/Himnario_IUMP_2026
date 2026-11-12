import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio ligero de telemetría silenciosa (Firebase Analytics + registro
/// esporádico de dispositivo en Firestore para el panel de administración).
class AppTelemetryService {
  static const String keyDeviceId = 'device_id';
  static const String keyRegisteredOnce = 'device_reg_registered_once';
  static const String keyLastVersion = 'device_reg_last_version';
  static const String keyLastSyncMs = 'device_reg_last_sync_ms';
  static const String keyLastFcmToken = 'device_reg_last_fcm_token';
  static const Duration syncInterval = Duration(days: 7);

  static const Set<String> _allowedPlatforms = {
    'android',
    'ios',
    'web',
    'macos',
    'windows',
    'linux',
    'other',
  };

  /// Obtiene o crea el identificador anónimo estable del dispositivo.
  static Future<String> getOrCreateDeviceId(SharedPreferences prefs) async {
    String deviceId = prefs.getString(keyDeviceId) ?? '';
    if (deviceId.isEmpty) {
      deviceId =
          'dev_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}';
      await prefs.setString(keyDeviceId, deviceId);
    }
    return deviceId;
  }

  /// Normaliza el nombre de la plataforma al conjunto aceptado por Firestore Rules.
  static String normalizePlatformName({
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    if (isWeb) return 'web';
    final raw = platform.name.toLowerCase();
    if (_allowedPlatforms.contains(raw)) return raw;
    return 'other';
  }

  /// Decide localmente (0 lecturas de Firestore) si corresponde sincronizar el registro.
  static bool shouldSyncDeviceRegistration({
    required SharedPreferences prefs,
    required String appVersion,
    required int nowMs,
    String? fcmToken,
  }) {
    final registeredOnce = prefs.getBool(keyRegisteredOnce) ?? false;
    if (!registeredOnce) return true;

    final lastVersion = prefs.getString(keyLastVersion) ?? '';
    if (lastVersion != appVersion) return true;

    final lastSyncMs = prefs.getInt(keyLastSyncMs) ?? 0;
    if (nowMs - lastSyncMs >= syncInterval.inMilliseconds) return true;

    final trimmedToken = (fcmToken ?? '').trim();
    if (trimmedToken.isNotEmpty) {
      final lastToken = prefs.getString(keyLastFcmToken) ?? '';
      if (trimmedToken != lastToken) return true;
    }

    return false;
  }

  /// Construye el payload validado para `device_installs/{deviceId}`.
  static Map<String, Object?> buildDeviceInstallPayload({
    required String deviceId,
    required String platform,
    required String appVersion,
    required bool isFirstRegistration,
    String? fcmToken,
  }) {
    final safeVersion =
        appVersion.length > 40 ? appVersion.substring(0, 40) : appVersion;
    final trimmedToken = (fcmToken ?? '').trim();
    final hasValidToken =
        trimmedToken.isNotEmpty && trimmedToken.length <= 512;

    final payload = <String, Object?>{
      'deviceId': deviceId,
      'platform': _allowedPlatforms.contains(platform) ? platform : 'other',
      'appVersion': safeVersion.isEmpty ? 'unknown' : safeVersion,
      'installStatus': 'active',
      'lastSeenAt': FieldValue.serverTimestamp(),
      'hasFcmToken': hasValidToken,
    };

    if (isFirstRegistration) {
      payload['firstSeenAt'] = FieldValue.serverTimestamp();
    }

    if (hasValidToken) {
      payload['fcmToken'] = trimmedToken;
      payload['fcmUpdatedAt'] = FieldValue.serverTimestamp();
    }

    return payload;
  }

  /// Inicializa Firebase Analytics y registra la apertura sin bloquear la app.
  static Future<void> initAnalyticsSilently() async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      await FirebaseAnalytics.instance.logAppOpen();
    } catch (e) {
      debugPrint('>>> Analytics omitido silenciosamente: $e');
    }
  }

  /// Sincroniza el dispositivo en `device_installs/{deviceId}` solo si cambió la
  /// versión, pasaron 7 días o llegó un token FCM nuevo.
  static Future<void> syncDeviceRegistration({String? fcmToken}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final info = await PackageInfo.fromPlatform();
      final rawVersion = info.buildNumber.isNotEmpty
          ? '${info.version}+${info.buildNumber}'
          : info.version;
      final appVersion = rawVersion.trim().isEmpty ? '1.0.37+42' : rawVersion.trim();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (!shouldSyncDeviceRegistration(
        prefs: prefs,
        appVersion: appVersion,
        nowMs: nowMs,
        fcmToken: fcmToken,
      )) {
        return;
      }

      final deviceId = await getOrCreateDeviceId(prefs);
      final isFirstRegistration = !(prefs.getBool(keyRegisteredOnce) ?? false);
      final platform = normalizePlatformName(
        isWeb: kIsWeb,
        platform: defaultTargetPlatform,
      );

      final payload = buildDeviceInstallPayload(
        deviceId: deviceId,
        platform: platform,
        appVersion: appVersion,
        isFirstRegistration: isFirstRegistration,
        fcmToken: fcmToken,
      );

      await FirebaseFirestore.instance
          .collection('device_installs')
          .doc(deviceId)
          .set(payload, SetOptions(merge: true));

      await prefs.setBool(keyRegisteredOnce, true);
      await prefs.setString(keyLastVersion, appVersion);
      await prefs.setInt(keyLastSyncMs, nowMs);
      final trimmedToken = (fcmToken ?? '').trim();
      if (trimmedToken.isNotEmpty && trimmedToken.length <= 512) {
        await prefs.setString(keyLastFcmToken, trimmedToken);
      }
    } catch (e) {
      debugPrint('>>> Registro de dispositivo diferido (offline/red): $e');
    }
  }
}

