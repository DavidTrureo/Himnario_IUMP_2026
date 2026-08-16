import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audio_session/audio_session.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/home/presentation/splash_screen.dart';
import 'features/hymns/presentation/hymn_list_screen.dart';
import 'features/hymns/presentation/hymn_detail_screen.dart';
import 'features/setlists/presentation/setlists_list_screen.dart';
import 'features/setlists/presentation/setlist_detail_screen.dart';
import 'features/tuner/presentation/instrument_tuner_screen.dart';
import 'features/live_worship/presentation/live_worship_screen.dart';
import 'features/live_worship/presentation/qr_scanner_screen.dart';
import 'features/hymns/presentation/detached_projector_screen.dart';

import 'package:google_fonts/google_fonts.dart';
import 'features/hymns/domain/hymn.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // En Web no descargamos fuentes en runtime: causa peticiones bloqueantes.
  // Se usan las fuentes del sistema o las precargadas en build.
  GoogleFonts.config.allowRuntimeFetching = false;

  try {
    // Precargar todos los catálogos en memoria RAM (0.01s)
    await Hymn.preloadAssets();

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.all(24),
          alignment: Alignment.center,
          color: const Color(0xFF0F172A),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.health_and_safety_rounded, size: 54, color: Colors.indigoAccent),
              const SizedBox(height: 14),
              const Text(
                'Protección Anti-Caídas Activa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Se ha aislado un detalle visual temporal para prevenir que la aplicación se cierre.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    };

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize FCM safely
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      messaging.getToken().then((token) {
        debugPrint('FCM Token: $token');
      }).catchError((e) {
        debugPrint('Error getting FCM token: $e');
      });
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }

    // Habilitar persistencia offline indefinida para Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    // Mantener la pantalla encendida mientras la app esté abierta
    try {
      WakelockPlus.enable();
    } catch (e) {
      debugPrint('Wakelock no soportado: $e');
    }

    await AudioSession.instance.then((session) async {
      await session.configure(const AudioSessionConfiguration.music());
    });

    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    // Si hay un error fatal antes de que inicie la app, mostramos una pantalla de error.
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  const Text('Error Crítico al Iniciar', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text(e.toString(), style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
                  const SizedBox(height: 10),
                  Text(stackTrace.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Configuración de GoRouter
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/hymns',
      builder: (context, state) => const HymnListScreen(),
    ),
    GoRoute(
      path: '/hymn/:id',
      builder: (context, state) {
        final hymnId = state.pathParameters['id']!;
        return HymnDetailScreen(hymnId: hymnId);
      },
    ),
    GoRoute(
      path: '/projector-view/:collection/:id',
      builder: (context, state) {
        final collection = state.pathParameters['collection']!;
        final hymnId = state.pathParameters['id']!;
        return DetachedProjectorScreen(collection: collection, hymnId: hymnId);
      },
    ),
    GoRoute(
      path: '/setlists',
      builder: (context, state) => const SetlistsListScreen(),
    ),
    GoRoute(
      path: '/setlist-detail',
      builder: (context, state) => const SetlistDetailScreen(),
    ),
    GoRoute(
      path: '/tuner',
      builder: (context, state) => const InstrumentTunerScreen(),
    ),
    GoRoute(
      path: '/scan-qr',
      builder: (context, state) => const QrScannerScreen(),
    ),
    GoRoute(
      path: '/culto-en-vivo/:sessionId',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return LiveWorshipScreen(sessionId: sessionId);
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Himnario IUMP',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Cambia automáticamente según el OS
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
