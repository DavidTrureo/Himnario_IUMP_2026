import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/splash_screen.dart';
import '../../features/hymns/presentation/hymn_list_screen.dart';
import '../../features/hymns/presentation/hymn_detail_screen.dart';
import '../../features/setlists/presentation/setlists_list_screen.dart';
import '../../features/setlists/presentation/setlist_detail_screen.dart';
import '../../features/live_worship/presentation/live_worship_screen.dart';
import '../../features/live_worship/presentation/qr_scanner_screen.dart';
import '../../features/hymns/presentation/detached_projector_screen.dart';
import '../widgets/main_layout_screen.dart';
import '../../features/home/presentation/tools_screen.dart';
import '../../features/home/presentation/church_about_screen.dart';
import '../../features/home/presentation/feature_guide_screen.dart';
import '../../features/hymns/presentation/hymn_scanner_screen.dart';
import '../../features/hymns/presentation/admin_suggestions_screen.dart';
import '../../features/hymns/presentation/admin_devices_screen.dart';
import '../../features/hymns/presentation/admin_dashboard_screen.dart';
import '../../features/hymns/presentation/hymn_tv_receiver_screen.dart';
import '../../features/hymns/presentation/tv_remote_control_screen.dart';
import '../../features/hymns/domain/hymn.dart';


final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final GlobalKey<NavigatorState> _shellNavigatorSetlistsKey = GlobalKey<NavigatorState>(debugLabel: 'shellSetlists');
final GlobalKey<NavigatorState> _shellNavigatorFavoritesKey = GlobalKey<NavigatorState>(debugLabel: 'shellFavorites');
final GlobalKey<NavigatorState> _shellNavigatorToolsKey = GlobalKey<NavigatorState>(debugLabel: 'shellTools');


// Reusable sub-routes para mantener el menú visible
final hymnDetailRoute = GoRoute(
  path: 'hymn/:id',
  builder: (context, state) {
    final hymnId = state.pathParameters['id']!;
    return HymnDetailScreen(hymnId: hymnId);
  },
);

final setlistDetailRoute = GoRoute(
  path: 'setlist-detail',
  builder: (context, state) => const SetlistDetailScreen(),
  routes: [
    GoRoute(
      path: 'hymn/:id',
      builder: (context, state) {
        final hymnId = state.pathParameters['id']!;
        return HymnDetailScreen(hymnId: hymnId);
      },
    ),
  ],
);

final hymnsListRoute = GoRoute(
  path: 'hymns',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>?;
    final autoFocus = extra?['autoFocusSearch'] as bool? ?? false;
    return HymnListScreen(autoFocusSearch: autoFocus);
  },
  routes: [hymnDetailRoute],
);

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final uri = state.uri;
    final loc = uri.toString();

    // Soporte para Deep Links con esquemas personalizados (ej: himnario://hymn/especiales-373 o himnario:/hymn/...)
    if (uri.scheme == 'himnario' || loc.startsWith('himnario:')) {
      final match = RegExp(r'(?:hymn|canto)/([a-zA-Z0-9_-]+)').firstMatch(loc);
      if (match != null) {
        final hymnId = match.group(1)!;
        return '/home/hymn/$hymnId';
      }
      return '/home';
    }

    return null;
  },
  errorBuilder: (context, state) {
    final loc = state.uri.toString();
    final match = RegExp(r'(?:hymn|canto)/([a-zA-Z0-9_-]+)').firstMatch(loc);
    if (match != null) {
      final hymnId = match.group(1)!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go('/home/hymn/$hymnId');
      });
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Página no encontrada',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => appRouter.go('/home'),
              child: const Text('Ir al Inicio'),
            ),
          ],
        ),
      ),
    );
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainLayoutScreen(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Home
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [hymnsListRoute, hymnDetailRoute],
            ),
          ],
        ),
        // Tab 2: Setlists
        StatefulShellBranch(
          navigatorKey: _shellNavigatorSetlistsKey,
          routes: [
            GoRoute(
              path: '/setlists',
              builder: (context, state) => const SetlistsListScreen(),
              routes: [setlistDetailRoute, hymnDetailRoute],
            ),
          ],
        ),
        // Tab 3: Favorites
        StatefulShellBranch(
          navigatorKey: _shellNavigatorFavoritesKey,
          routes: [
            GoRoute(
              path: '/favorites',
              builder: (context, state) => const HymnListScreen(isFavoritesTab: true),
              routes: [hymnDetailRoute],
            ),
          ],
        ),
        // Tab 4: Tools
        StatefulShellBranch(
          navigatorKey: _shellNavigatorToolsKey,
          routes: [
            GoRoute(
              path: '/tools',
              builder: (context, state) => const ToolsScreen(),
              routes: [
                GoRoute(
                  path: 'church',
                  builder: (context, state) => const ChurchAboutScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    // Rutas fuera del BottomNavigationBar
    // Soporte para Deep Links y enlaces compartidos (Web / App Links)
    GoRoute(
      path: '/hymn/:id',
      redirect: (context, state) {
        final hymnId = state.pathParameters['id']!;
        return '/home/hymn/$hymnId';
      },
    ),
    GoRoute(
      path: '/hymn/:collection/:id',
      redirect: (context, state) {
        final col = state.pathParameters['collection']!;
        final id = state.pathParameters['id']!;
        return '/home/hymn/$col-$id';
      },
    ),
    GoRoute(
      path: '/canto/:id',
      redirect: (context, state) {
        final hymnId = state.pathParameters['id']!;
        return '/home/hymn/$hymnId';
      },
    ),
    GoRoute(
      path: '/canto/:collection/:id',
      redirect: (context, state) {
        final col = state.pathParameters['collection']!;
        final id = state.pathParameters['id']!;
        return '/home/hymn/$col-$id';
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/projector-view/:collection/:id',
      builder: (context, state) {
        final collection = state.pathParameters['collection']!;
        final hymnId = state.pathParameters['id']!;
        return DetachedProjectorScreen(collection: collection, hymnId: hymnId);
      },
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/admin-dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/admin-suggestions',
      builder: (context, state) => AdminSuggestionsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/admin-devices',
      builder: (context, state) => const AdminDevicesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/guide',
      builder: (context, state) {
        final isOnboarding = state.uri.queryParameters['onboarding'] == '1';
        return FeatureGuideScreen(isOnboarding: isOnboarding);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tv',
      builder: (context, state) => const HymnTvReceiverScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/remote',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra == null) {
          return const Scaffold(body: Center(child: Text('Error: Falta información extra')));
        }
        final hymn = extra['hymn'] as Hymn;
        final roomId = extra['roomId'] as String;
        return TvRemoteControlScreen(hymn: hymn, roomId: roomId);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/scanner',
      builder: (context, state) => HymnScannerScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/scan-qr',
      builder: (context, state) => const QrScannerScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/culto-en-vivo/:sessionId',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return LiveWorshipScreen(sessionId: sessionId);
      },
    ),
  ],
);

