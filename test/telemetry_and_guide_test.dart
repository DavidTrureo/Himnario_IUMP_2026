import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:himnario_iump/core/services/app_telemetry_service.dart';
import 'package:himnario_iump/core/services/global_audio_service.dart';
import 'package:himnario_iump/features/favorites/domain/favorites_notifier.dart';
import 'package:himnario_iump/features/home/presentation/feature_guide_screen.dart';
import 'package:himnario_iump/features/home/presentation/tools_screen.dart';
import 'package:himnario_iump/features/hymns/domain/hymn.dart';
import 'package:himnario_iump/features/hymns/presentation/admin_dashboard_screen.dart';
import 'package:himnario_iump/features/hymns/presentation/hymn_detail_screen.dart';
import 'package:himnario_iump/features/hymns/presentation/hymn_list_screen.dart';

class _MockAdminModeNotifier extends AdminModeNotifier {
  final bool initial;
  _MockAdminModeNotifier(this.initial);

  @override
  bool build() => initial;
}

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

  group('AdminDashboardScreen Tests', () {
    testWidgets('Muestra Acceso Restringido cuando no es admin', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminModeProvider.overrideWith(() => _MockAdminModeNotifier(false)),
          ],
          child: const MaterialApp(
            home: AdminDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acceso Restringido'), findsOneWidget);
      expect(find.text('Volver al Inicio'), findsOneWidget);
    });

    testWidgets('Muestra Panel de Control Oficial cuando es admin', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminModeProvider.overrideWith(() => _MockAdminModeNotifier(true)),
          ],
          child: const MaterialApp(
            home: AdminDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Panel de Control Oficial'), findsOneWidget);
      expect(find.text('Administrador Oficial'), findsOneWidget);
      expect(find.text('Pulso del Himnario en Tiempo Real'), findsOneWidget);
      expect(find.text('Gestión de Contenido y Cantos'), findsOneWidget);
    });
  });

  group('ToolsScreen Tests', () {
    testWidgets('Herramientas no contiene el Centro de Control duplicado', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminModeProvider.overrideWith(() => _MockAdminModeNotifier(true)),
          ],
          child: const MaterialApp(
            home: ToolsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Centro de Control Oficial (Admin)'), findsNothing);
      expect(find.text('Guía Rápida de Funciones'), findsOneWidget);
    });
  });

  group('HymnDetailScreen Audio Management Tests', () {
    test('stopGlobalAudio limpia sin arrojar excepciones incluso si no hay reproductor activo', () {
      expect(() => HymnDetailScreen.stopGlobalAudio(), returnsNormally);
    });

    test('globalAudioProvider inicializa en estado inactivo y stopAndClose limpia', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(globalAudioProvider);
      expect(state.isPlaying, isFalse);
      expect(state.isVisible, isFalse);
      expect(state.hymn, isNull);

      await container.read(globalAudioProvider.notifier).stopAndClose();
      expect(container.read(globalAudioProvider).isVisible, isFalse);
    });
  });

  group('Search & Favorites UX Tests', () {
    test('favoritesSearchQueryProvider es independiente de searchQueryProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(searchQueryProvider), isEmpty);
      expect(container.read(favoritesSearchQueryProvider), isEmpty);

      container.read(searchQueryProvider.notifier).updateQueryImmediately('gracia');
      expect(container.read(searchQueryProvider), 'gracia');
      expect(container.read(favoritesSearchQueryProvider), isEmpty);

      container.read(favoritesSearchQueryProvider.notifier).updateQueryImmediately('250');
      expect(container.read(searchQueryProvider), 'gracia');
      expect(container.read(favoritesSearchQueryProvider), '250');
    });

    test('suggestedFavoritesHymnsProvider excluye cantos que ya están en favoritos', () async {
      final container = ProviderContainer(
        overrides: [
          favoritesProvider.overrideWith(() => FavoritesNotifier()),
          allHymnsGlobalProvider.overrideWith(
            (ref) => AsyncValue.data([
              Hymn(
                id: 1,
                title: 'Canto Uno',
                lyrics: 'letra uno',
                toneNote: 'DO',
                beats: '80',
                timeSignature: '4/4',
                category: 'Alabanza',
                collection: 'iump',
              ),
              Hymn(
                id: 2,
                title: 'Canto Dos',
                lyrics: 'letra dos',
                toneNote: 'RE',
                beats: '90',
                timeSignature: '3/4',
                category: 'Adoración',
                collection: 'iump',
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Si query está vacía, no sugiere nada
      expect(container.read(suggestedFavoritesHymnsProvider), isEmpty);

      // Añadimos 'iump-1' a favoritos
      await container.read(favoritesProvider.notifier).toggleFavorite('iump-1');

      // Buscamos 'Canto'
      container.read(favoritesSearchQueryProvider.notifier).updateQueryImmediately('Canto');

      final suggestions = container.read(suggestedFavoritesHymnsProvider);
      // Solo debe sugerir 'Canto Dos' porque 'Canto Uno' ya está en favoritos
      expect(suggestions.length, 1);
      expect(suggestions.first.id, 2);
    });
  });
}
