import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/home/presentation/splash_screen.dart';
import 'features/hymns/presentation/hymn_list_screen.dart';
import 'features/hymns/presentation/hymn_detail_screen.dart';
import 'features/setlists/presentation/setlists_list_screen.dart';
import 'features/setlists/presentation/setlist_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ==========================================
  // [TEMPORAL] Purga de Alabanzas Especiales con Acordes
  // ==========================================
  try {
    final idsToDelete = ['250', '270', '332', '442', '448', '626'];
    final firestore = FirebaseFirestore.instance;
    for (final docId in idsToDelete) {
      debugPrint('>>> BORRANDO de Firestore (especiales): $docId');
      await firestore.collection('especiales').doc(docId).delete();
    }
    debugPrint('>>> PURGA DE ALABANZAS ESPECIALES COMPLETADA.');
  } catch (e) {
    debugPrint('>>> ERROR AL PURGAR DE FIRESTORE: $e');
  }
  // ==========================================
  
  // Mantener la pantalla encendida mientras la app esté abierta
  try {
    WakelockPlus.enable();
    debugPrint('>>> Wakelock habilitado: La pantalla no entrará en suspensión.');
  } catch (e) {
    debugPrint('>>> Error al habilitar Wakelock: $e');
  }
  
  runApp(
    // ProviderScope es necesario para Riverpod
    const ProviderScope(
      child: MyApp(),
    ),
  );
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
      path: '/setlists',
      builder: (context, state) => const SetlistsListScreen(),
    ),
    GoRoute(
      path: '/setlist-detail',
      builder: (context, state) => const SetlistDetailScreen(),
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
