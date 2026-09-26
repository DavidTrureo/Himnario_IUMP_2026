import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class MainLayoutScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayoutScreen({
    super.key,
    required this.navigationShell,
  });

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && navigationShell.currentIndex != 0) {
          _goBranch(0);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;
          
          if (isTablet) {
            // Diseño para Tablet/Escritorio (NavigationRail a la izquierda)
            return Scaffold(
              backgroundColor: theme.colorScheme.surface,
              body: Row(
                children: [
                  Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A), // Slate 900
                      border: Border(
                        right: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RailItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: 'Inicio',
                          isSelected: navigationShell.currentIndex == 0,
                          onTap: () => _goBranch(0),
                          theme: theme,
                        ),
                        const SizedBox(height: 32),
                        _RailItem(
                          icon: Icons.queue_music_outlined,
                          activeIcon: Icons.queue_music_rounded,
                          label: 'Listas',
                          isSelected: navigationShell.currentIndex == 1,
                          onTap: () => _goBranch(1),
                          theme: theme,
                        ),
                        const SizedBox(height: 32),
                        _RailItem(
                          icon: Icons.favorite_outline_rounded,
                          activeIcon: Icons.favorite_rounded,
                          label: 'Favoritos',
                          isSelected: navigationShell.currentIndex == 2,
                          onTap: () => _goBranch(2),
                          theme: theme,
                        ),
                        const SizedBox(height: 32),
                        _RailItem(
                          icon: Icons.apps_rounded,
                          activeIcon: Icons.apps_rounded,
                          label: 'Más',
                          isSelected: navigationShell.currentIndex == 3,
                          onTap: () => _goBranch(3),
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRect(child: navigationShell),
                  ),
                ],
              ),
            );
          }

          // Diseño Móvil (BottomNavigationBar flotante)
          return Scaffold(
            extendBody: true,
            body: navigationShell,
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.65), // Slate 800
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _NavBarItem(
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'Inicio',
                            isSelected: navigationShell.currentIndex == 0,
                            onTap: () => _goBranch(0),
                            theme: theme,
                          ),
                          _NavBarItem(
                            icon: Icons.queue_music_outlined,
                            activeIcon: Icons.queue_music_rounded,
                            label: 'Listas',
                            isSelected: navigationShell.currentIndex == 1,
                            onTap: () => _goBranch(1),
                            theme: theme,
                          ),
                          _NavBarItem(
                            icon: Icons.favorite_outline_rounded,
                            activeIcon: Icons.favorite_rounded,
                            label: 'Favoritos',
                            isSelected: navigationShell.currentIndex == 2,
                            onTap: () => _goBranch(2),
                            theme: theme,
                          ),
                          _NavBarItem(
                            icon: Icons.apps_rounded,
                            activeIcon: Icons.apps_rounded,
                            label: 'Más',
                            isSelected: navigationShell.currentIndex == 3,
                            onTap: () => _goBranch(3),
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _RailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        width: 72,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? theme.colorScheme.primary : const Color(0xFF94A3B8),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? theme.colorScheme.primary : const Color(0xFF94A3B8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? theme.colorScheme.primary : const Color(0xFF94A3B8), // Slate 400
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
