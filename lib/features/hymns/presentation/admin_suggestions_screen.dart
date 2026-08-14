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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugerencias Pendientes'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
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

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.assignment_rounded, color: Colors.white),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(subtitle),
                  isThreeLine: requesterName.isNotEmpty || requesterChurch.isNotEmpty,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _reviewSuggestion(context, doc.id, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _reviewSuggestion(BuildContext context, String docId, Map<String, dynamic> data) {
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final lyricsCtrl = TextEditingController(text: data['lyrics'] ?? '');
    final keyCtrl = TextEditingController(text: data['key'] ?? '');
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
                      value: ['iump', 'coros', 'especiales'].contains(selectedCollection) 
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
                    TextField(
                      controller: lyricsCtrl,
                      maxLines: 8,
                      decoration: const InputDecoration(labelText: 'Letra', border: OutlineInputBorder()),
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
                          // 1. Encontrar el siguiente ID disponible
                          final snapshot = await FirebaseFirestore.instance.collection('hymns').doc(selectedCollection).get();
                          final hymnsList = snapshot.data()?['hymns'] as List<dynamic>? ?? [];
                          
                          int nextId = 1;
                          if (hymnsList.isNotEmpty) {
                            for (var h in hymnsList) {
                              if (h is Map && h['id'] != null) {
                                int id = (h['id'] is int) ? h['id'] : int.tryParse(h['id'].toString()) ?? 0;
                                if (id >= nextId) nextId = id + 1;
                              }
                            }
                          }

                          // 2. Crear el nuevo objeto de canto
                          final newHymn = {
                            'id': nextId,
                            'title': titleCtrl.text.trim(),
                            'lyrics': lyricsCtrl.text.trim(),
                          };
                          
                          final tone = keyCtrl.text.trim();
                          if (tone.isNotEmpty) {
                            newHymn['toneNote'] = tone;
                          }

                          // 3. Guardar en la colección oficial
                          hymnsList.add(newHymn);
                          await FirebaseFirestore.instance.collection('hymns').doc(selectedCollection).set({
                            'hymns': hymnsList,
                          }, SetOptions(merge: true));

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
