import 'package:himnario_iump/core/services/local_hymn_storage_service.dart';
import 'package:himnario_iump/core/services/gemini_ai_service.dart';
import 'dart:ui' as dart_ui;
import 'package:himnario_iump/features/hymns/domain/hymn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminSuggestionsScreen extends ConsumerStatefulWidget {
  const AdminSuggestionsScreen({super.key});

  @override
  ConsumerState<AdminSuggestionsScreen> createState() => _AdminSuggestionsScreenState();
}

class _AdminSuggestionsScreenState extends ConsumerState<AdminSuggestionsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Sugerencias Pendientes',
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
                  ? Colors.black.withValues(alpha: 0.3) 
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
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
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.1),
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
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
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
                  Icon(Icons.inbox_rounded, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No hay sugerencias pendientes', 
                    style: GoogleFonts.nunito(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Sin título';
              final collection = data['collection'] ?? 'Desconocida';
              final requesterName = data['requesterName']?.toString().trim() ?? '';
              final requesterChurch = data['requesterChurch']?.toString().trim() ?? '';
              
              String subtitle = 'Colección sugerida: ${collection.toUpperCase()}';
              if (requesterName.isNotEmpty || requesterChurch.isNotEmpty) {
                subtitle += '\nEnviado por: ${requesterName.isNotEmpty ? requesterName : 'Anónimo'}'
                            '${requesterChurch.isNotEmpty ? ' ($requesterChurch)' : ''}';
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.1) 
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.assignment_rounded, color: Color(0xFFF59E0B)),
                      ),
                      title: Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(subtitle, style: GoogleFonts.nunito(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                      ),
                      isThreeLine: requesterName.isNotEmpty || requesterChurch.isNotEmpty,
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_right_rounded, size: 20),
                      ),
                      onTap: () => _reviewSuggestion(context, ref, doc.id, data),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  void _reviewSuggestion(BuildContext context, WidgetRef ref, String docId, Map<String, dynamic> data) {
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final lyricsCtrl = TextEditingController(text: data['lyrics'] ?? '');
    final keyCtrl = TextEditingController(text: data['key'] ?? '');
    final beatsCtrl = TextEditingController(text: data['beats'] ?? '');
    final timeSignatureCtrl = TextEditingController(text: data['timeSignature'] ?? '');
    String selectedCollection = data['collection'] ?? 'especiales';
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Revisar Sugerencia'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: ['iump', 'coros', 'especiales'].contains(selectedCollection) 
                          ? selectedCollection 
                          : 'especiales',
                      decoration: const InputDecoration(labelText: 'Colección Destino', border: OutlineInputBorder()),
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
                      decoration: const InputDecoration(labelText: 'Tono (Ej: Do Mayor)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: beatsCtrl, decoration: const InputDecoration(labelText: 'Tiempo (BPM)', border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: timeSignatureCtrl, decoration: const InputDecoration(labelText: 'Métrica', border: OutlineInputBorder()))),
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
                        setState(() => isProcessing = true);
                        try {
                          await FirebaseFirestore.instance.collection('cantos_sugeridos').doc(docId).update({
                            'status': 'rejected',
                          });
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          setState(() => isProcessing = false);
                        }
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Rechazar'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        setState(() => isProcessing = true);
                        try {
                          // 1. Encontrar el siguiente ID disponible en la colección seleccionada
                          final snapshot = await FirebaseFirestore.instance
                              .collection(selectedCollection)
                              .orderBy('id', descending: true)
                              .limit(1)
                              .get();
                          
                          int nextId = 1;
                          if (snapshot.docs.isNotEmpty) {
                            final data = snapshot.docs.first.data();
                            if (data['id'] != null) {
                              nextId = (data['id'] as int) + 1;
                            }
                          }

                          // 2. Crear el nuevo objeto de canto
                          final newHymn = {
                            'id': nextId,
                            'title': titleCtrl.text.trim(),
                            'lyrics': lyricsCtrl.text.trim(),
                            'collection': selectedCollection,
                          };
                          
                          final tone = keyCtrl.text.trim();
                          if (tone.isNotEmpty) {
                            newHymn['toneNote'] = tone;
                          }
                          final beats = beatsCtrl.text.trim();
                          if (beats.isNotEmpty) newHymn['beats'] = beats;
                          final timeSig = timeSignatureCtrl.text.trim();
                          if (timeSig.isNotEmpty) newHymn['timeSignature'] = timeSig;

                          // 3. Guardar en la colección oficial de Firestore
                          await FirebaseFirestore.instance
                              .collection(selectedCollection)
                              .doc(nextId.toString())
                              .set(newHymn);
                          
                          // Refrescar el provider de la colección para mostrar el nuevo canto
                          ref.invalidate(hymnsProvider(selectedCollection));
                          

                          // 4. Marcar sugerencia como aprobada
                          await FirebaseFirestore.instance.collection('cantos_sugeridos').doc(docId).update({
                            'status': 'approved',
                            'approvedAt': FieldValue.serverTimestamp(),
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Canto aprobado y publicado con éxito!'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setState(() => isProcessing = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      child: const Text('Aprobar y Guardar'),
                    ),
                  ],
            );
          },
        );
      },
    );
  }
}
