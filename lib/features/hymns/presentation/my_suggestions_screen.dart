import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/suggestion_tracking_service.dart';
import '../domain/hymn.dart';
import 'hymn_list_screen.dart';

class MySuggestionsScreen extends ConsumerStatefulWidget {
  const MySuggestionsScreen({super.key});

  @override
  ConsumerState<MySuggestionsScreen> createState() => _MySuggestionsScreenState();
}

class _MySuggestionsScreenState extends ConsumerState<MySuggestionsScreen> {
  List<SubmittedSuggestion> _suggestions = [];
  bool _isLoading = true;
  bool _isSyncingCloud = false;

  @override
  void initState() {
    super.initState();
    _loadAndSyncSuggestions();
  }

  Future<void> _loadAndSyncSuggestions() async {
    // 1. Mostrar inmediatamente el caché local para respuesta instantánea
    final localList = await SuggestionTrackingService.getSubmittedSuggestions();
    if (mounted) {
      setState(() {
        _suggestions = localList;
        _isLoading = false;
        _isSyncingCloud = localList.isNotEmpty;
      });
    }

    if (localList.isEmpty) return;

    // 2. Consultar en la nube el estado actualizado de cada sugerencia (aprobado / rechazado / pendiente)
    //    con comparación interna Antes vs. Después contra todo el catálogo oficial
    final currentHymns = ref.read(allHymnsGlobalProvider).value ?? [];
    final result = await SuggestionTrackingService.syncStatusesFromCloud(
      officialHymns: currentHymns,
    );

    // 3. Si hubo nuevos cantos aprobados, refrescar esas colecciones del catálogo oficial
    if (mounted && result.newlyApprovedCollections.isNotEmpty) {
      for (final col in result.newlyApprovedCollections) {
        ref.invalidate(hymnsProvider(col));
      }
    }

    if (mounted) {
      setState(() {
        _suggestions = result.suggestions;
        _isSyncingCloud = false;
      });
    }
  }

  Future<void> _removeLocalItem(SubmittedSuggestion item) async {
    await SuggestionTrackingService.removeSubmittedSuggestion(item.docId);
    if (mounted) {
      setState(() {
        _suggestions = _suggestions.where((s) => s.docId != item.docId).toList();
      });
    }
  }

  String _collectionLabel(String col) {
    switch (col) {
      case 'iump':
        return 'Himnario IUMP';
      case 'coros':
        return 'Coros de Avivamiento';
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
    final allHymnsAsync = ref.watch(allHymnsGlobalProvider);
    final allHymns = allHymnsAsync.value ?? [];
    final catalogReady = allHymnsAsync.hasValue && !allHymnsAsync.isLoading;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Mis Sugerencias Enviadas',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Actualizar estados',
            onPressed: _isSyncingCloud ? null : _loadAndSyncSuggestions,
            icon: _isSyncingCloud
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
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
                      'Cuando sugieras agregar o corregir un canto al catálogo oficial (desde el botón + o el Escáner IA), podrás seguir aquí el estado de revisión del administrador.',
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
            Column(
              children: [
                if (_isSyncingCloud)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAndSyncSuggestions,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final item = _suggestions[index];

                        // Respaldo: buscar si ya existe el canto publicado en el catálogo oficial
                        final targetCol = item.publishedCollection ?? item.collection;
                        final matchingHymn = allHymns.where((h) => !h.isLocalOnly).cast<Hymn?>().firstWhere(
                          (h) {
                            if (h == null) return false;
                            if (item.publishedId != null &&
                                h.id == item.publishedId &&
                                h.collection == targetCol) {
                              return true;
                            }
                            if (item.status == 'pending' &&
                                item.type != 'correction' &&
                                h.normalizedTitle == Hymn.normalizeString(item.title)) {
                              return true;
                            }
                            return false;
                          },
                          orElse: () => null,
                        );

                        final int? openId = item.publishedId ?? matchingHymn?.id;
                        final String openCol = item.publishedCollection ?? matchingHymn?.collection ?? item.collection;
                        final String? finalPublishedTitle = item.publishedTitle ?? matchingHymn?.title;

                        final bool wasApproved = item.status == 'approved' ||
                            (item.status == 'pending' && matchingHymn != null && item.type != 'correction');
                        final bool isRemoved = item.status == 'removed' ||
                            (wasApproved && catalogReady && openId != null && matchingHymn == null);
                        final bool isApproved = wasApproved && !isRemoved;
                        final bool isRejected = !wasApproved && !isRemoved && item.status == 'rejected';

                        final bool titleChanged = finalPublishedTitle != null &&
                            finalPublishedTitle.trim().toUpperCase() != item.title.trim().toUpperCase();
                        final bool wasPolishedByAdmin = item.editedByAdmin || titleChanged;

                        // Si se detectó publicado por coincidencia local y aún estaba pendiente, actualizarlo en caché
                        if (matchingHymn != null && item.status == 'pending' && item.type != 'correction') {
                          SuggestionTrackingService.updateSuggestionStatus(
                            item.docId,
                            status: 'approved',
                            publishedId: matchingHymn.id,
                            publishedCollection: matchingHymn.collection,
                            publishedTitle: matchingHymn.title,
                          );
                        }

                        final statusColor = isApproved
                            ? const Color(0xFF10B981)
                            : isRemoved
                                ? const Color(0xFF94A3B8)
                                : (isRejected ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

                        final String statusLabel;
                        if (isApproved) {
                          if (item.type == 'correction') {
                            statusLabel = 'Aprobado · Canto actualizado en catálogo';
                          } else if (wasPolishedByAdmin) {
                            statusLabel = 'Aprobado y publicado (con ajustes de formato)';
                          } else {
                            statusLabel = 'Aprobado y publicado en el catálogo oficial';
                          }
                        } else if (isRemoved) {
                          statusLabel = 'Retirado del catálogo oficial';
                        } else if (isRejected) {
                          statusLabel = 'No publicado por el Administrador';
                        } else {
                          statusLabel = 'En revisión por el Administrador';
                        }

                        final statusIcon = isApproved
                            ? (wasPolishedByAdmin ? Icons.auto_awesome_rounded : Icons.check_circle_rounded)
                            : isRemoved
                                ? Icons.inventory_2_outlined
                                : (isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded);

                        // Construir mensaje amable y claro según estado, fecha de incorporación y ajustes
                        String approvedMessage() {
                          final dateFragment = item.reviewedAt != null
                              ? ' el ${_formatDate(item.reviewedAt!)}'
                              : '';
                          final numFragment = openId != null ? ' como N° $openId' : '';
                          if (wasPolishedByAdmin) {
                            final editDetail = (item.adminEditSummary != null &&
                                    item.adminEditSummary!.trim().isNotEmpty)
                                ? item.adminEditSummary!.trim()
                                : 'ajustes de ortografía y formato';
                            final renameNote = titleChanged
                                ? ' Título oficial: "$finalPublishedTitle".'
                                : '';
                            return '¡Gracias por tu aporte! Incorporado$dateFragment$numFragment con $editDetail realizados por el administrador.$renameNote';
                          }
                          return '¡Muchas gracias por tu aporte! Incorporado oficialmente$dateFragment$numFragment para toda la congregación.';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isApproved
                                  ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                  : isRejected
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.06)),
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
                                        finalPublishedTitle ?? item.title,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _collectionLabel(openCol),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    if (isApproved || isRejected || isRemoved)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: () => _removeLocalItem(item),
                                          child: Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                              color: isDark ? Colors.white38 : Colors.black38,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                if (item.source == 'scanner_ia')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.document_scanner_rounded, size: 13, color: Color(0xFF8B5CF6)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Enviado desde Escáner Inteligente IA',
                                          style: GoogleFonts.nunito(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF8B5CF6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

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

                                // Línea de tiempo de fechas (Envío y Incorporación / Revisión)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
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
                                      ],
                                    ),
                                    if (item.reviewedAt != null && (isApproved || isRejected))
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isApproved
                                              ? 'Publicado el ${_formatDate(item.reviewedAt!)}'
                                              : 'Revisado el ${_formatDate(item.reviewedAt!)}',
                                          style: GoogleFonts.nunito(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (item.requesterName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline_rounded, size: 13, color: isDark ? Colors.white54 : Colors.black45),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${item.requesterName}${item.requesterChurch.isNotEmpty ? ' · ${item.requesterChurch}' : ''}',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.nunito(
                                            fontSize: 12,
                                            color: isDark ? Colors.white54 : Colors.black45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 10),

                                // Estado de la sugerencia
                                Row(
                                  children: [
                                    Icon(statusIcon, size: 17, color: statusColor),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        statusLabel,
                                        style: GoogleFonts.nunito(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                    if (isApproved && openId != null && matchingHymn != null)
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          foregroundColor: const Color(0xFF10B981),
                                        ),
                                        onPressed: () {
                                          context.push('/hymn-view/$openCol-$openId');
                                        },
                                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                        label: Text(
                                          'Ver N° $openId',
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),

                                if (isApproved)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0, left: 23.0),
                                    child: Text(
                                      approvedMessage(),
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        height: 1.38,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  )
                                else if (isRemoved)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0, left: 23.0),
                                    child: Text(
                                      'Este canto fue retirado posteriormente del catálogo oficial por el administrador.',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                else if (isRejected)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0, left: 23.0),
                                    child: Text(
                                      (item.rejectionReason != null && item.rejectionReason!.trim().isNotEmpty)
                                          ? 'Motivo: ${item.rejectionReason!.trim()}'
                                          : 'Esta sugerencia no fue incorporada al catálogo oficial (puede ya existir o no corresponder a la colección).',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0, left: 23.0),
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
                ),
              ],
            ),
        ],
      ),
    );
  }
}
