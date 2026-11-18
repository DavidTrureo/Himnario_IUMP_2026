import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/gemini_ai_service.dart';
import '../../../core/services/local_hymn_storage_service.dart';
import '../../../core/services/suggestion_tracking_service.dart';
import '../domain/hymn.dart';
import 'hymn_list_screen.dart';

class ScannerResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> initialData;

  const ScannerResultScreen({super.key, required this.initialData});

  @override
  ConsumerState<ScannerResultScreen> createState() => _ScannerResultScreenState();
}

class _ScannerResultScreenState extends ConsumerState<ScannerResultScreen> {
  late TextEditingController _idCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _beatsCtrl;
  late TextEditingController _timeSigCtrl;
  late TextEditingController _lyricsCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _churchCtrl;
  String _selectedCollection = 'coros';
  String _selectedMode = 'Mayor';
  String _selectedCategory = '';
  bool _isLoading = false;

  static const List<String> _collections = ['iump', 'especiales', 'coros'];

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController();

    final rawTitle = (widget.initialData['title'] ?? '').toString().trim();
    _titleCtrl = TextEditingController(
      text: rawTitle.toLowerCase() == 'título desconocido' ? '' : rawTitle.toUpperCase(),
    );

    final rawKey = (widget.initialData['key'] ?? '').toString().trim();
    String parsedNote = '';
    if (rawKey.isNotEmpty && !rawKey.toLowerCase().contains('desconocid')) {
      final parsed = Hymn.parseToneComponents(rawKey);
      final note = parsed['toneNote'] ?? '';
      if (note.endsWith('m')) {
        _selectedMode = 'Menor';
        parsedNote = note.substring(0, note.length - 1);
      } else {
        parsedNote = note;
      }
    }
    _keyCtrl = TextEditingController(text: parsedNote);

    final rawSig = (widget.initialData['timeSignature'] ?? '').toString().trim();
    final cleanSig = rawSig.toLowerCase().contains('desconocid') ? '' : rawSig;
    _timeSigCtrl = TextEditingController(text: cleanSig);

    // Inferir tiempos automáticamente si la métrica empieza con un número (ej: "4/4" -> "4", "3/4" -> "3")
    final beatsMatch = RegExp(r'^(\d+)/').firstMatch(cleanSig);
    _beatsCtrl = TextEditingController(text: beatsMatch?.group(1) ?? '');

    _lyricsCtrl = TextEditingController(
      text: (widget.initialData['lyrics'] ?? '').toString(),
    );
    _nameCtrl = TextEditingController();
    _churchCtrl = TextEditingController();
    _loadSavedRequesterProfile();
  }

  Future<void> _loadSavedRequesterProfile() async {
    final profile = await SuggestionTrackingService.getRequesterProfile();
    if (!mounted) return;
    if (_nameCtrl.text.isEmpty && profile.name.isNotEmpty) {
      _nameCtrl.text = profile.name;
    }
    if (_churchCtrl.text.isEmpty && profile.church.isNotEmpty) {
      _churchCtrl.text = profile.church;
    }
  }

  Future<void> _showSuggestionSuccessDialog({
    required String title,
    required String requesterName,
    required String requesterChurch,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Sugerencia Enviada!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu canto "$title" digitalizado con Escáner IA ha sido enviado con tus datos ($requesterName · $requesterChurch).\n\nEl administrador revisará la letra y el formato para incorporarlo próximamente al catálogo oficial.',
                style: GoogleFonts.nunito(fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                '💡 Podrás ver cuándo sea aprobado o gestionado en "Mis Sugerencias Enviadas".',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  void _prefillNextIumpId() {
    if (_selectedCollection != 'iump') return;
    final list = ref.read(hymnsProvider('iump')).value ?? [];
    final official = list.where((h) => !h.isLocalOnly).toList();
    final nextId = official.isEmpty
        ? 1
        : official.map((h) => h.id).reduce((a, b) => a > b ? a : b) + 1;
    _idCtrl.text = nextId.toString();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _titleCtrl.dispose();
    _keyCtrl.dispose();
    _beatsCtrl.dispose();
    _timeSigCtrl.dispose();
    _lyricsCtrl.dispose();
    _nameCtrl.dispose();
    _churchCtrl.dispose();
    super.dispose();
  }

  String _collectionLabel(String c) {
    switch (c) {
      case 'iump':
        return 'HIMNARIO IUMP';
      case 'especiales':
        return 'ALABANZAS ESPECIALES';
      case 'coros':
        return 'COROS DE AVIVAMIENTO';
      default:
        return c.toUpperCase();
    }
  }

  Future<void> _saveHymn({required bool isLocal, required bool isAdmin}) async {
    final title = _titleCtrl.text.trim();
    final lyrics = _lyricsCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (title.isEmpty || lyrics.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa título y letra')),
      );
      return;
    }

    final requesterName = _nameCtrl.text.trim();
    final requesterChurch = _churchCtrl.text.trim();

    if (!isLocal && !isAdmin) {
      if (requesterName.isEmpty || requesterChurch.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF59E0B),
            content: Text(
              'Por favor, ingresa tu Nombre y tu Iglesia/Local para enviar la sugerencia al administrador.',
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
            ),
          ),
        );
        return;
      }
    }

    int? explicitIumpId;
    if (!isLocal && isAdmin && _selectedCollection == 'iump') {
      explicitIumpId = int.tryParse(_idCtrl.text.trim());
      if (explicitIumpId == null || explicitIumpId <= 0) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ingresa un número válido para el Himno IUMP.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      final iumpHymns = ref.read(hymnsProvider('iump')).value ?? [];
      if (iumpHymns.any((h) => !h.isLocalOnly && h.id == explicitIumpId)) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('El himno N° $explicitIumpId ya existe en el Himnario IUMP.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    final existingHymns = ref.read(allHymnsProvider).value ?? [];
    final duplicate = Hymn.findPossibleDuplicate(lyrics, existingHymns);
    if (duplicate != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Posible Duplicado'),
          content: Text(
            'Este canto se parece mucho a "${duplicate.title}" que ya existe en el himnario. ¿Seguro que deseas añadirlo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Añadir de todos modos'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() => _isLoading = true);
    final normalizedTone = Hymn.applyToneMode(_keyCtrl.text, _selectedMode);

    try {
      if (isLocal) {
        await LocalHymnStorageService.saveCustomHymn(
          title.toUpperCase(),
          lyrics,
          _selectedCollection,
          key: normalizedTone,
          beats: _beatsCtrl.text.trim(),
          timeSignature: _timeSigCtrl.text.trim(),
          category: _selectedCategory,
        );
        ref.invalidate(hymnsProvider(_selectedCollection));
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Guardado localmente en tu dispositivo.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else if (isAdmin) {
        final savedId = await ref
            .read(hymnsProvider(_selectedCollection).notifier)
            .publishNewOfficialHymn(
              title: title.toUpperCase(),
              toneNote: normalizedTone,
              beats: _beatsCtrl.text.trim(),
              timeSignature: _timeSigCtrl.text.trim(),
              lyrics: lyrics,
              explicitId: explicitIumpId,
              category: _selectedCategory,
            );
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '¡Publicado directo en ${_collectionLabel(_selectedCollection)} (N° $savedId)!',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        final docRef = await FirebaseFirestore.instance.collection('cantos_sugeridos').add({
          'title': title.toUpperCase(),
          'lyrics': lyrics,
          'collection': _selectedCollection,
          'key': normalizedTone,
          'beats': _beatsCtrl.text.trim(),
          'timeSignature': _timeSigCtrl.text.trim(),
          'category': _selectedCategory,
          'requesterName': requesterName,
          'requesterChurch': requesterChurch,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'type': 'new',
          'source': 'scanner_ia',
        });

        await SuggestionTrackingService.saveRequesterProfile(
          name: requesterName,
          church: requesterChurch,
        );

        await SuggestionTrackingService.saveSubmittedSuggestion(
          SubmittedSuggestion(
            docId: docRef.id,
            title: title.toUpperCase(),
            collection: _selectedCollection,
            requesterName: requesterName,
            requesterChurch: requesterChurch,
            date: DateTime.now(),
            type: 'new',
            source: 'scanner_ia',
            status: 'pending',
          ),
        );

        if (mounted) {
          await _showSuggestionSuccessDialog(
            title: title.toUpperCase(),
            requesterName: requesterName,
            requesterChurch: requesterChurch,
          );
        }
      }
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
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
    final isAdmin = ref.watch(adminModeProvider);
    final categoryItems = Hymn.categoriesForCollection(_selectedCollection);

    return Scaffold(
      appBar: AppBar(
        title: Text('Resultados de IA', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (!isAdmin)
            IconButton(
              icon: const Icon(Icons.mark_email_read_outlined),
              tooltip: 'Mis Sugerencias Enviadas',
              onPressed: () => context.push('/my-suggestions'),
            ),
        ],
      ),
      body: Stack(
        children: [
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
                          isAdmin
                              ? 'Letra procesada con éxito. Revisa la colección destino y publícala directo en la BD oficial.'
                              : 'Letra procesada con éxito. Puedes editar los datos antes de guardar o enviar.',
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
                const SizedBox(height: 20),

                _buildLabel('Colección destino'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCollection,
                  decoration: _buildInputDecoration(theme, isDark),
                  items: _collections
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(_collectionLabel(c)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _selectedCollection = v;
                      _selectedCategory = '';
                      _prefillNextIumpId();
                    });
                  },
                ),
                const SizedBox(height: 16),

                if (isAdmin && _selectedCollection == 'iump') ...[
                  _buildLabel('Número del Himno (IUMP)'),
                  TextFormField(
                    controller: _idCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _buildInputDecoration(theme, isDark),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildLabel('Categoría'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: _buildInputDecoration(theme, isDark),
                  items: categoryItems
                      .map((cat) => DropdownMenuItem<String>(
                            value: cat['id']!,
                            child: Text(cat['name']!, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCategory = v);
                  },
                ),
                const SizedBox(height: 16),

                _buildLabel('Título'),
                TextFormField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18),
                  decoration: _buildInputDecoration(theme, isDark),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Tono (Ej: DO, SOL)'),
                          TextFormField(
                            controller: _keyCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                            decoration: _buildInputDecoration(theme, isDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Modo'),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedMode,
                            decoration: _buildInputDecoration(theme, isDark),
                            items: const [
                              DropdownMenuItem(value: 'Mayor', child: Text('Mayor (M)')),
                              DropdownMenuItem(value: 'Menor', child: Text('Menor (m)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedMode = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Tiempos (Ej: 3)'),
                          TextFormField(
                            controller: _beatsCtrl,
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                            decoration: _buildInputDecoration(theme, isDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Métrica (Ej: 4/4)'),
                          TextFormField(
                            controller: _timeSigCtrl,
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                            decoration: _buildInputDecoration(theme, isDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLabel('Letra y Acordes'),
                    TextButton.icon(
                      icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 18),
                      label: Text(
                        'Pulir Ortografía',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () async {
                        if (_lyricsCtrl.text.trim().isEmpty) return;
                        final res = await GeminiAiService.correctHymnGrammar(
                          context: context,
                          title: _titleCtrl.text.trim(),
                          lyrics: _lyricsCtrl.text.trim(),
                        );
                        if (res != null && mounted) {
                          _titleCtrl.text = res['title']!;
                          _lyricsCtrl.text = res['lyrics']!;
                        }
                      },
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFDFBF7),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),
                ),

                if (!isAdmin) ...[
                  const SizedBox(height: 20),
                  _buildLabel('Datos del Sugeridor (Obligatorios para Sugerir Oficial)'),
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
                    child: Text(
                      'Necesitamos tu nombre y tu iglesia para registrar tu aporte si envías el canto al catálogo oficial (no se exigen para Guardar Local).',
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _buildInputDecoration(theme, isDark).copyWith(
                            labelText: 'Tu Nombre *',
                            hintText: 'Ej: Hno. Juan Pérez',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _churchCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: _buildInputDecoration(theme, isDark).copyWith(
                            labelText: 'Iglesia / Local *',
                            hintText: 'Ej: IUMP Central',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 110),
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
              if (!kIsWeb) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _saveHymn(isLocal: true, isAdmin: isAdmin),
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Guardar Local'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _saveHymn(isLocal: false, isAdmin: isAdmin),
                  icon: Icon(isAdmin ? Icons.publish_rounded : Icons.cloud_upload_rounded),
                  label: Text(isAdmin ? 'Publicar Oficial' : 'Sugerir Oficial'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isAdmin ? const Color(0xFF10B981) : null,
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
          color: Colors.grey[500],
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
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
