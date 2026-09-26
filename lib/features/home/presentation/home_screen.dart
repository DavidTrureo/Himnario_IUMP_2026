import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../hymns/presentation/hymn_scanner_screen.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../hymns/presentation/hymn_list_screen.dart';
import '../../hymns/domain/hymn.dart';
import '../../favorites/domain/favorites_notifier.dart';
import '../../setlists/presentation/setlists_provider.dart';
import '../../hymns/presentation/admin_suggestions_screen.dart';
import '../../../core/widgets/app_music_icons.dart';

class AdminTapCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
  void reset() => state = 0;
}

final adminTapCountProvider = NotifierProvider<AdminTapCountNotifier, int>(() {
  return AdminTapCountNotifier();
});


final pendingSuggestionsProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance
      .collection('cantos_sugeridos')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) => snap.docs.length);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final iumpCount = ref.watch(hymnsProvider('iump')).when(
      data: (list) => list.length.toString(),
      loading: () => '...',
      error: (e, s) => '490',
    );
    final especialesCount = ref.watch(hymnsProvider('especiales')).when(
      data: (list) => list.length.toString(),
      loading: () => '...',
      error: (e, s) => '870',
    );
    final corosCount = ref.watch(hymnsProvider('coros')).when(
      data: (list) => list.length.toString(),
      loading: () => '...',
      error: (e, s) => '109',
    );
    final favoritesCount = ref.watch(favoritesProvider).length.toString();
    final acordesCount = ref.watch(allHymnsGlobalProvider).when(
      data: (list) => list.where((h) => h.lyrics.contains('[')).length.toString(),
      loading: () => '...',
      error: (e, s) => '0',
    );
    final setlistsCount = ref.watch(setlistsProvider).when(
      data: (list) => list.length.toString(),
      loading: () => '...',
      error: (e, s) => '0',
    );

    return Scaffold(
      body: Stack(
        children: [
          // Fondo base gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                  ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                  : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
              ),
            ),
          ),
          
          // Círculo decorativo aurora superior derecha
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: isDark 
                  ? const Color(0xFF6366F1).withValues(alpha: 0.18) 
                  : const Color(0xFF818CF8).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Círculo decorativo aurora inferior izquierda
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: isDark 
                  ? const Color(0xFFEC4899).withValues(alpha: 0.12) 
                  : const Color(0xFFF472B6).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Capa decorativa suave (sin BackdropFilter para no bloquear GPU en Web)
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
            ),
          ),
          
          // Contenido principal
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Título e icono)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final count = ref.read(adminTapCountProvider);
                          if (count < 4) {
                            ref.read(adminTapCountProvider.notifier).increment();
                          } else {
                            ref.read(adminTapCountProvider.notifier).reset();
                            _showAdminPasswordPrompt(context, ref);
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark 
                              ? Colors.white.withValues(alpha: 0.04) 
                              : theme.colorScheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark 
                                ? Colors.white.withValues(alpha: 0.08) 
                                : theme.colorScheme.primary.withValues(alpha: 0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                              )
                            ]
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(17),
                            child: Image.asset(
                              'assets/images/church_logo_clean.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Himnos & Alabanzas',
                                  style: GoogleFonts.outfit(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : theme.colorScheme.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (ref.watch(adminModeProvider)) ...[
                                  const SizedBox(width: 8),
                                  const Tooltip(
                                    message: 'Modo Administrador Activo',
                                    child: Icon(
                                      Icons.admin_panel_settings_rounded, 
                                      color: Colors.amber, 
                                      size: 22
                                    ),
                                  ).animate().shake(delay: 200.ms),
                                ],
                              ],
                            ),
                            Text(
                              'Iglesia Primera San Bernardo',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
                
                // Buscador Rápido (Navegación Hero a Listado)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
                  child: Hero(
                    tag: 'search-bar',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          readOnly: true,
                          onTap: () {
                            ref.read(showFavoritesProvider.notifier).setFavorites(false);
                            ref.read(searchQueryProvider.notifier).updateQuery('');
                            ref.read(activeCollectionProvider.notifier).setCollection('all');
                            ref.read(activeCategoryProvider.notifier).setCategory('Todos');
                            context.push('/home/hymns', extra: {'autoFocusSearch': true});
                          },
                          decoration: InputDecoration(
                            hintText: 'Buscar por título, letra o número...',
                            hintStyle: GoogleFonts.nunito(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: isDark ? Colors.white60 : theme.colorScheme.primary.withValues(alpha: 0.6),
                            ),
                            filled: true,
                            fillColor: isDark 
                              ? Colors.white.withValues(alpha: 0.04) 
                              : Colors.white.withValues(alpha: 0.85),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18.0),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18.0),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),

                // Lista de Opciones
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                    decoration: BoxDecoration(
                      color: isDark 
                        ? const Color(0xFF0B1329).withValues(alpha: 0.5) 
                        : Colors.white.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(36),
                        topRight: Radius.circular(36),
                      ),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.01),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(36),
                        topRight: Radius.circular(36),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 120),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildMenuItem(
                            context,
                            ref: ref,
                            title: 'Himnario IUMP',
                            subtitle: 'Alabanzas congregacionales',
                            icon: Icons.auto_stories_rounded,
                            iconColor: const Color(0xFF3B82F6),
                            collection: 'iump',
                            counter: iumpCount,
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
                          const SizedBox(height: 16),
                          _buildMenuItem(
                            context,
                            ref: ref,
                            title: 'Alabanzas Especiales',
                            subtitle: 'Oportunidades, Coro Instrumental y Niños',
                            icon: Icons.music_note_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            collection: 'especiales',
                            counter: especialesCount,
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15),
                          const SizedBox(height: 16),
                          _buildMenuItem(
                            context,
                            ref: ref,
                            title: 'Coros de Avivamiento',
                            subtitle: 'Coros alegres y de adoración',
                            icon: Icons.favorite_rounded,
                            iconColor: const Color(0xFF10B981),
                            collection: 'coros',
                            counter: corosCount,
                          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.15),

                          const SizedBox(height: 16),
                          _buildMenuItem(
                            context,
                            ref: ref,
                            title: 'Acordes & Guías',
                            subtitle: 'Cifrado musical para instrumentos',
                            icon: Icons.queue_music_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            collection: 'acordes',
                            counter: acordesCount,
                          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.15),

                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    String? collection,
    bool isFavoritesOnly = false,
    bool isSetlists = false,
    bool isComingSoon = false,
    bool isAbout = false,
    bool isScanner = false,
    bool isQrScanner = false,
    bool isAdminSuggestions = false,
    String? counter,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
              ? (kIsWeb
                  ? const Color(0xFF1E293B).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.04))
              : (kIsWeb
                  ? Colors.white.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isComingSoon 
                ? () => _showComingSoon(context)
                : isScanner
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HymnScannerScreen()))
                  : () {
                      if (isSetlists) {
                        context.push('/setlists');
                        return;
                      }
                      if (isFavoritesOnly) {
                        ref.read(showFavoritesProvider.notifier).setFavorites(true);
                      } else {
                        ref.read(activeCollectionProvider.notifier).setCollection(collection!);
                        ref.read(showFavoritesProvider.notifier).setFavorites(false);
                      }
                      ref.read(searchQueryProvider.notifier).updateQuery('');
                      ref.read(activeCategoryProvider.notifier).setCategory('Todos');
                      context.push('/home/hymns');
                    },
              borderRadius: BorderRadius.circular(24),
              splashColor: iconColor.withValues(alpha: 0.1),
              highlightColor: iconColor.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Icono con gradiente de fondo
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            iconColor.withValues(alpha: isDark ? 0.25 : 0.15),
                            iconColor.withValues(alpha: isDark ? 0.08 : 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: iconColor.withValues(alpha: isDark ? 0.2 : 0.15),
                          width: 1,
                          ),
                        ),
                        child: Icon(icon, color: iconColor, size: 26),
                      ),
                      const SizedBox(width: 16),
                      // Textos del Menú
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Contador de cantos (Pill badge)
                      if (counter != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: iconColor.withValues(alpha: isDark ? 0.25 : 0.15),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            counter,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? iconColor.withValues(alpha: 0.9) : iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Flecha indicadora
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded, 
                          color: isDark ? Colors.white38 : Colors.black26, 
                          size: 12
                        ),
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

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'Próximamente disponible en futuras versiones.',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  void _showAdminPasswordPrompt(BuildContext context, WidgetRef ref) {
    final adminMode = ref.read(adminModeProvider);
    if (adminMode) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Modo Administrador',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Text(
              '¿Deseas desactivar el modo de administración en este dispositivo?',
              style: GoogleFonts.nunito(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar', style: GoogleFonts.nunito()),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await ref.read(adminModeProvider.notifier).deactivate();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Modo Administrador desactivado', style: GoogleFonts.nunito()),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: Text('Desactivar', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
      return;
    }

    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Activar Modo Administrador',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ingresa la contraseña de superusuario para habilitar la edición de himnos.',
                  style: GoogleFonts.nunito(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña de Acceso',
                    labelStyle: GoogleFonts.nunito(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingresa una contraseña';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.nunito()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final success = await ref
                      .read(adminModeProvider.notifier)
                      .verifyAndActivate(passwordController.text);
                  
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('¡Modo Administrador activado con éxito!', style: GoogleFonts.nunito()),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Contraseña incorrecta', style: GoogleFonts.nunito()),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                  }
                }
              },
              child: Text('Activar', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showMissionInfoDialog(BuildContext context, bool isDark, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logotipos (Iglesia Local a la izquierda, Misión a la derecha)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo de la Iglesia Local (A la izquierda)
                  Container(
                    padding: const EdgeInsets.all(12),
                    height: 130,
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/church_logo_clean.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Logo de la Misión (A la derecha)
                  Container(
                    padding: const EdgeInsets.all(12),
                    height: 130,
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/mission_logo_v3.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Nombres
              Text(
                'Iglesia Unida\nMetodista Pentecostal',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : theme.colorScheme.primary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Iglesia Primera San Bernardo',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[800],
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nuestra congregación local es miembro activo de esta honorable misión nacional, consagrados a la adoración y evangelización.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // Botón Canal de YouTube
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000), // Rojo YouTube
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
                label: Text(
                  'Ver Canal de YouTube',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onPressed: () async {
                  final url = Uri.parse('https://www.youtube.com/@primeradesanbernardo');
                  try {
                    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
                    if (!launched) {
                      await launchUrl(url, mode: LaunchMode.platformDefault);
                    }
                  } catch (e) {
                    await launchUrl(url, mode: LaunchMode.platformDefault);
                  }
                },
              ),
              const Divider(height: 32),
              Text(
                'Desarrollado por David Trureo Ahumada',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cerrar',
                  style: GoogleFonts.nunito(
                    color: isDark ? Colors.white60 : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


