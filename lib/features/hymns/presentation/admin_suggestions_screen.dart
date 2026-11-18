import 'dart:ui' as dart_ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:himnario_iump/core/services/gemini_ai_service.dart';
import 'package:himnario_iump/core/services/suggestion_tracking_service.dart';
import 'package:himnario_iump/features/hymns/domain/hymn.dart';
import 'hymn_list_screen.dart';
import 'widgets/hymn_structure_toolbar.dart';

class AdminSuggestionsScreen extends ConsumerStatefulWidget {
  const AdminSuggestionsScreen({super.key});

  @override
  ConsumerState<AdminSuggestionsScreen> createState() => _AdminSuggestionsScreenState();
}

class _AdminSuggestionsScreenState extends ConsumerState<AdminSuggestionsScreen> {
  String _collectionLabel(String col) {
    switch (col) {
      case 'iump':
        return 'IUMP';
      case 'coros':
        return 'COROS';
      case 'especiales':
        return 'ESPECIALES';
      default:
        return col.toUpperCase();
    }
  }

  String _collectionFullLabel(String col) {
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

  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    return '';
  }

  /// Detecta automáticamente (Antes vs. Después) si el administrador realizó ajustes
  /// de orden, ortografía, formato, acordes, título, tonalidad o colección.
  ({bool edited, String? summary}) _detectAdminEdits({
    required Map<String, dynamic> originalData,
    required String finalTitle,
    required String finalLyrics,
    required String finalCollection,
    required String finalKey,
  }) {
    final diff = SuggestionTrackingService.compareBeforeAfter(
      originalTitle: (originalData['title'] ?? '').toString(),
      originalLyrics: (originalData['lyrics'] ?? '').toString(),
      originalCollection: (originalData['collection'] ?? '').toString(),
      originalKey: (originalData['key'] ?? '').toString(),
      finalTitle: finalTitle,
      finalLyrics: finalLyrics,
      finalCollection: finalCollection,
      finalKey: finalKey,
    );
    return (edited: diff.wasEdited, summary: diff.summary);
  }

  /// Compara internamente la sugerencia original (Antes) con el canto oficial publicado (Después)
  /// para determinar con exactitud si fue modificado/ordenado por el administrador.
  ({bool edited, String summary, String displayTitle}) _resolveLiveEditStatus({
    required Map<String, dynamic> data,
    required Hymn? publishedHymn,
  }) {
    final originalTitle = (data['title'] ?? 'Sin título').toString();
    final storedPubTitle = (data['publishedTitle'] ?? originalTitle).toString();
    final origCol = (data['collection'] ?? 'especiales').toString();
    final pubCol = (data['publishedCollection'] ?? origCol).toString();
    final storedEdited = data['editedByAdmin'] == true;
    final storedSummary = data['adminEditSummary']?.toString().trim() ?? '';

    if (publishedHymn != null) {
      final diff = SuggestionTrackingService.compareBeforeAfter(
        originalTitle: originalTitle,
        originalLyrics: (data['lyrics'] ?? '').toString(),
        originalCollection: origCol,
        originalKey: (data['key'] ?? '').toString(),
        finalTitle: publishedHymn.title,
        finalLyrics: publishedHymn.lyrics,
        finalCollection: publishedHymn.collection,
        finalKey: publishedHymn.toneNote,
      );
      final isEdited = diff.wasEdited || storedEdited;
      final summary = diff.wasEdited
          ? (diff.summary ?? 'ajustes de formato')
          : (storedSummary.isNotEmpty ? storedSummary : 'ajustes de formato');
      return (
        edited: isEdited,
        summary: summary,
        displayTitle: publishedHymn.title,
      );
    }

    final fallbackEdited = storedEdited ||
        storedPubTitle.trim().toUpperCase() != originalTitle.trim().toUpperCase() ||
        pubCol != origCol;
    return (
      edited: fallbackEdited,
      summary: storedSummary.isNotEmpty ? storedSummary : 'ajustes de formato',
      displayTitle: storedPubTitle,
    );
  }

  /// Muestra una Ficha de Trazabilidad del Aporte al tocar un registro aprobado,
  /// con los datos del colaborador, línea de tiempo, curaduría editorial (Antes vs. Después) y botón directo al canto.
  void _showApprovedContributionSheet(
    BuildContext context, {
    required String docId,
    required Map<String, dynamic> data,
    required Hymn? publishedHymn,
    required bool isRemovedFromCatalog,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final originalTitle = (data['title'] ?? 'Sin título').toString();
    final origCol = (data['collection'] ?? 'especiales').toString();
    final pubCol = (data['publishedCollection'] ?? origCol).toString();
    final pubId = data['publishedId'] != null ? int.tryParse(data['publishedId'].toString()) : null;
    final requesterName = ((data['requesterName'] ?? data['suggestedByName']) as String?)?.trim() ?? '';
    final requesterChurch = ((data['requesterChurch'] ?? data['suggestedByChurch']) as String?)?.trim() ?? '';
    final type = data['type']?.toString() ?? 'new';
    final source = data['source']?.toString() ?? 'manual';
    final sentDate = _formatTimestamp(data['timestamp']);
    final approvedDate = _formatTimestamp(data['approvedAt']);

    final liveStatus = _resolveLiveEditStatus(data: data, publishedHymn: publishedHymn);
    final publishedTitle = liveStatus.displayTitle;
    final editedByAdmin = liveStatus.edited;
    final editSummary = liveStatus.summary;

    // Si detectamos cambios reales (ej. canto aprobado antes de Build 78 o editado después en el catálogo),
    // sincronizar en segundo plano con Firestore para que el dispositivo del usuario también lo refleje.
    if (editedByAdmin && (data['editedByAdmin'] != true || data['adminEditSummary'] != editSummary)) {
      FirebaseFirestore.instance.collection('cantos_sugeridos').doc(docId).update({
        'editedByAdmin': true,
        'adminEditSummary': editSummary,
        'publishedTitle': publishedTitle,
      }).catchError((_) {});
    }

    final originLabel = type == 'correction'
        ? 'Propuesta de mejora'
        : (source == 'scanner_ia' ? 'Escáner Inteligente IA' : 'Formulario Manual (+)');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(sheetCtx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ficha del Aporte Aprobado',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          publishedTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pubId != null
                              ? '${_collectionFullLabel(pubCol)} · N° $pubId'
                              : _collectionFullLabel(pubCol),
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bloque de Colaborador e Iglesia
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      icon: Icons.person_rounded,
                      color: const Color(0xFF38BDF8),
                      label: 'Colaborador',
                      value: requesterName.isNotEmpty ? requesterName : 'Sin nombre registrado',
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      icon: Icons.church_rounded,
                      color: const Color(0xFF818CF8),
                      label: 'Iglesia / Local',
                      value: requesterChurch.isNotEmpty ? requesterChurch : 'Sin iglesia registrada',
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      icon: source == 'scanner_ia' ? Icons.document_scanner_rounded : Icons.edit_note_rounded,
                      color: const Color(0xFF8B5CF6),
                      label: 'Origen del envío',
                      value: originLabel,
                      isDark: isDark,
                    ),
                    if (sentDate.isNotEmpty || approvedDate.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildDetailRow(
                        icon: Icons.schedule_rounded,
                        color: const Color(0xFFF59E0B),
                        label: 'Línea de tiempo',
                        value: [
                          if (sentDate.isNotEmpty) 'Enviado: $sentDate',
                          if (approvedDate.isNotEmpty) 'Publicado: $approvedDate',
                        ].join('  →  '),
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Bloque de Curaduría Editorial o Aviso de Retiro
              if (isRemovedFromCatalog)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Este canto ya no existe en el catálogo oficial (fue eliminado posteriormente). Puedes quitar este registro del historial.',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: (editedByAdmin ? const Color(0xFF0EA5E9) : const Color(0xFF10B981))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (editedByAdmin ? const Color(0xFF0EA5E9) : const Color(0xFF10B981))
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        editedByAdmin ? Icons.auto_awesome_rounded : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: editedByAdmin ? const Color(0xFF0EA5E9) : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              editedByAdmin
                                  ? 'Publicado con ${editSummary.isNotEmpty ? editSummary : 'ajustes de formato'} por el administrador'
                                  : 'Publicado sin modificaciones (tal como fue enviado)',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: editedByAdmin ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                              ),
                            ),
                            if (publishedTitle.trim().toUpperCase() != originalTitle.trim().toUpperCase())
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  'Título original enviado: "$originalTitle"',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ),
                            if (pubCol != origCol)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Colección sugerida: ${_collectionFullLabel(origCol)} → ${_collectionFullLabel(pubCol)}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),

              // Acciones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  if (isRemovedFromCatalog) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(sheetCtx);
                          try {
                            await FirebaseFirestore.instance
                                .collection('cantos_sugeridos')
                                .doc(docId)
                                .delete();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Registro retirado del historial de aprobados.'),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('No se pudo eliminar: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_forever_rounded, size: 19),
                        label: Text(
                          'Eliminar del historial',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ] else if (pubId != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          context.push('/hymn-view/$pubCol-$pubId');
                        },
                        icon: const Icon(Icons.menu_book_rounded, size: 19),
                        label: Text(
                          'Abrir Canto N° $pubId',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 11.5,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.nunito(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(
            'Gestión de Sugerencias',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          bottom: TabBar(
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('cantos_sugeridos')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pending_actions_rounded, size: 18),
                        const SizedBox(width: 6),
                        const Text('Pendientes'),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Aprobados'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            // Fondo degradado y auroras
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.14 : 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: dart_ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: const SizedBox(),
              ),
            ),
            TabBarView(
              children: [
                _buildPendingTab(isDark),
                _buildApprovedHistoryTab(isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cantos_sugeridos')
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 76, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No hay sugerencias pendientes',
                  style: GoogleFonts.nunito(fontSize: 18, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 32),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Sin título';
            final collection = data['collection'] ?? 'Desconocida';
            final requesterName = data['requesterName']?.toString().trim() ?? '';
            final requesterChurch = data['requesterChurch']?.toString().trim() ?? '';
            final type = data['type']?.toString() ?? 'new';
            final source = data['source']?.toString() ?? 'manual';
            final isCorrection = type == 'correction';
            final isMedley = type == 'medley';
            final targetTitle = data['targetTitle']?.toString();
            final targetHymnId = data['targetHymnId'];

            String typeLabel = source == 'scanner_ia' ? 'ESCÁNER IA' : 'CANTO NUEVO';
            Color typeColor = source == 'scanner_ia' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
            IconData leadingIcon = source == 'scanner_ia'
                ? Icons.document_scanner_rounded
                : Icons.add_circle_outline_rounded;

            if (isCorrection) {
              typeLabel = 'PROPUESTA DE MEJORA';
              typeColor = const Color(0xFF0EA5E9);
              leadingIcon = Icons.auto_fix_high_rounded;
            } else if (isMedley) {
              typeLabel = 'MEDLEY / POPURRÍ';
              typeColor = const Color(0xFF8B5CF6);
              leadingIcon = Icons.library_music_rounded;
            }

            String subtitle = 'Colección sugerida: ${_collectionLabel(collection.toString())}';
            if (isCorrection && targetTitle != null) {
              subtitle += '\nPara: $targetTitle (N° $targetHymnId)';
            }
            if (requesterName.isNotEmpty || requesterChurch.isNotEmpty) {
              subtitle += '\nEnviado por: ${requesterName.isNotEmpty ? requesterName : 'Anónimo'}'
                  '${requesterChurch.isNotEmpty ? ' ($requesterChurch)' : ''}';
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                leading: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(leadingIcon, color: typeColor, size: 22),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: typeColor.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Text(
                        typeLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      height: 1.35,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                isThreeLine: true,
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right_rounded, size: 20),
                ),
                onTap: () => _reviewSuggestion(context, ref, doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  /// Pestaña de Registro Histórico de Aportes Aprobados:
  /// Solo guarda/muestra cantos aprobados (los rechazados no ensucian este registro)
  /// permitiendo al administrador ver la Ficha de Trazabilidad y abrir el canto publicado.
  Widget _buildApprovedHistoryTab(bool isDark) {
    final allHymnsAsync = ref.watch(allHymnsGlobalProvider);
    final allHymns = allHymnsAsync.value ?? [];
    final catalogReady = allHymnsAsync.hasValue && !allHymnsAsync.isLoading;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('cantos_sugeridos')
          .where('status', isEqualTo: 'approved')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No se pudo cargar el historial de aprobados: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_outlined, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aún no hay aportes aprobados',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cada sugerencia que apruebes aparecerá aquí con el nombre del hermano/a, su iglesia y acceso directo al canto publicado.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final pubCol = (data['publishedCollection'] ?? data['collection'] ?? 'especiales').toString();
            final pubId = data['publishedId'] != null ? int.tryParse(data['publishedId'].toString()) : null;
            final publishedHymn = pubId != null
                ? allHymns
                    .where((h) => !h.isLocalOnly && h.collection == pubCol && h.id == pubId)
                    .firstOrNull
                : null;
            final isRemovedFromCatalog = catalogReady && pubId != null && publishedHymn == null;
            final liveStatus = _resolveLiveEditStatus(data: data, publishedHymn: publishedHymn);
            final publishedTitle = liveStatus.displayTitle;
            final requesterName = ((data['requesterName'] ?? data['suggestedByName']) as String?)?.trim() ?? '';
            final requesterChurch = ((data['requesterChurch'] ?? data['suggestedByChurch']) as String?)?.trim() ?? '';
            final type = data['type']?.toString() ?? 'new';
            final source = data['source']?.toString() ?? 'manual';
            final editedByAdmin = liveStatus.edited;
            final approvedDate = _formatTimestamp(data['approvedAt'] ?? data['timestamp']);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.65)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (isRemovedFromCatalog ? Colors.redAccent : const Color(0xFF10B981))
                      .withValues(alpha: isDark ? 0.3 : 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _showApprovedContributionSheet(
                  context,
                  docId: doc.id,
                  data: data,
                  publishedHymn: publishedHymn,
                  isRemovedFromCatalog: isRemovedFromCatalog,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isRemovedFromCatalog ? Colors.redAccent : const Color(0xFF10B981))
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isRemovedFromCatalog
                                  ? Icons.delete_outline_rounded
                                  : (editedByAdmin ? Icons.auto_awesome_rounded : Icons.check_circle_rounded),
                              color: isRemovedFromCatalog ? Colors.redAccent : const Color(0xFF10B981),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  publishedTitle,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.5,
                                    decoration: isRemovedFromCatalog ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (isRemovedFromCatalog)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'RETIRADO DEL CATÁLOGO',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          pubId != null
                                              ? '${_collectionLabel(pubCol)} · N° $pubId'
                                              : _collectionLabel(pubCol),
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                    if (editedByAdmin)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'PULIDO ADMIN',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF38BDF8),
                                          ),
                                        ),
                                      ),
                                    if (type == 'correction')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'CORRECCIÓN',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0EA5E9),
                                          ),
                                        ),
                                      ),
                                    if (source == 'scanner_ia')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'ESCÁNER IA',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF8B5CF6),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 15, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${requesterName.isNotEmpty ? requesterName : 'Sin nombre registrado'}'
                                '${requesterChurch.isNotEmpty ? ' · $requesterChurch' : ''}',
                                style: GoogleFonts.nunito(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                                ),
                              ),
                            ),
                            if (approvedDate.isNotEmpty)
                              Text(
                                approvedDate,
                                style: GoogleFonts.nunito(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _askRejectionReason(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    const presets = [
      'Ya existe en el catálogo oficial',
      'Letra incompleta o poco legible',
      'No corresponde al himnario',
    ];

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rechazar sugerencia',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'El usuario verá en "Mis Sugerencias Enviadas" que no fue publicada. Opcionalmente puedes indicar el motivo:',
                      style: GoogleFonts.nunito(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presets.map((p) {
                        final selected = reasonCtrl.text.trim() == p;
                        return ChoiceChip(
                          label: Text(p, style: GoogleFonts.nunito(fontSize: 12)),
                          selected: selected,
                          onSelected: (_) {
                            setDialogState(() {
                              reasonCtrl.text = selected ? '' : p;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonCtrl,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Motivo (opcional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, null),
                  child: const Text('Volver'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () => Navigator.pop(dialogCtx, reasonCtrl.text.trim()),
                  child: const Text('Confirmar Rechazo'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonCtrl.dispose();
    return result;
  }

  void _reviewSuggestion(BuildContext context, WidgetRef ref, String docId, Map<String, dynamic> data) {
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final lyricsCtrl = TextEditingController(text: data['lyrics'] ?? '');
    final keyCtrl = TextEditingController(text: data['key'] ?? '');
    final beatsCtrl = TextEditingController(text: data['beats'] ?? '');
    final timeSignatureCtrl = TextEditingController(text: data['timeSignature'] ?? '');
    String selectedCollection = data['collection'] ?? 'especiales';
    final isCorrection = data['type'] == 'correction' && data['targetHymnId'] != null;
    final isMedley = data['type'] == 'medley';
    final targetHymnId = data['targetHymnId'];
    final requesterName = ((data['requesterName'] ?? data['suggestedByName']) as String?)?.trim() ?? '';
    final requesterChurch = ((data['requesterChurch'] ?? data['suggestedByChurch']) as String?)?.trim() ?? '';
    final category = (data['category'] as String?)?.trim() ?? '';
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isCorrection
                        ? Icons.edit_note_rounded
                        : (isMedley ? Icons.queue_music_rounded : Icons.add_circle_outline_rounded),
                    color: isCorrection ? Colors.cyan : (isMedley ? Colors.purpleAccent : Colors.teal),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCorrection
                          ? 'Revisar Corrección'
                          : (isMedley ? 'Revisar Medley / Popurrí' : 'Revisar Sugerencia'),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (requesterName.isNotEmpty || requesterChurch.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_pin_rounded, size: 16, color: Colors.blueAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Sugerido por: ${requesterName.isNotEmpty ? requesterName : "Hermano/a"}${requesterChurch.isNotEmpty ? " ($requesterChurch)" : ""}',
                                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (isCorrection) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: Colors.cyan),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Propuesta de mejora para Canto N° $targetHymnId en ${selectedCollection.toUpperCase()}',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: ['iump', 'coros', 'especiales'].contains(selectedCollection)
                          ? selectedCollection
                          : 'especiales',
                      decoration: const InputDecoration(
                        labelText: 'Colección Destino',
                        border: OutlineInputBorder(),
                      ),
                      items: ['iump', 'coros', 'especiales']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase())))
                          .toList(),
                      onChanged: (v) => setState(() => selectedCollection = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tono (Ej: Do Mayor)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: beatsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tiempo (BPM)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: timeSignatureCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Métrica',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Letra', style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                          tooltip: 'Mejorar Ortografía y Puntuación con IA',
                          onPressed: () async {
                            if (lyricsCtrl.text.trim().isEmpty) return;
                            final result = await GeminiAiService.correctHymnGrammar(
                              context: context,
                              title: titleCtrl.text.trim(),
                              lyrics: lyricsCtrl.text.trim(),
                            );
                            if (result != null) {
                              titleCtrl.text = result['title']!;
                              lyricsCtrl.text = result['lyrics']!;
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    HymnStructureToolbar(controller: lyricsCtrl),
                    const SizedBox(height: 8),
                    TextField(
                      controller: lyricsCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: isProcessing
                  ? [const CircularProgressIndicator()]
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final rejectionReason = await _askRejectionReason(context);
                          if (rejectionReason == null || !context.mounted) return;

                          setState(() => isProcessing = true);
                          try {
                            final rejectPayload = <String, dynamic>{
                              'status': 'rejected',
                              'reviewedAt': FieldValue.serverTimestamp(),
                            };
                            if (rejectionReason.isNotEmpty) {
                              rejectPayload['rejectionReason'] = rejectionReason;
                            }
                            await FirebaseFirestore.instance
                                .collection('cantos_sugeridos')
                                .doc(docId)
                                .update(rejectPayload);

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sugerencia rechazada. El usuario verá el estado actualizado.'),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isProcessing = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al rechazar: $e')),
                              );
                            }
                          }
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Rechazar'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final finalTitle = titleCtrl.text.trim();
                          final finalLyrics = lyricsCtrl.text.trim();
                          final finalTone = keyCtrl.text.trim();
                          if (finalTitle.isEmpty || finalLyrics.isEmpty) return;

                          final editInfo = _detectAdminEdits(
                            originalData: data,
                            finalTitle: finalTitle,
                            finalLyrics: finalLyrics,
                            finalCollection: selectedCollection,
                            finalKey: finalTone,
                          );

                          setState(() => isProcessing = true);
                          try {
                            if (isCorrection) {
                              // Actualizar canto existente en la colección
                              final updateData = <String, dynamic>{
                                'title': finalTitle,
                                'lyrics': finalLyrics,
                              };
                              if (finalTone.isNotEmpty) updateData['toneNote'] = finalTone;
                              final beats = beatsCtrl.text.trim();
                              if (beats.isNotEmpty) updateData['beats'] = beats;
                              final timeSig = timeSignatureCtrl.text.trim();
                              if (timeSig.isNotEmpty) updateData['timeSignature'] = timeSig;
                              if (requesterName.isNotEmpty) updateData['lastImprovedByName'] = requesterName;
                              if (requesterChurch.isNotEmpty) updateData['lastImprovedByChurch'] = requesterChurch;

                              await FirebaseFirestore.instance
                                  .collection(selectedCollection)
                                  .doc(targetHymnId.toString())
                                  .set(updateData, SetOptions(merge: true));

                              ref.invalidate(hymnsProvider(selectedCollection));

                              final approvalUpdate = <String, dynamic>{
                                'status': 'approved',
                                'approvedAt': FieldValue.serverTimestamp(),
                                'publishedId': targetHymnId is int ? targetHymnId : int.tryParse(targetHymnId.toString()),
                                'publishedCollection': selectedCollection,
                                'publishedTitle': finalTitle,
                                'editedByAdmin': editInfo.edited,
                              };
                              if (editInfo.summary != null) {
                                approvalUpdate['adminEditSummary'] = editInfo.summary;
                              }

                              await FirebaseFirestore.instance
                                  .collection('cantos_sugeridos')
                                  .doc(docId)
                                  .update(approvalUpdate);

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('¡Canto N° $targetHymnId actualizado y publicado con éxito!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              // 1. Encontrar el siguiente ID disponible en la colección seleccionada
                              final snapshot = await FirebaseFirestore.instance
                                  .collection(selectedCollection)
                                  .orderBy('id', descending: true)
                                  .limit(1)
                                  .get();

                              int nextId = 1;
                              if (snapshot.docs.isNotEmpty) {
                                final docData = snapshot.docs.first.data();
                                if (docData['id'] != null) {
                                  nextId = (docData['id'] as int) + 1;
                                }
                              }

                              // 2. Crear el nuevo objeto de canto con trazabilidad de aporte
                              final newHymn = <String, dynamic>{
                                'id': nextId,
                                'title': finalTitle,
                                'lyrics': finalLyrics,
                                'collection': selectedCollection,
                              };

                              if (finalTone.isNotEmpty) newHymn['toneNote'] = finalTone;
                              final beats = beatsCtrl.text.trim();
                              if (beats.isNotEmpty) newHymn['beats'] = beats;
                              final timeSig = timeSignatureCtrl.text.trim();
                              if (timeSig.isNotEmpty) newHymn['timeSignature'] = timeSig;
                              if (category.isNotEmpty) newHymn['category'] = category;
                              if (requesterName.isNotEmpty) newHymn['suggestedByName'] = requesterName;
                              if (requesterChurch.isNotEmpty) newHymn['suggestedByChurch'] = requesterChurch;
                              newHymn['approvedAt'] = FieldValue.serverTimestamp();

                              // 3. Guardar en la colección oficial de Firestore
                              await FirebaseFirestore.instance
                                  .collection(selectedCollection)
                                  .doc(nextId.toString())
                                  .set(newHymn);

                              // Refrescar el provider de la colección para mostrar el nuevo canto
                              ref.invalidate(hymnsProvider(selectedCollection));

                              // 4. Marcar sugerencia como aprobada (queda en pestaña Aprobados y actualiza al usuario)
                              final approvalUpdate = <String, dynamic>{
                                'status': 'approved',
                                'approvedAt': FieldValue.serverTimestamp(),
                                'publishedId': nextId,
                                'publishedCollection': selectedCollection,
                                'publishedTitle': finalTitle,
                                'editedByAdmin': editInfo.edited,
                              };
                              if (editInfo.summary != null) {
                                approvalUpdate['adminEditSummary'] = editInfo.summary;
                              }

                              await FirebaseFirestore.instance
                                  .collection('cantos_sugeridos')
                                  .doc(docId)
                                  .update(approvalUpdate);

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('¡Canto N° $nextId aprobado y publicado con éxito!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setState(() => isProcessing = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        child: Text(isCorrection ? 'Aprobar y Actualizar' : 'Aprobar y Guardar'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
}
