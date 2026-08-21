import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/hymn.dart';

class SheetMusicViewer extends ConsumerStatefulWidget {
  final Hymn hymn;
  final bool isEmbedded;
  const SheetMusicViewer({super.key, required this.hymn, this.isEmbedded = false});

  @override
  ConsumerState<SheetMusicViewer> createState() => _SheetMusicViewerState();
}

class _SheetMusicViewerState extends ConsumerState<SheetMusicViewer> {
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  Future<void> _pickAndUpload(bool isPdf) async {
    List<File> filesToUpload = [];

    if (isPdf) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      if (result != null) {
        filesToUpload = result.paths.where((p) => p != null).map((p) => File(p!)).toList();
      }
    } else {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        filesToUpload = images.map((x) => File(x.path)).toList();
      }
    }

    if (filesToUpload.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final storage = FirebaseStorage.instance;
      List<String> newUrls = [];
      
      for (int i = 0; i < filesToUpload.length; i++) {
        final file = filesToUpload[i];
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final ref = storage.ref().child('sheet_music/${widget.hymn.collection}/${widget.hymn.id}/$fileName');
        
        final uploadTask = ref.putFile(file);
        
        uploadTask.snapshotEvents.listen((event) {
          setState(() {
            _uploadProgress = ((i + (event.bytesTransferred / event.totalBytes)) / filesToUpload.length);
          });
        });

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        newUrls.add(downloadUrl);
      }

      // Añadir al canto actual
      final updatedUrls = List<String>.from(widget.hymn.sheetMusicUrls)..addAll(newUrls);
      
      // Actualizar en el estado (Riverpod)
      await ref.read(hymnsProvider(widget.hymn.collection).notifier).saveHymn(
        id: widget.hymn.id,
        title: widget.hymn.title,
        toneNote: widget.hymn.toneNote,
        beats: widget.hymn.beats,
        timeSignature: widget.hymn.timeSignature,
        lyrics: widget.hymn.lyrics,
        isNew: false,
        audioUrl: widget.hymn.audioUrl,
        category: widget.hymn.category,
        sheetMusicUrls: updatedUrls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partitura(s) subida(s) con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteAttachment(String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar partitura'),
        content: const Text('¿Estás seguro de eliminar este archivo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploading = true);
    try {
      // Eliminar de Storage
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (e) {
        debugPrint('Error deleting from storage: $e');
      }

      final updatedUrls = List<String>.from(widget.hymn.sheetMusicUrls)..remove(url);
      
      await ref.read(hymnsProvider(widget.hymn.collection).notifier).saveHymn(
        id: widget.hymn.id,
        title: widget.hymn.title,
        toneNote: widget.hymn.toneNote,
        beats: widget.hymn.beats,
        timeSignature: widget.hymn.timeSignature,
        lyrics: widget.hymn.lyrics,
        isNew: false,
        audioUrl: widget.hymn.audioUrl,
        category: widget.hymn.category,
        sheetMusicUrls: updatedUrls,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.hymn.sheetMusicUrls;
    final theme = Theme.of(context);
    final isAdmin = ref.watch(adminModeProvider);

    Widget body = _isUploading
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Subiendo... ${(_uploadProgress * 100).toStringAsFixed(1)}%'),
              ],
            ),
          )
        : urls.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_music_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      isAdmin ? 'No hay partituras adjuntas' : 'Aún no hay partitura oficial para este himno', 
                      style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      _buildUploadButtons(),
                    ],
                  ],
                ),
              )
            : Column(
                children: [
                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildUploadButtons(),
                    ),
                  Expanded(
                    child: PageView.builder(
                      itemCount: urls.length,
                      itemBuilder: (context, index) {
                        final url = urls[index];
                        final isPdf = url.toLowerCase().contains('.pdf');

                        return Stack(
                          children: [
                            Center(
                              child: isPdf
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.picture_as_pdf, size: 80, color: Colors.redAccent),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () => launchUrl(Uri.parse(url)),
                                          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                                          label: Text('Abrir Partitura Oficial', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            elevation: 4,
                                          ),
                                        ),
                                      ],
                                    )
                                  : InteractiveViewer(
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      child: Image.network(url,
                                        
                                        fit: BoxFit.contain,
                                        
                                        
                                      ),
                                    ),
                            ),
                            if (isAdmin)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  style: IconButton.styleFrom(backgroundColor: Colors.white70),
                                  onPressed: () => _deleteAttachment(url),
                                ),
                              ),
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${index + 1} / ${urls.length}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Partituras: ${widget.hymn.title}', style: GoogleFonts.outfit(fontSize: 18)),
      ),
      body: body,
    );
  }

  Widget _buildUploadButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () => _pickAndUpload(false),
          icon: const Icon(Icons.image),
          label: const Text('Fotos'),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => _pickAndUpload(true),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('PDF'),
        ),
      ],
    );
  }
}
