import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:himnario_iump/core/services/app_telemetry_service.dart';
import 'package:himnario_iump/features/home/presentation/feature_guide_screen.dart';

void main() {
  group('AppTelemetryService Tests', () {
    test('shouldSyncDeviceRegistration solo dispara al instalar, cambiar versión, cada 7 días o token nuevo', () async {
      const oneWeekMs = 7 * 24 * 60 * 60 * 1000;
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();

      // 1. Primera vez: debe registrar
      expect(
        AppTelemetryService.shouldSyncDeviceRegistration(
          prefs: prefs,
          appVersion: '1.0.37+42',
          nowMs: 1000,
        ),
        isTrue,
      );

      // Simulamos registro guardado
      await prefs.setBool(AppTelemetryService.keyRegisteredOnce, true);
      await prefs.setString(AppTelemetryService.keyLastVersion, '1.0.37+42');
      await prefs.setInt(AppTelemetryService.keyLastSyncMs, 1000);
      await prefs.setString(AppTelemetryService.keyLastFcmToken, 'token_abc');

      // 2. Mismo día, misma versión, mismo token: 0 escrituras
      expect(
        AppTelemetryService.shouldSyncDeviceRegistration(
          prefs: prefs,
          appVersion: '1.0.37+42',
          nowMs: 1000 + 60 * 60 * 1000,
          fcmToken: 'token_abc',
        ),
        isFalse,
      );

      // 3. Cambio de versión: debe sincronizar
      expect(
        AppTelemetryService.shouldSyncDeviceRegistration(
          prefs: prefs,
          appVersion: '1.0.38+43',
          nowMs: 1000 + 60 * 60 * 1000,
          fcmToken: 'token_abc',
        ),
        isTrue,
      );

      // 4. Token FCM nuevo: debe sincronizar
      expect(
        AppTelemetryService.shouldSyncDeviceRegistration(
          prefs: prefs,
          appVersion: '1.0.37+42',
          nowMs: 1000 + 60 * 60 * 1000,
          fcmToken: 'token_xyz',
        ),
        isTrue,
      );

      // 5. Pasados 7 días: debe refrescar lastSeenAt
      expect(
        AppTelemetryService.shouldSyncDeviceRegistration(
          prefs: prefs,
          appVersion: '1.0.37+42',
          nowMs: 1000 + oneWeekMs,
          fcmToken: 'token_abc',
        ),
        isTrue,
      );
    });

    test('normalizePlatformName y buildDeviceInstallPayload cumplen el esquema de Firestore Rules', () {
      expect(
        AppTelemetryService.normalizePlatformName(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        'web',
      );
      expect(
        AppTelemetryService.normalizePlatformName(
          isWeb: false,
          platform: TargetPlatform.iOS,
        ),
        'ios',
      );

      final payload = AppTelemetryService.buildDeviceInstallPayload(
        deviceId: 'dev_123456',
        platform: 'android',
        appVersion: '1.0.37+42',
        isFirstRegistration: true,
        fcmToken: 'fcm_token_example_12345',
      );

      expect(payload['deviceId'], 'dev_123456');
      expect(payload['platform'], 'android');
      expect(payload['appVersion'], '1.0.37+42');
      expect(payload['installStatus'], 'active');
      expect(payload['hasFcmToken'], isTrue);
      expect(payload.containsKey('firstSeenAt'), isTrue);
      expect(payload.containsKey('lastSeenAt'), isTrue);
      expect(payload.containsKey('fcmUpdatedAt'), isTrue);
    });
  });

  group('FeatureGuideScreen Tests', () {
    testWidgets('Muestra los slides de funciones y guarda flag al Omitir', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: FeatureGuideScreen(isOnboarding: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Más de 2.900 cantos siempre contigo'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Desliza y fija el canto en pantalla'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Acordes, tono ajustable y partituras'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Hermoso diseño PDF: con o sin acordes'), findsOneWidget);

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kFeatureGuideSeenKey), isTrue);
    });
  });
}
