import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/hymn.dart';

/// Modelo de datos que representa una partitura asociada a un instrumento específico.
class SheetMusicItem {
  final String url;
  final int index;
  final String rawFileName;
  final String instrument;
  final IconData icon;

  const SheetMusicItem({
    required this.url,
    required this.index,
    required this.rawFileName,
    required this.instrument,
    required this.icon,
  });

  /// Analiza la URL y el nombre del archivo para deducir el instrumento musical y su icono.
  static SheetMusicItem parse(String url, int index) {
    String rawFileName = 'Partitura';
    try {
      final uri = Uri.parse(url);
      final decodedPath = Uri.decodeComponent(uri.path);
      var fn = decodedPath.split('/').last;
      final underscoreIdx = fn.indexOf('_');
      if (underscoreIdx != -1 && underscoreIdx < fn.length - 1) {
        fn = fn.substring(underscoreIdx + 1);
      }
      rawFileName = fn.trim();
    } catch (_) {}

    final nameNoExt = rawFileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();
    final lower = nameNoExt.toLowerCase();

    String instrument = '';
    IconData icon = Icons.music_note_rounded;

    if (lower.contains('violin 1') || lower.contains('violín 1') || lower.contains('1er violin') || lower.contains('violin i') || lower.contains('violín i')) {
      instrument = 'Violín 1';
      icon = Icons.music_note_rounded;
    } else if (lower.contains('violin 2') || lower.contains('violín 2') || lower.contains('2do violin') || lower.contains('violin ii') || lower.contains('violín ii')) {
      instrument = 'Violín 2';
      icon = Icons.music_note_rounded;
    } else if (lower.contains('violin 3') || lower.contains('violín 3') || lower.contains('3er violin') || lower.contains('violin iii') || lower.contains('violín iii')) {
      instrument = 'Violín 3';
      icon = Icons.music_note_rounded;
    } else if (lower.contains('violin') || lower.contains('violín')) {
      instrument = 'Violín';
      icon = Icons.music_note_rounded;
    } else if (lower.contains('mandolin 1') || lower.contains('mandolina 1') || lower.contains('mandolina i') || lower.contains('mandolin i')) {
      instrument = 'Mandolina 1';
      icon = Icons.queue_music_rounded;
    } else if (lower.contains('mandolin 2') || lower.contains('mandolina 2') || lower.contains('mandolina ii') || lower.contains('mandolin ii')) {
      instrument = 'Mandolina 2';
      icon = Icons.queue_music_rounded;
    } else if (lower.contains('mandolin 3') || lower.contains('mandolina 3') || lower.contains('mandolina iii') || lower.contains('mandolin iii')) {
      instrument = 'Mandolina 3';
      icon = Icons.queue_music_rounded;
    } else if (lower.contains('mandolin') || lower.contains('mandolina') || lower.contains('bandurria')) {
      instrument = 'Mandolina';
      icon = Icons.queue_music_rounded;
    } else if (lower.contains('piano') || lower.contains('teclado') || lower.contains('keyboard')) {
      instrument = 'Piano';
      icon = Icons.piano_rounded;
    } else if (lower.contains('guitar') || lower.contains('guitarra') || lower.contains('acustica') || lower.contains('acústica')) {
      instrument = 'Guitarra';
      icon = Icons.music_note_rounded;
    } else if (lower.contains('bass') || lower.contains('bajo')) {
      instrument = 'Bajo';
      icon = Icons.music_note_rounded;
    } else if (lower.contains('cello') || lower.contains('violonchelo') || lower.contains('chelo')) {
      instrument = 'Violonchelo';
      icon = Icons.music_note_rounded;
    } else if (lower.contains('viola')) {
      instrument = 'Viola';
      icon = Icons.music_note_rounded;
    } else if (lower.contains('contrabajo') || lower.contains('double bass')) {
      instrument = 'Contrabajo';
      icon = Icons.music_note_rounded;
    } else if (lower.contains('flauta') || lower.contains('flute')) {
      instrument = 'Flauta';
      icon = Icons.air_rounded;
    } else if (lower.contains('clarinete') || lower.contains('clarinet')) {
      instrument = 'Clarinete';
      icon = Icons.air_rounded;
    } else if (lower.contains('trompeta') || lower.contains('trumpet')) {
      instrument = 'Trompeta';
      icon = Icons.air_rounded;
    } else if (lower.contains('trombon') || lower.contains('trombón') || lower.contains('trombone')) {
      instrument = 'Trombón';
      icon = Icons.air_rounded;
    } else if (lower.contains('sax') || lower.contains('saxofon') || lower.contains('saxofón')) {
      instrument = 'Saxofón';
      icon = Icons.air_rounded;
    } else if (lower.contains('corno') || lower.contains('french horn')) {
      instrument = 'Corno';
      icon = Icons.air_rounded;
    } else if (lower.contains('bateria') || lower.contains('batería') || lower.contains('drums')) {
      instrument = 'Batería';
      icon = Icons.album_rounded;
    } else if (lower.contains('percusion') || lower.contains('percusión')) {
      instrument = 'Percusión';
      icon = Icons.album_rounded;
    } else if (lower.contains('coro') || lower.contains('voces') || lower.contains('vocal') || lower.contains('soprano') || lower.contains('tenor')) {
      instrument = 'Coro / Voces';
      icon = Icons.record_voice_over_rounded;
    } else if (lower.contains('director') || lower.contains('general') || lower.contains('completa') || lower.contains('score') || lower.contains('guia') || lower.contains('guía')) {
      instrument = 'Partitura General';
      icon = Icons.library_music_rounded;
    } else {
      final parts = nameNoExt.split('-').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.length > 1 && parts.last.length <= 30) {
        instrument = parts.last;
      } else {
        instrument = 'Documento ${index + 1}';
      }
    }

    return SheetMusicItem(
      url: url,
      index: index,
      rawFileName: rawFileName,
      instrument: instrument,
      icon: icon,
    );
  }

  /// Procesa todas las URLs desambiguando nombres repetidos (ej: Violín 2 #1 y Violín 2 #2).
  static List<SheetMusicItem> parseAll(List<String> urls) {
    final list = <SheetMusicItem>[];
    final counts = <String, int>{};
    for (int i = 0; i < urls.length; i++) {
      final item = parse(urls[i], i);
      counts[item.instrument] = (counts[item.instrument] ?? 0) + 1;
      list.add(item);
    }

    final seen = <String, int>{};
    final result = <SheetMusicItem>[];
    for (final item in list) {
      if ((counts[item.instrument] ?? 0) > 1) {
        final currentCount = (seen[item.instrument] ?? 0) + 1;
        seen[item.instrument] = currentCount;
        result.add(SheetMusicItem(
          url: item.url,
          index: item.index,
          rawFileName: item.rawFileName,
          instrument: '${item.instrument} (#$currentCount)',
          icon: item.icon,
        ));
      } else {
        result.add(item);
      }
    }
    return result;
  }
}

class SheetMusicViewer extends ConsumerStatefulWidget {
  final Hymn hymn;
  final bool isEmbedded;
  const SheetMusicViewer({super.key, required this.hymn, this.isEmbedded = false});

  @override
  ConsumerState<SheetMusicViewer> createState() => _SheetMusicViewerState();
}

class _UploadItem {
  final String name;
  final Uint8List bytes;
  final bool isPdf;
  _UploadItem({required this.name, required this.bytes, required this.isPdf});
}

class _SheetMusicViewerState extends ConsumerState<SheetMusicViewer> {
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  int _selectedDocIndex = 0;
  List<String>? _localUrls;

  bool _isPrintingAction = false;
  bool _isSharingAction = false;

  @override
  void initState() {
    super.initState();
    _localUrls = List<String>.from(widget.hymn.sheetMusicUrls);
  }

  @override
  void didUpdateWidget(covariant SheetMusicViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.hymn.sheetMusicUrls, widget.hymn.sheetMusicUrls)) {
      setState(() {
        _localUrls = List<String>.from(widget.hymn.sheetMusicUrls);
        if (_selectedDocIndex >= (_localUrls?.length ?? 0)) {
          _selectedDocIndex = (_localUrls?.isEmpty ?? true) ? 0 : _localUrls!.length - 1;
        }
      });
    }
  }

  List<String> get _currentUrls {
    if (_localUrls != null) return _localUrls!;
    final hymnsAsync = ref.watch(hymnsProvider(widget.hymn.collection));
    return hymnsAsync.maybeWhen(
      data: (list) {
        final found = list.firstWhere((h) => h.id == widget.hymn.id, orElse: () => widget.hymn);
        return found.sheetMusicUrls;
      },
      orElse: () => widget.hymn.sheetMusicUrls,
    );
  }

  String _buildFormattedDocName(String hymnTitle, String instrument) {
    final cleanTitle = hymnTitle.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    final cleanInst = instrument.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    return '$cleanTitle - $cleanInst';
  }

  // ── Subida Universal (Web, Mac, Android, iOS) ──────────────────────────
  Future<void> _pickAndUpload(bool isPdf) async {
    final List<_UploadItem> itemsToUpload = [];

    try {
      if (isPdf) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: true,
          withData: true, // Crucial para Web: carga los bytes en memoria
        );

        if (result != null && result.files.isNotEmpty) {
          for (final f in result.files) {
            Uint8List? data = f.bytes;
            if (data == null && f.path != null && !kIsWeb) {
              data = await io.File(f.path!).readAsBytes();
            }
            if (data != null && data.isNotEmpty) {
              itemsToUpload.add(_UploadItem(name: f.name, bytes: data, isPdf: true));
            }
          }
        }
      } else {
        final ImagePicker picker = ImagePicker();
        final List<XFile> images = await picker.pickMultiImage();
        for (final img in images) {
          final data = await img.readAsBytes();
          if (data.isNotEmpty) {
            itemsToUpload.add(_UploadItem(name: img.name, bytes: data, isPdf: false));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar archivos: $e')),
        );
      }
      return;
    }

    if (itemsToUpload.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final storage = FirebaseStorage.instance;
      final List<String> newUrls = [];

      for (int i = 0; i < itemsToUpload.length; i++) {
        final item = itemsToUpload[i];
        final safeName = item.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
        final refStorage = storage.ref().child('sheet_music/${widget.hymn.collection}/${widget.hymn.id}/$fileName');

        final metadata = SettableMetadata(
          contentType: item.isPdf ? 'application/pdf' : 'image/jpeg',
        );

        final uploadTask = refStorage.putData(item.bytes, metadata);

        uploadTask.snapshotEvents.listen((event) {
          if (mounted && event.totalBytes > 0) {
            setState(() {
              _uploadProgress = ((i + (event.bytesTransferred / event.totalBytes)) / itemsToUpload.length);
            });
          }
        });

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        newUrls.add(downloadUrl);
      }

      final updatedUrls = List<String>.from(_currentUrls)..addAll(newUrls);

      setState(() {
        _localUrls = updatedUrls;
        _selectedDocIndex = updatedUrls.length - newUrls.length; // Posicionar en el primer archivo subido
      });

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
          SnackBar(content: Text('Se subieron ${newUrls.length} partitura(s) exitosamente')),
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
        setState(() => _isUploading = false);
      }
    }
  }

  // ── Eliminar Partitura ────────────────────────────────────────────────
  Future<void> _deleteAttachment(String url, String instrument) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar partitura'),
        content: Text('¿Estás seguro de eliminar la partitura de «$instrument»?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploading = true);
    try {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (e) {
        debugPrint('Error deleting from storage: $e');
      }

      final updatedUrls = List<String>.from(_currentUrls)..remove(url);

      setState(() {
        _localUrls = updatedUrls;
        if (_selectedDocIndex >= updatedUrls.length) {
          _selectedDocIndex = updatedUrls.isEmpty ? 0 : updatedUrls.length - 1;
        }
      });

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
          SnackBar(content: Text('Partitura de «$instrument» eliminada')),
        );
      }
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

  // ── Impresión Inteligente (Individual o Por Selección) ────────────────
  Future<void> _printDocument(SheetMusicItem item) async {
    if (_isPrintingAction) return;
    setState(() => _isPrintingAction = true);

    final docTitle = _buildFormattedDocName(widget.hymn.title, item.instrument);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Abriendo impresión de «${item.instrument}»...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final response = await http.get(Uri.parse(item.url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        await Printing.layoutPdf(
          onLayout: (format) async => response.bodyBytes,
          name: docTitle,
          format: PdfPageFormat.letter,
          dynamicLayout: false,
        );
      } else {
        await launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error abriendo impresión: $e');
      await launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) setState(() => _isPrintingAction = false);
    }
  }

  Future<void> _printMultipleDocuments(List<SheetMusicItem> itemsToPrint) async {
    if (itemsToPrint.isEmpty || _isPrintingAction) return;
    setState(() => _isPrintingAction = true);

    try {
      for (int i = 0; i < itemsToPrint.length; i++) {
        final item = itemsToPrint[i];
        final docTitle = _buildFormattedDocName(widget.hymn.title, item.instrument);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  const SizedBox(width: 12),
                  Text('Preparando impresión de «${item.instrument}» (${i + 1}/${itemsToPrint.length})...'),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        final response = await http.get(Uri.parse(item.url)).timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) {
          await Printing.layoutPdf(
            onLayout: (format) async => response.bodyBytes,
            name: docTitle,
            format: PdfPageFormat.letter,
            dynamicLayout: false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error imprimiendo documentos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al imprimir: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPrintingAction = false);
    }
  }

  void _showPrintDialog(List<SheetMusicItem> items, int currentIdx) {
    if (items.isEmpty) return;
    if (items.length == 1) {
      _printDocument(items.first);
      return;
    }

    final currentItem = items[currentIdx.clamp(0, items.length - 1)];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final theme = Theme.of(ctx);
        final selectedIndexes = <int>{currentIdx};

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final allSelected = selectedIndexes.length == items.length;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(modalCtx).padding.bottom),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.print_rounded, color: Colors.redAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Imprimir Partituras',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '«${widget.hymn.title}» • ${items.length} instrumentos disponibles',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Opción 1: Imprimir solo el instrumento actual
                  InkWell(
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      _printDocument(currentItem);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(currentItem.icon, color: theme.colorScheme.primary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Imprimir solo ${currentItem.instrument}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  'Nombre de trabajo: «${_buildFormattedDocName(widget.hymn.title, currentItem.instrument)}»',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'O escoge cuáles instrumentos imprimir:',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            if (allSelected) {
                              selectedIndexes.clear();
                              selectedIndexes.add(currentIdx);
                            } else {
                              selectedIndexes.addAll(List.generate(items.length, (i) => i));
                            }
                          });
                        },
                        child: Text(
                          allSelected ? 'Solo actual' : 'Seleccionar todas',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.map((it) {
                          final isChecked = selectedIndexes.contains(it.index);
                          return CheckboxListTile(
                            value: isChecked,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedIndexes.add(it.index);
                                } else {
                                  if (selectedIndexes.length > 1) {
                                    selectedIndexes.remove(it.index);
                                  }
                                }
                              });
                            },
                            secondary: Icon(it.icon, size: 20),
                            title: Text(
                              it.instrument,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${_buildFormattedDocName(widget.hymn.title, it.instrument)}.pdf',
                              style: GoogleFonts.nunito(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: selectedIndexes.isEmpty
                          ? null
                          : () {
                              Navigator.of(modalCtx).pop();
                              final toPrint = selectedIndexes.map((i) => items[i]).toList();
                              _printMultipleDocuments(toPrint);
                            },
                      icon: const Icon(Icons.print_rounded),
                      label: Text(
                        selectedIndexes.length == 1
                            ? 'Imprimir ${items[selectedIndexes.first].instrument}'
                            : 'Imprimir ${selectedIndexes.length} partituras seleccionadas',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Compartir Inteligente (Individual, Todas o Selección) ──────────────
  Future<void> _shareMultipleDocuments(List<SheetMusicItem> toShare) async {
    if (toShare.isEmpty || _isSharingAction) return;
    setState(() => _isSharingAction = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text(
              toShare.length == 1
                  ? 'Preparando partitura de «${toShare.first.instrument}»...'
                  : 'Descargando y preparando ${toShare.length} partituras...',
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      if (kIsWeb) {
        // En Web: descarga directa en el navegador con el nombre completo
        for (final item in toShare) {
          final isPdf = item.url.toLowerCase().contains('.pdf');
          final ext = isPdf ? 'pdf' : 'jpg';
          final docName = '${_buildFormattedDocName(widget.hymn.title, item.instrument)}.$ext';
          final response = await http.get(Uri.parse(item.url)).timeout(const Duration(seconds: 20));
          if (response.statusCode == 200) {
            await Printing.sharePdf(bytes: response.bodyBytes, filename: docName);
          }
        }
      } else {
        // En Móvil / Desktop: guardar temporalmente y compartir archivos juntos
        final tempDir = await getTemporaryDirectory();
        final xFiles = <XFile>[];

        for (final item in toShare) {
          final isPdf = item.url.toLowerCase().contains('.pdf');
          final ext = isPdf ? 'pdf' : 'jpg';
          final docName = '${_buildFormattedDocName(widget.hymn.title, item.instrument)}.$ext';
          final localFile = io.File('${tempDir.path}/$docName');

          if (!await localFile.exists()) {
            final response = await http.get(Uri.parse(item.url)).timeout(const Duration(seconds: 25));
            if (response.statusCode == 200) {
              await localFile.writeAsBytes(response.bodyBytes);
            }
          }

          if (await localFile.exists()) {
            xFiles.add(XFile(
              localFile.path,
              name: docName,
              mimeType: isPdf ? 'application/pdf' : 'image/jpeg',
            ));
          }
        }

        if (xFiles.isEmpty) {
          throw Exception('No se pudieron preparar los archivos de partitura.');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        Rect? sharePositionOrigin;
        try {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            final pos = box.localToGlobal(Offset.zero);
            sharePositionOrigin = Rect.fromLTWH(
              pos.dx + box.size.width / 4,
              pos.dy + box.size.height - 80,
              box.size.width / 2,
              60,
            );
          }
        } catch (_) {}

        if ((sharePositionOrigin == null || sharePositionOrigin.isEmpty) && mounted) {
          final size = MediaQuery.of(context).size;
          sharePositionOrigin = Rect.fromLTWH(size.width / 4, size.height / 2, size.width / 2, 60);
        }

        final subject = toShare.length == 1
            ? 'Partitura: ${widget.hymn.title} - ${toShare.first.instrument}'
            : 'Partituras: ${widget.hymn.title} (${toShare.length} instrumentos)';

        final text = toShare.length == 1
            ? 'Partitura de «${widget.hymn.title}» (${toShare.first.instrument}) - Himnario Cristiano IUMP'
            : 'Partituras de «${widget.hymn.title}» (${toShare.length} instrumentos: ${toShare.map((e) => e.instrument).join(", ")}) - Himnario Cristiano IUMP';

        await Share.shareXFiles(
          xFiles,
          subject: subject,
          text: text,
          sharePositionOrigin: sharePositionOrigin,
        );
      }
    } catch (e) {
      debugPrint('Error compartiendo partituras: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir partituras: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingAction = false);
    }
  }

  void _showShareDialog(List<SheetMusicItem> items, int currentIdx) {
    if (items.isEmpty) return;
    if (items.length == 1) {
      _shareMultipleDocuments([items.first]);
      return;
    }

    final currentItem = items[currentIdx.clamp(0, items.length - 1)];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final theme = Theme.of(ctx);
        final selectedIndexes = <int>{currentIdx};

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final allSelected = selectedIndexes.length == items.length;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(modalCtx).padding.bottom),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.share_rounded, color: theme.colorScheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Compartir Partituras',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '«${widget.hymn.title}» • ${items.length} instrumentos',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Opción 1: Compartir solo actual
                  InkWell(
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      _shareMultipleDocuments([currentItem]);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(currentItem.icon, color: theme.colorScheme.primary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compartir solo ${currentItem.instrument}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  'Archivo: «${_buildFormattedDocName(widget.hymn.title, currentItem.instrument)}.pdf»',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Opción 2: Compartir TODAS
                  InkWell(
                    onTap: () {
                      Navigator.of(modalCtx).pop();
                      _shareMultipleDocuments(items);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.collections_bookmark_rounded, color: Colors.amber, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compartir todas las partituras (${items.length} archivos)',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: isDark ? Colors.amber[300] : Colors.amber[900],
                                  ),
                                ),
                                Text(
                                  'Envía los ${items.length} instrumentos juntos con sus nombres correspondientes',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'O escoge qué instrumentos enviar:',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            if (allSelected) {
                              selectedIndexes.clear();
                              selectedIndexes.add(currentIdx);
                            } else {
                              selectedIndexes.addAll(List.generate(items.length, (i) => i));
                            }
                          });
                        },
                        child: Text(
                          allSelected ? 'Solo actual' : 'Seleccionar todas',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.map((it) {
                          final isChecked = selectedIndexes.contains(it.index);
                          return CheckboxListTile(
                            value: isChecked,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedIndexes.add(it.index);
                                } else {
                                  if (selectedIndexes.length > 1) {
                                    selectedIndexes.remove(it.index);
                                  }
                                }
                              });
                            },
                            secondary: Icon(it.icon, size: 20),
                            title: Text(
                              it.instrument,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${_buildFormattedDocName(widget.hymn.title, it.instrument)}.pdf',
                              style: GoogleFonts.nunito(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: selectedIndexes.isEmpty
                          ? null
                          : () {
                              Navigator.of(modalCtx).pop();
                              final toShare = selectedIndexes.map((i) => items[i]).toList();
                              _shareMultipleDocuments(toShare);
                            },
                      icon: const Icon(Icons.share_rounded),
                      label: Text(
                        selectedIndexes.length == 1
                            ? 'Compartir ${items[selectedIndexes.first].instrument}'
                            : 'Compartir ${selectedIndexes.length} archivos seleccionados',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Selector Visual de Instrumentos ──────────────────────────────────
  Widget _buildInstrumentSelector(List<SheetMusicItem> items, bool isDark, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.library_music_rounded, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Instrumentos disponibles',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Instrumento anterior',
                    onPressed: _selectedDocIndex > 0
                        ? () => setState(() => _selectedDocIndex--)
                        : null,
                  ),
                  Text(
                    '${_selectedDocIndex + 1}/${items.length}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Siguiente instrumento',
                    onPressed: _selectedDocIndex < items.length - 1
                        ? () => setState(() => _selectedDocIndex++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: items.map((item) {
                final isSelected = item.index == _selectedDocIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDocIndex = item.index;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 16,
                            color: isSelected ? theme.colorScheme.onPrimary : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.instrument,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? theme.colorScheme.onPrimary : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _currentUrls;
    final items = SheetMusicItem.parseAll(urls);
    final isAdmin = ref.watch(adminModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_selectedDocIndex >= items.length && items.isNotEmpty) {
      _selectedDocIndex = items.length - 1;
    }

    Widget body = _isUploading
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Subiendo partituras... ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        : items.isEmpty
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildUploadButtons(),
                    ),
                  if (items.length > 1)
                    _buildInstrumentSelector(items, isDark, theme),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final currentItem = items[_selectedDocIndex];
                        final url = currentItem.url;
                        final isPdf = url.toLowerCase().contains('.pdf');

                        return Stack(
                          children: [
                            Center(
                              child: isPdf
                                  ? PdfSheetMusicPreview(
                                      key: ValueKey(url),
                                      url: url,
                                      fileName: currentItem.rawFileName,
                                      hymnTitle: widget.hymn.title,
                                      instrument: currentItem.instrument,
                                      onOpenFullscreen: () => _showPrintDialog(items, _selectedDocIndex),
                                      onShare: () => _showShareDialog(items, _selectedDocIndex),
                                      isDark: isDark,
                                    )
                                  : InteractiveViewer(
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      child: Image.network(
                                        url,
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
                                  tooltip: 'Eliminar partitura de ${currentItem.instrument}',
                                  style: IconButton.styleFrom(backgroundColor: isDark ? Colors.black87 : Colors.white70),
                                  onPressed: () => _deleteAttachment(url, currentItem.instrument),
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

class PdfSheetMusicPreview extends StatefulWidget {
  final String url;
  final String fileName;
  final String hymnTitle;
  final String instrument;
  final VoidCallback onOpenFullscreen;
  final VoidCallback onShare;
  final bool isDark;

  const PdfSheetMusicPreview({
    super.key,
    required this.url,
    required this.fileName,
    required this.hymnTitle,
    required this.instrument,
    required this.onOpenFullscreen,
    required this.onShare,
    required this.isDark,
  });

  @override
  State<PdfSheetMusicPreview> createState() => _PdfSheetMusicPreviewState();
}

class _PdfSheetMusicPreviewState extends State<PdfSheetMusicPreview> {
  List<Uint8List> _pages = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _renderPdfPages();
  }

  @override
  void didUpdateWidget(covariant PdfSheetMusicPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _currentPage = 0;
      _isLoading = true;
      _hasError = false;
      _pages.clear();
      _renderPdfPages();
    }
  }

  Future<void> _renderPdfPages() async {
    try {
      final response = await http.get(Uri.parse(widget.url)).timeout(const Duration(seconds: 25));
      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;
        final List<Uint8List> pages = [];
        await for (final page in Printing.raster(pdfBytes, dpi: 150)) {
          final pngBytes = await page.toPng();
          pages.add(pngBytes);
        }
        if (mounted) {
          setState(() {
            _pages = pages;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _isLoading = false; _hasError = true; });
      }
    } catch (e) {
      debugPrint('Error renderizando páginas de partitura: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.redAccent),
            const SizedBox(height: 18),
            Text(
              'Cargando partitura (${widget.instrument})...',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Preparando vista previa en alta resolución',
              style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_hasError || _pages.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 80, color: Colors.redAccent),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: widget.onOpenFullscreen,
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            label: Text(
              'Imprimir ${widget.instrument}',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onShare,
            icon: const Icon(Icons.share_rounded, color: Colors.redAccent),
            label: Text(
              'Compartir Partitura',
              style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _pages.length,
          onPageChanged: (idx) => setState(() => _currentPage = idx),
          itemBuilder: (context, pIdx) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.5,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(
                      _pages[pIdx],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 480;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pages.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Pág. ${_currentPage + 1} de ${_pages.length}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.onOpenFullscreen,
                              icon: const Icon(Icons.print_rounded, size: 20),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isCompact ? 'Imprimir' : 'Imprimir Partitura',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompact ? 8 : 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onShare,
                              icon: const Icon(Icons.share_rounded, size: 18),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isCompact ? 'Compartir' : 'Compartir Partituras',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: widget.isDark ? Colors.black54 : Colors.white70,
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompact ? 8 : 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
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
  }
}
