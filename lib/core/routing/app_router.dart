import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../features/hymns/presentation/hymn_scanner_screen.dart';
import '../../features/hymns/presentation/admin_suggestions_screen.dart';


final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final GlobalKey<NavigatorState> _shellNavigatorSetlistsKey = GlobalKey<NavigatorState>(debugLabel: 'shellSetlists');
final GlobalKey<NavigatorState> _shellNavigatorFavoritesKey = GlobalKey<NavigatorState>(debugLabel: 'shellFavorites');
final GlobalKey<NavigatorState> _shellNavigatorToolsKey = GlobalKey<NavigatorState>(debugLabel: 'shellTools');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
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
            ),
          ],
        ),
      ],
    ),
    // Rutas fuera del BottomNavigationBar
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/hymns',
      builder: (context, state) => const HymnListScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/hymn/:id',
      builder: (context, state) {
        final hymnId = state.pathParameters['id']!;
        return HymnDetailScreen(hymnId: hymnId);
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
      path: '/setlist-detail',
      builder: (context, state) => const SetlistDetailScreen(),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/admin-suggestions',
      builder: (context, state) => AdminSuggestionsScreen(),
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

