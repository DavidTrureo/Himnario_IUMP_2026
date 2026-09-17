import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/hymn_pdf_service.dart';
import '../../../core/services/local_hymn_storage_service.dart';
import '../domain/hymn.dart';
import 'hymn_list_screen.dart';

class ScannerResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> initialData;

  const ScannerResultScreen({super.key, required this.initialData});

  @override
  ConsumerState<ScannerResultScreen> createState() => _ScannerResultScreenState();
}

class _ScannerResultScreenState extends ConsumerState<ScannerResultScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _timeSigCtrl;
  late TextEditingController _lyricsCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialData['title'] ?? '');
    _keyCtrl = TextEditingController(text: widget.initialData['key'] ?? '');
    _timeSigCtrl = TextEditingController(text: widget.initialData['timeSignature'] ?? '');
    _lyricsCtrl = TextEditingController(text: widget.initialData['lyrics'] ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _keyCtrl.dispose();
    _timeSigCtrl.dispose();
    _lyricsCtrl.dispose();
    super.dispose();
  }

  Hymn _buildTempHymn() {
    return Hymn(
      id: DateTime.now().millisecondsSinceEpoch % 1000000,
      title: _titleCtrl.text.trim().isEmpty ? 'Sin Título' : _titleCtrl.text.trim(),
      toneNote: _keyCtrl.text.trim(),
      beats: '4', // Default
      timeSignature: _timeSigCtrl.text.trim(),
      lyrics: _lyricsCtrl.text.trim(),
      collection: 'coros',
      audioUrl: '',
      category: 'Transcripción IA',
    );
  }


  bool _isDuplicate(String lyrics, List<dynamic> existingHymns) {
    // A simple heuristic for duplicate checking: check if any existing hymn's lyrics are very similar.
    final cleanLyrics = lyrics.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    for (final hymn in existingHymns) {
      final existingClean = (hymn.lyrics ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (existingClean.isNotEmpty && cleanLyrics.contains(existingClean) || existingClean.contains(cleanLyrics)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveHymn(bool isLocal) async {
    final title = _titleCtrl.text.trim();
    final lyrics = _lyricsCtrl.text.trim();
    
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
          'coros',
          key: _keyCtrl.text.trim(),
          beats: '4',
          timeSignature: _timeSigCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guardado localmente.')),
          );
        }
      } else {
        await FirebaseFirestore.instance.collection('cantos_sugeridos').add({
          'title': title,
          'lyrics': lyrics,
          'collection': 'coros',
          'key': _keyCtrl.text.trim(),
          'beats': '4',
          'timeSignature': _timeSigCtrl.text.trim(),
          'requesterName': 'Usuario (Escáner IA)',
          'requesterChurch': 'Himnario App',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Canto sugerido enviado a revisión.')),
          );
        }
      }
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Resultados de IA', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                    ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Letra procesada con éxito. Puedes editar el título, tonalidad o letra antes de guardar o exportar.',
                          style: GoogleFonts.nunito(
                            color: isDark ? Colors.amber[200] : Colors.amber[900], 
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Form Fields
                _buildLabel('Título'),
                TextFormField(
                  controller: _titleCtrl,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18),
                  decoration: _buildInputDecoration(theme, isDark),
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Tonalidad (Armadura)'),
                          TextFormField(
                            controller: _keyCtrl,
                            
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: Colors.grey),
                            decoration: _buildInputDecoration(theme, isDark).copyWith(
                              fillColor: isDark ? Colors.black26 : Colors.grey[200],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Métrica'),
                          TextFormField(
                            controller: _timeSigCtrl,
                            
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: Colors.grey),
                            decoration: _buildInputDecoration(theme, isDark).copyWith(
                              fillColor: isDark ? Colors.black26 : Colors.grey[200],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                _buildLabel('Letra y Acordes'),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: TextFormField(
                      controller: _lyricsCtrl,
                      maxLines: 18,
                      style: GoogleFonts.robotoMono(
                        fontSize: 14, 
                        height: 1.6, 
                        color: isDark ? Colors.white : Colors.black87
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFDFBF7), // Slight off-white like paper
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100), // Space for bottom buttons
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _saveHymn(true),
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Guardar Local'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : () => _saveHymn(false),
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Sugerir Oficial'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(ThemeData theme, bool isDark) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
