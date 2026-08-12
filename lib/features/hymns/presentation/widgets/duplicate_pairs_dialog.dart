import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/hymn.dart';
import '../hymn_list_screen.dart';

class DuplicatePair {
  final Hymn hymnA;
  final Hymn hymnB;
  final double similarityScore;

  String get pairKey {
    final keyA = '${hymnA.collection}-${hymnA.id}';
    final keyB = '${hymnB.collection}-${hymnB.id}';
    return keyA.compareTo(keyB) < 0 ? '$keyA::$keyB' : '$keyB::$keyA';
  }

  const DuplicatePair({
    required this.hymnA,
    required this.hymnB,
    required this.similarityScore,
  });
}

class DuplicatePairsDialog extends ConsumerStatefulWidget {
  final List<DuplicatePair> duplicatePairs;

  const DuplicatePairsDialog({super.key, required this.duplicatePairs});

  static void show(BuildContext context, List<DuplicatePair> pairs) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DuplicatePairsDialog(duplicatePairs: pairs),
    );
  }

  @override
  ConsumerState<DuplicatePairsDialog> createState() => _DuplicatePairsDialogState();
}

class _DuplicatePairsDialogState extends ConsumerState<DuplicatePairsDialog> {
  int _currentIndex = 0;
  bool _isProcessing = false;

  Future<void> _ignoreCurrentPair(DuplicatePair pair) async {
    setState(() => _isProcessing = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('app_config').doc('ignored_duplicates');
      await docRef.set({
        'ignoredPairs': FieldValue.arrayUnion([pair.pairKey]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Par marcado como "Conservar Ambos". No volverá a sugerirse.', style: GoogleFonts.nunito()),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('>>> Error al ignorar par duplicado: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (_currentIndex < widget.duplicatePairs.length - 1) {
            _currentIndex++;
          } else {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  Future<void> _deleteHymn(Hymn hymn, DuplicatePair pair) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar Canto?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente "${hymn.title}" (${hymn.collectionName})?',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection(hymn.collection).doc(hymn.id.toString()).delete();

      // También registrar en ignorados para evitar rezagados en caché local
      final docRef = firestore.collection('app_config').doc('ignored_duplicates');
      await docRef.set({
        'ignoredPairs': FieldValue.arrayUnion([pair.pairKey]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Canto "${hymn.title}" eliminado correctamente.', style: GoogleFonts.nunito()),
            backgroundColor: Colors.amber.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('>>> Error al eliminar canto duplicado: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (_currentIndex < widget.duplicatePairs.length - 1) {
            _currentIndex++;
          } else {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.duplicatePairs.isEmpty || _currentIndex >= widget.duplicatePairs.length) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Text('No quedan pares duplicados pendientes de revisión.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    final pair = widget.duplicatePairs[_currentIndex];
    final totalPairs = widget.duplicatePairs.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Encabezado con contador de revisión (1 contra 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.compare_arrows_rounded, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revisión Lado a Lado (1 contra 1)',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Par ${_currentIndex + 1} de $totalPairs • Coincidencia ${(pair.similarityScore * 100).toInt()}%',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
            const SizedBox(height: 14),

            // Comparación en 2 Columnas (Canto A vs Canto B)
            Expanded(
              child: _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Columna Canto A
                        Expanded(
                          child: _buildHymnColumn(context, pair.hymnA, 'Canto A', pair, isA: true),
                        ),
                        const SizedBox(width: 12),
                        VerticalDivider(color: isDark ? Colors.white12 : Colors.black12, width: 1),
                        const SizedBox(width: 12),
                        // Columna Canto B
                        Expanded(
                          child: _buildHymnColumn(context, pair.hymnB, 'Canto B', pair, isA: false),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
            const SizedBox(height: 14),

            // Botones de Acción Administrador
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _currentIndex < totalPairs - 1
                      ? () => setState(() => _currentIndex++)
                      : null,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: Text('Saltar este Par', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : () => _ignoreCurrentPair(pair),
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.black),
                  label: Text(
                    '🟢 Conservar Ambos (No es duplicado)',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent[400],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHymnColumn(BuildContext context, Hymn hymn, String label, DuplicatePair pair, {required bool isA}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insignia Canto A / B + Categoría
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hymn.collectionName,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Título del Canto
          Text(
            '#${hymn.id} - ${hymn.title}',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Tono
          if (hymn.toneNote.isNotEmpty)
            Text(
              'Tono: ${hymn.toneNote}',
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white60),
            ),
          const SizedBox(height: 10),

          // Previsualización de Letra
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF020617) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  hymn.lyrics,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Botón Eliminar esta Copia
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _deleteHymn(hymn, pair),
              icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.white),
              label: Text(
                'Eliminar ${isA ? "Canto A" : "Canto B"}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent[400],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
