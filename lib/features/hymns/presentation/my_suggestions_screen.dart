import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/suggestion_tracking_service.dart';
import '../domain/hymn.dart';

class MySuggestionsScreen extends ConsumerStatefulWidget {
  const MySuggestionsScreen({super.key});

  @override
  ConsumerState<MySuggestionsScreen> createState() => _MySuggestionsScreenState();
}

class _MySuggestionsScreenState extends ConsumerState<MySuggestionsScreen> {
  List<SubmittedSuggestion> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);
    final list = await SuggestionTrackingService.getSubmittedSuggestions();
    if (mounted) {
      setState(() {
        _suggestions = list;
        _isLoading = false;
      });
    }
  }

  String _collectionLabel(String col) {
    switch (col) {
      case 'iump':
        return 'Himnario IUMP';
      case 'coros':
        return 'Coros Unidos';
      case 'especiales':
        return 'Alabanzas Especiales';
      default:
        return col.toUpperCase();
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allHymns = ref.watch(allHymnsProvider).value ?? [];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Mis Sugerencias Enviadas',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // Fondo degradado sutil
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.08 : 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.08 : 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_suggestions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No tienes sugerencias enviadas aún',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cuando sugieras agregar o corregir un canto al catálogo oficial, podrás seguir aquí el estado de revisión del administrador.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.push('/add-hymn'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Sugerir un Canto'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _loadSuggestions,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final item = _suggestions[index];

                  // Verificar si ya fue publicado en el himnario oficial
                  final matchingHymn = allHymns.where((h) => !h.isLocalOnly).cast<Hymn?>().firstWhere(
                    (h) => h != null && (
                      (item.publishedId != null && h.id == item.publishedId && h.collection == (item.publishedCollection ?? item.collection)) ||
                      (h.title.toUpperCase() == item.title.toUpperCase())
                    ),
                    orElse: () => null,
                  );

                  final bool isPublished = item.status == 'approved' || matchingHymn != null;
                  final bool isRejected = item.status == 'rejected';

                  // Si se detectó publicado y no estaba marcado, actualizarlo en local
                  if (matchingHymn != null && item.status != 'approved') {
                    SuggestionTrackingService.updateSuggestionStatus(
                      item.docId,
                      status: 'approved',
                      publishedId: matchingHymn.id,
                      publishedCollection: matchingHymn.collection,
                    );
                  }

                  final statusColor = isPublished
                      ? const Color(0xFF10B981)
                      : (isRejected ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

                  final statusLabel = isPublished
                      ? 'Gestionado por Administrador (Aprobado)'
                      : (isRejected ? 'Gestionado por Administrador (No publicado)' : 'En revisión por el Administrador');

                  final statusIcon = isPublished
                      ? Icons.check_circle_rounded
                      : (isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? const Color(0xFF1E293B).withValues(alpha: 0.7) 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.08) 
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _collectionLabel(item.collection),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          if (item.type == 'correction')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.build_circle_outlined, size: 14, color: Color(0xFF0EA5E9)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Propuesta de corrección / mejora para: ${item.targetTitle ?? 'Canto existente'}',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0EA5E9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 13, color: isDark ? Colors.white54 : Colors.black45),
                              const SizedBox(width: 4),
                              Text(
                                'Enviado el ${_formatDate(item.date)}',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                              if (item.requesterName.isNotEmpty) ...[
                                const Text(' • '),
                                Flexible(
                                  child: Text(
                                    '${item.requesterName} (${item.requesterChurch})',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Estado de la sugerencia
                          Row(
                            children: [
                              Icon(statusIcon, size: 16, color: statusColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              if (isPublished && matchingHymn != null)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    foregroundColor: const Color(0xFF10B981),
                                  ),
                                  onPressed: () {
                                    context.push('/hymn/${matchingHymn.collection}/${matchingHymn.id}');
                                  },
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                  label: Text(
                                    'Ver N° ${matchingHymn.id}',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          if (!isPublished && !isRejected)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0, left: 22.0),
                              child: Text(
                                'El administrador revisará la letra, el formato y la agregará próximamente a la base de datos oficial.',
                                style: GoogleFonts.nunito(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
