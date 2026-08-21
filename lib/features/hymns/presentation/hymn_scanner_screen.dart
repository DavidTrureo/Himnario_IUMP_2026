import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/services/gemini_ai_service.dart';
import 'scanner_result_screen.dart';

class HymnScannerScreen extends StatefulWidget {
  const HymnScannerScreen({super.key});

  @override
  State<HymnScannerScreen> createState() => _HymnScannerScreenState();
}

class _HymnScannerScreenState extends State<HymnScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: \$e");
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    String apiKey = await GeminiAiService.getApiKey();
    if (apiKey.isEmpty) {
      final newKey = await GeminiAiService.showApiKeyInputDialog(context);
      if (newKey != null && newKey.isNotEmpty) {
        await GeminiAiService.saveApiKey(newKey);
        apiKey = newKey;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Necesitas una Clave API de Gemini para usar esta función.')),
          );
        }
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);

      
      String mimeType = 'image/jpeg';
      if (_imageFile!.path.toLowerCase().endsWith('.png')) mimeType = 'image/png';
      else if (_imageFile!.path.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';
      else if (_imageFile!.path.toLowerCase().endsWith('.heic')) mimeType = 'image/heic';
      
      final result = await GeminiAiService.transcribeSheetMusic(base64Image, mimeType: mimeType);


      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (result != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScannerResultScreen(
                initialData: result,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo procesar la imagen. Verifica tu conexión o clave API de Gemini.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Escanear con IA', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_rounded),
            tooltip: 'Cambiar Clave API',
            onPressed: () async {
              final newKey = await GeminiAiService.showApiKeyInputDialog(context);
              if (newKey != null && newKey.isNotEmpty) {
                await GeminiAiService.saveApiKey(newKey);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Clave API actualizada correctamente.')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF020617)],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Scanner Frame
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        colors: _isProcessing 
                          ? [theme.colorScheme.primary, Colors.purpleAccent, theme.colorScheme.primary]
                          : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
                      ),
                      boxShadow: _isProcessing ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ] : [],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: _imageFile != null
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  kIsWeb 
                                      ? Image.network(_imageFile!.path, fit: BoxFit.cover, height: 350, width: double.infinity)
                                      : Image.file(File(_imageFile!.path), fit: BoxFit.cover, height: 350, width: double.infinity),
                                  if (_isProcessing)
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      height: 350,
                                      width: double.infinity,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const CircularProgressIndicator(color: Colors.white),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Analizando partitura...',
                                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          )
                                        ],
                                      ),
                                    ),
                                ],
                              )
                            : Container(
                                constraints: const BoxConstraints(minHeight: 300),
                                width: double.infinity,
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.document_scanner_rounded, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                                    const SizedBox(height: 16),
                                    Column(
                                      children: [
                                        Text(
                                          'Sube una foto de una letra o partitura con acordes',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.nunito(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 20),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'A diferencia del botón "+" de la pantalla principal que es para escritura manual, esta herramienta está diseñada para procesar imágenes con Inteligencia Artificial.',
                                                      style: GoogleFonts.nunito(color: Colors.grey[300], fontSize: 13, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'La IA extraerá automáticamente el texto limpio de la letra desde la foto de tu cancionero (ignorando los acordes para evitar errores de alineación) para ahorrarte la escritura manual.',
                                                      style: GoogleFonts.nunito(color: Colors.amber[100], fontSize: 13),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  if (!_isProcessing) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionButton(
                          context,
                          icon: Icons.photo_library_rounded,
                          label: 'Galería',
                          onTap: () => _pickImage(ImageSource.gallery),
                          isPrimary: false,
                        ),
                        const SizedBox(width: 16),
                        _buildActionButton(
                          context,
                          icon: Icons.camera_alt_rounded,
                          label: 'Cámara',
                          onTap: () => _pickImage(ImageSource.camera),
                          isPrimary: false,
                        ),
                      ],
                    ),
                    if (_imageFile != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _buildActionButton(
                          context,
                          icon: Icons.auto_awesome_rounded,
                          label: 'Procesar con Gemini',
                          onTap: _processImage,
                          isPrimary: true,
                        ),
                      ),
                    ]
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, required bool isPrimary}) {
    final theme = Theme.of(context);
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? theme.colorScheme.primary : const Color(0xFF334155),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isPrimary ? 8 : 0,
        shadowColor: isPrimary ? theme.colorScheme.primary.withValues(alpha: 0.5) : null,
      ),
      icon: Icon(icon, size: 22),
      label: Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
      onPressed: onTap,
    );
  }

}
