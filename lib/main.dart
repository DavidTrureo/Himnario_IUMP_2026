import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audio_session/audio_session.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';

import 'package:google_fonts/google_fonts.dart';
import 'features/hymns/domain/hymn.dart';

void main() async {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A), // Slate 900
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  WidgetsFlutterBinding.ensureInitialized();
  

  try {
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

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        // reCAPTCHA v3 site key para la web
        webProvider: ReCaptchaV3Provider('6LeCoostAAAAADjlTZgUZk3KXlf0neU9S-FV3so5'),
      );
    } catch (e) {
      debugPrint('Error inicializando Firebase App Check: $e');
    }

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

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Himnario IUMP',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
