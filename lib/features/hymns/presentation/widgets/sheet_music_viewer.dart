import 'dart:io';
import 'dart:typed_data';
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


  String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final path = Uri.decodeComponent(uri.path);
      final fileNameWithTimestamp = path.split('/').last;
      final firstUnderscore = fileNameWithTimestamp.indexOf('_');
      if (firstUnderscore != -1 && firstUnderscore < fileNameWithTimestamp.length - 1) {
        return fileNameWithTimestamp.substring(firstUnderscore + 1);
      }
      return fileNameWithTimestamp;
    } catch (e) {
      return 'Partitura';
    }
  }

  bool _isOpeningPdf = false;
  bool _isSharing = false;

  Future<void> _openPdf(String url) async {
    if (_isOpeningPdf) return;
    setState(() => _isOpeningPdf = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Abriendo partitura nativa...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final pdfBytes = response.bodyBytes;
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: '${widget.hymn.title} - Partitura',
          format: PdfPageFormat.letter,
          dynamicLayout: false,
        );
      } else {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error abriendo visor PDF nativo: $e');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } finally {
      if (mounted) {
        setState(() => _isOpeningPdf = false);
      }
    }
  }

  Future<void> _shareDocument(String url) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Preparando documento para compartir...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final isPdf = url.toLowerCase().contains('.pdf');
      final ext = isPdf ? 'pdf' : 'jpg';
      final tempDir = await getTemporaryDirectory();
      final safeTitle = widget.hymn.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final localFile = File('${tempDir.path}/Partitura_$safeTitle.$ext');
      
      if (!await localFile.exists()) {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        await localFile.writeAsBytes(response.bodyBytes);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Cálculo de anchor rect para iPadOS / tablets (evita error de popover nulo en iOS)
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
        sharePositionOrigin = Rect.fromLTWH(
          size.width / 4,
          size.height / 2,
          size.width / 2,
          60,
        );
      }

      await Share.shareXFiles(
        [XFile(localFile.path, mimeType: isPdf ? 'application/pdf' : 'image/jpeg')],
        subject: 'Partitura: ${widget.hymn.title}',
        text: 'Partitura de «${widget.hymn.title}» - Himnario Cristiano IUMP',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Error compartiendo archivo local: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Rect? fallbackOrigin;
      try {
        final size = MediaQuery.of(context).size;
        fallbackOrigin = Rect.fromLTWH(size.width / 4, size.height / 2, size.width / 2, 60);
      } catch (_) {}
      await Share.share(
        url,
        subject: 'Partitura de ${widget.hymn.title}',
        sharePositionOrigin: fallbackOrigin,
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.hymn.sheetMusicUrls;
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
                                  ? PdfSheetMusicPreview(
                                      url: url,
                                      fileName: _extractFileName(url),
                                      hymnTitle: widget.hymn.title,
                                      onOpenFullscreen: () => _openPdf(url),
                                      onShare: () => _shareDocument(url),
                                      isDark: Theme.of(context).brightness == Brightness.dark,
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
                                  style: IconButton.styleFrom(backgroundColor: Colors.white70),
                                  onPressed: () => _deleteAttachment(url),
                                ),
                              ),
                            if (urls.length > 1)
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Doc. ${index + 1} de ${urls.length}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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

class PdfSheetMusicPreview extends StatefulWidget {
  final String url;
  final String fileName;
  final String hymnTitle;
  final VoidCallback onOpenFullscreen;
  final VoidCallback onShare;
  final bool isDark;

  const PdfSheetMusicPreview({
    super.key,
    required this.url,
    required this.fileName,
    required this.hymnTitle,
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
              'Cargando partitura oficial...',
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
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
            label: Text(
              'Abrir ${widget.fileName}',
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
                              icon: const Icon(Icons.fullscreen_rounded, size: 20),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isCompact ? 'Ver / Imprimir' : 'Imprimir / Pantalla Completa',
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
                                  isCompact ? 'Compartir' : 'Compartir Partitura',
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
