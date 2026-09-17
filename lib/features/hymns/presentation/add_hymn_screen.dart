import 'package:flutter/material.dart';
import 'hymn_list_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/gemini_ai_service.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:himnario_iump/core/services/local_hymn_storage_service.dart';
import 'package:himnario_iump/features/hymns/domain/hymn.dart';
import 'package:himnario_iump/features/hymns/presentation/hymn_list_screen.dart';

class AddHymnScreen extends ConsumerStatefulWidget {
  const AddHymnScreen({super.key});

  @override
  ConsumerState<AddHymnScreen> createState() => _AddHymnScreenState();
}

class _AddHymnScreenState extends ConsumerState<AddHymnScreen> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _keyController = TextEditingController();
  final _beatsController = TextEditingController();
  final _timeSignatureController = TextEditingController();
  final _nameController = TextEditingController();
  final _churchController = TextEditingController();

  String _selectedCollection = 'especiales';
  bool _isLoading = false;

  final List<String> _collections = ['iump', 'especiales', 'coros'];

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    _keyController.dispose();
    _beatsController.dispose();
    _timeSignatureController.dispose();
    _nameController.dispose();
    _churchController.dispose();
    super.dispose();
  }



  Future<void> _scanText() async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('gemini_api_key') ?? '';
    if (apiKey.isEmpty) {
      if (!mounted) return;
      final enteredKey = await GeminiAiService.showApiKeyInputDialog(context, reason: 'Para usar el escáner OCR con IA necesitas tu propia llave de API gratuita de Google AI Studio.');
      if (enteredKey == null || enteredKey.trim().isEmpty) return;
      apiKey = enteredKey.trim();
      await prefs.setString('gemini_api_key', apiKey);
    }

    if (!mounted) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Tomar Foto con Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);

    if (pickedFile == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Analizando texto con Gemini...',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );

        try {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      String mimeType = 'image/jpeg';
      if (pickedFile.path.toLowerCase().endsWith('.png')) mimeType = 'image/png';
      else if (pickedFile.path.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';
      else if (pickedFile.path.toLowerCase().endsWith('.heic')) mimeType = 'image/heic';

      final result = await GeminiAiService.transcribeSheetMusic(base64Image, mimeType: mimeType);
      
      if (mounted) Navigator.pop(context); // Cierra cargando

      if (result != null) {
          final titleVal = result['title']?.toString() ?? '';
          final toneVal = result['key']?.toString() ?? '';
          final lyricsVal = result['lyrics']?.toString() ?? '';

          if (titleVal.isNotEmpty && titleVal.toLowerCase() != 'título desconocido') _titleController.text = titleVal.toUpperCase();
          if (toneVal.isNotEmpty && toneVal.toLowerCase() != 'desconocida') _keyController.text = toneVal.toUpperCase();
          if (lyricsVal.isNotEmpty) _lyricsController.text = lyricsVal;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Texto y estructura cargados con éxito!'),
                backgroundColor: Colors.green,
              ),
            );
          }
      } else {
        throw Exception('No se pudo procesar la imagen (respuesta vacía)');
      }

    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // Cerrar cargando si sigue abierto
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error en el escaneo'),
            content: Text('Los servidores de IA están temporalmente ocupados o hubo un error de conexión.\n\nPor favor, intenta nuevamente en un momento.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
            ],
          ),
        );
      }
    }
  }

  bool _isDuplicate(String newLyrics, List<Hymn> existingHymns) {
    if (newLyrics.trim().length < 20) return false;

    String normalize(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ]'), '').toLowerCase();
    
    final cleanNew = normalize(newLyrics);
    Set<String> getTrigrams(String str) {
      final Set<String> trigrams = {};
      for (int i = 0; i <= str.length - 3; i++) {
        trigrams.add(str.substring(i, i + 3));
      }
      return trigrams;
    }

    final newTrigrams = getTrigrams(cleanNew);
    if (newTrigrams.isEmpty) return false;

    for (final hymn in existingHymns) {
      final cleanExisting = normalize(hymn.lyrics);
      final existingTrigrams = getTrigrams(cleanExisting);
      if (existingTrigrams.isEmpty) continue;

      int intersection = 0;
      for (final t in newTrigrams) {
        if (existingTrigrams.contains(t)) intersection++;
      }

      final similarity = (2.0 * intersection) / (newTrigrams.length + existingTrigrams.length);
      if (similarity > 0.8) {
        return true; 
      }
    }
    return false;
  }

  Future<void> _saveHymn(bool isLocal) async {
    final title = _titleController.text.trim();
    final lyrics = _lyricsController.text.trim();
    
    if (title.isEmpty || lyrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa título y letra')),
      );
      return;
    }

    final existingHymns = ref.read(allHymnsProvider).value ?? [];

    if (_isDuplicate(lyrics, existingHymns)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Posible Duplicado'),
          content: const Text('Este canto se parece mucho a uno que ya existe en el himnario. ¿Seguro que deseas añadirlo?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Añadir de todos modos')),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    try {
      if (isLocal) {
        await LocalHymnStorageService.saveCustomHymn(
          title, 
          lyrics, 
          _selectedCollection,
          key: _keyController.text.trim(),
          beats: _beatsController.text.trim(),
          timeSignature: _timeSignatureController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardado localmente.')),
        );
      } else {
        await FirebaseFirestore.instance.collection('cantos_sugeridos').add({
          'title': title,
          'lyrics': lyrics,
          'collection': _selectedCollection,
          'key': _keyController.text.trim(),
          'beats': _beatsController.text.trim(),
          'timeSignature': _timeSignatureController.text.trim(),
          'requesterName': _nameController.text.trim(),
          'requesterChurch': _churchController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canto sugerido enviado a revisión.')),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el canto. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title, IconData icon, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : Colors.grey[50];
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Añadir Canto', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            // CARD 1: INFORMACIÓN PRINCIPAL
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Información Básica', Icons.info_outline),
                    DropdownButtonFormField<String>(
                      value: _selectedCollection,
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: const Icon(Icons.folder_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      ),
                      items: _collections.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                      onChanged: (v) => setState(() => _selectedCollection = v!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return TextEditingValue(
                            text: newValue.text.toUpperCase(),
                            selection: newValue.selection,
                          );
                        }),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Título del canto',
                        prefixIcon: const Icon(Icons.text_fields),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CARD 2: MUSICALIZACIÓN
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Musicalización', Icons.music_note_outlined),
                    TextField(
                      controller: _keyController,
                      decoration: InputDecoration(
                        labelText: 'Tono (Ej: Do Mayor, Sol)',
                        prefixIcon: const Icon(Icons.piano),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _beatsController,
                            decoration: InputDecoration(
                              labelText: 'Tiempo (Ej: 120)',
                              prefixIcon: const Icon(Icons.speed),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _timeSignatureController,
                            decoration: InputDecoration(
                              labelText: 'Métrica (Ej: 4/4)',
                              prefixIcon: const Icon(Icons.straighten),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CARD 3: LETRA
            Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Letra del Canto', Icons.article_outlined, trailing: IconButton(
                      icon: const Icon(Icons.travel_explore_rounded, color: Colors.blueAccent),
                      tooltip: 'Buscar Letra en Internet (IA)',
                      onPressed: () => _searchLyricsWithAI(context),
                    )),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                              tooltip: 'Mejorar Ortografía y Puntuación con IA',
                              onPressed: () async {
                                if (_lyricsController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ingresa la letra antes de pulir con IA')),
                                  );
                                  return;
                                }
                                final result = await GeminiAiService.correctHymnGrammar(
                                  context: context,
                                  title: _titleController.text.trim(),
                                  lyrics: _lyricsController.text.trim(),
                                );
                                if (result != null) {
                                  _titleController.text = result['title']!;
                                  _lyricsController.text = result['lyrics']!;
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.document_scanner),
                              tooltip: 'Escanear con OCR',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              onPressed: _scanText,
                            ),
                          ],
                        ),
                      ],
                    ),
                    TextField(
                      controller: _lyricsController,
                      maxLines: 12,
                      decoration: InputDecoration(
                        hintText: 'Pega la letra aquí o escanea una foto con el botón superior.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CARD 4: DATOS DEL SUGERIDOR
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E293B) : Colors.blueGrey[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? Colors.blueGrey[800]! : Colors.blueGrey[200]!, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Datos del Sugeridor', Icons.person_outline),
                    Text(
                      'Opcional. Se enviarán junto a la letra si eliges "Sugerir Oficial".',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Tu Nombre',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark ? Colors.grey[900] : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _churchController,
                            decoration: InputDecoration(
                              labelText: 'Iglesia/Local',
                              prefixIcon: const Icon(Icons.church_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark ? Colors.grey[900] : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // BOTONES DE ACCIÓN
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : () => _saveHymn(true),
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Guardar Local'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : () => _saveHymn(false),
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Sugerir Oficial'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _searchLyricsWithAI(BuildContext context) async {
    final title = _titleController.text.trim();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => OnlineSearchDialog(
        initialQuery: title,
        returnResults: true,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (result['title'] != null && result['title'].toString().isNotEmpty) {
          _titleController.text = result['title'];
        }
        if (result['lyrics'] != null && result['lyrics'].toString().isNotEmpty) {
          _lyricsController.text = result['lyrics'];
        }
        if (result['key'] != null && result['key'].toString().isNotEmpty) {
          _keyController.text = result['key'];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos importados exitosamente.')));
    }
  }

}
