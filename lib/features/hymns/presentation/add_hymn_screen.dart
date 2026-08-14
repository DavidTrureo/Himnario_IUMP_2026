import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final _lyricsController = TextEditingController();
  final _keyController = TextEditingController();
  final _nameController = TextEditingController();
  final _churchController = TextEditingController();
  String _selectedCollection = 'especiales';
  bool _isLoading = false;

  final List<String> _collections = ['iump', 'coros', 'especiales'];

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    _keyController.dispose();
    _nameController.dispose();
    _churchController.dispose();
    super.dispose();
  }

  Future<String?> _showGeminiKeyInputDialog(BuildContext context) async {
    String? key = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('API Key de Gemini'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Para usar el escáner inteligente, necesitas ingresar tu API Key de Gemini. Puedes obtenerla gratis en Google AI Studio.'),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder()),
              onChanged: (val) => key = val,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, key), child: const Text('Guardar')),
        ],
      ),
    );
    return key;
  }

  Future<void> _scanText() async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('gemini_api_key') ?? '';
    if (apiKey.isEmpty) {
      if (!mounted) return;
      final enteredKey = await _showGeminiKeyInputDialog(context);
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

      final requestBody = jsonEncode({
        'contents': [{
          'parts': [
            {
              'text': 'Analiza esta imagen y extrae el texto del canto, himno o alabanza cristiana. '
                      'Identifica el título oficial del canto (si no está, infiérelo de la letra), '
                      'los acordes iniciales / tono (ej: RE / 2 TIEMPOS, SOLm / 3 TIEMPOS) si vienen escritos en alguna parte (si no vienen, deja el tono vacío), '
                      'y la letra completa del canto organizada de forma prolija en estrofas y coros claros, '
                      'eliminando cualquier acorde escrito entre medio de la letra (queremos solo el texto limpio de la letra). \n'
                      'Retorna el resultado estrictamente en este formato JSON, sin bloques de código markdown, sin explicaciones ni textos decorativos, solo el JSON:\n'
                      '{\n'
                      '  "title": "Título del canto",\n'
                      '  "tone": "Acorde / N tiempos (dejar vacío si no hay indicación)",\n'
                      '  "lyrics": "Letra completa limpia"\n'
                      '}'
            },
            {
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': base64Image
              }
            }
          ]
        }]
      });

      http.Response? response;
      final modelsToTry = ['gemini-2.0-flash', 'gemini-1.5-flash'];

      for (final model in modelsToTry) {
        try {
          final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
          final res = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          ).timeout(const Duration(seconds: 15));
          
          if (res.statusCode == 200) {
            response = res;
            break;
          }
        } catch (_) {}

        if (response == null) {
          try {
            final url = Uri.parse('https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$apiKey');
            final res = await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            ).timeout(const Duration(seconds: 15));
            
            if (res.statusCode == 200) {
              response = res;
              break;
            }
          } catch (_) {}
        }
      }

      if (mounted) Navigator.pop(context); // Cierra cargando

      if (response != null && response.statusCode == 200) {
        final respData = jsonDecode(response.body);
        String rawText = respData['candidates'][0]['content']['parts'][0]['text'] as String;
        
        rawText = rawText.trim();
        if (rawText.startsWith('```json')) {
          rawText = rawText.substring(7);
        } else if (rawText.startsWith('```')) {
          rawText = rawText.substring(3);
        }
        if (rawText.endsWith('```')) {
          rawText = rawText.substring(0, rawText.length - 3);
        }
        rawText = rawText.trim();

        final parsed = jsonDecode(rawText);
        if (parsed is Map) {
          final titleVal = parsed['title']?.toString() ?? '';
          final toneVal = parsed['tone']?.toString() ?? '';
          final lyricsVal = parsed['lyrics']?.toString() ?? '';

          if (titleVal.isNotEmpty) _titleController.text = titleVal.toUpperCase();
          if (toneVal.isNotEmpty) _keyController.text = toneVal.toUpperCase();
          if (lyricsVal.isNotEmpty) _lyricsController.text = lyricsVal;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Texto y estructura cargados con éxito!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        throw Exception(response?.body ?? 'Error al llamar a Gemini');
      }

    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // Cerrar cargando si sigue abierto
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error en el escaneo'),
            content: Text('No pudimos procesar la imagen de manera exitosa: $e'),
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

    // Normalizar
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
        return true; // Se parece demasiado a uno existente
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
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Canto'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCollection,
                    decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                    items: _collections.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                    onChanged: (v) => setState(() => _selectedCollection = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(labelText: 'Tono (Ej: Do Mayor)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título del canto', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lyricsController,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: 'Letra del canto', 
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt),
                  tooltip: 'Escanear con OCR',
                  onPressed: _scanText,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Datos del sugeridor (Opcional, solo si vas a Sugerir Oficial)', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Tu Nombre', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _churchController,
                    decoration: const InputDecoration(labelText: 'Tu Iglesia / Local', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _saveHymn(true),
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Guardar Local'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : () => _saveHymn(false),
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Sugerir Oficial'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
