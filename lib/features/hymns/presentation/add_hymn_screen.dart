import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:himnario_iump/core/services/local_hymn_storage_service.dart';
import 'package:himnario_iump/features/hymns/domain/hymn.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/chord_transposer_service.dart';
import '../../../core/services/gemini_ai_service.dart';
import '../../../core/services/suggestion_tracking_service.dart';
import 'widgets/hymn_structure_toolbar.dart';
import 'hymn_list_screen.dart';

enum _DuplicateAction {
  viewExisting,
  requestCorrection,
  saveLocalMedley,
  proceedAsNew,
}

class AddHymnScreen extends ConsumerStatefulWidget {
  final String initialCollection;

  const AddHymnScreen({
    super.key,
    this.initialCollection = 'especiales',
  });

  @override
  ConsumerState<AddHymnScreen> createState() => _AddHymnScreenState();
}

class _AddHymnScreenState extends ConsumerState<AddHymnScreen> {
  final _idController = TextEditingController();
  final _titleController = TextEditingController();
  final _lyricsController = TextEditingController();
  final _keyController = TextEditingController();
  final _beatsController = TextEditingController();
  final _timeSignatureController = TextEditingController();
  final _nameController = TextEditingController();
  final _churchController = TextEditingController();

  late String _selectedCollection;
  String _selectedMode = 'Mayor';
  String _selectedCategory = '';
  bool _isLoading = false;

  static const List<String> _collections = ['iump', 'especiales', 'coros'];

  @override
  void initState() {
    super.initState();
    _selectedCollection = _collections.contains(widget.initialCollection)
        ? widget.initialCollection
        : 'especiales';
    _prefillNextIdIfIump();
    _loadSavedRequesterProfile();
  }

  Future<void> _loadSavedRequesterProfile() async {
    final profile = await SuggestionTrackingService.getRequesterProfile();
    if (!mounted) return;
    if (_nameController.text.isEmpty && profile.name.isNotEmpty) {
      _nameController.text = profile.name;
    }
    if (_churchController.text.isEmpty && profile.church.isNotEmpty) {
      _churchController.text = profile.church;
    }
  }

  void _prefillNextIdIfIump() {
    if (_selectedCollection != 'iump') return;
    final list = ref.read(hymnsProvider('iump')).value ?? [];
    final official = list.where((h) => !h.isLocalOnly).toList();
    final nextId = official.isEmpty
        ? 1
        : official.map((h) => h.id).reduce((a, b) => a > b ? a : b) + 1;
    _idController.text = nextId.toString();
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _lyricsController.dispose();
    _keyController.dispose();
    _beatsController.dispose();
    _timeSignatureController.dispose();
    _nameController.dispose();
    _churchController.dispose();
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

  Future<void> _scanText() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Tomar Foto con Cámara'),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir Imagen de la Galería'),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (pickedFile == null || !mounted) return;

    bool progressDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Analizando imagen con Gemini...',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => progressDialogOpen = false);

    try {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final lowerPath = pickedFile.name.toLowerCase();
      String mimeType = 'image/jpeg';
      if (lowerPath.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (lowerPath.endsWith('.webp')) {
        mimeType = 'image/webp';
      } else if (lowerPath.endsWith('.heic')) {
        mimeType = 'image/heic';
      }

      final result = await GeminiAiService.transcribeSheetMusic(
        base64Image,
        mimeType: mimeType,
      );

      if (mounted && progressDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogOpen = false;
      }

      if (!mounted) return;

      if (result != null) {
        final titleVal = result['title']?.toString().trim() ?? '';
        final toneVal = result['key']?.toString().trim() ?? '';
        final timeSigVal = result['timeSignature']?.toString().trim() ?? '';
        final lyricsVal = result['lyrics']?.toString().trim() ?? '';

        setState(() {
          if (titleVal.isNotEmpty && titleVal.toLowerCase() != 'título desconocido') {
            _titleController.text = titleVal.toUpperCase();
          }
          if (toneVal.isNotEmpty && toneVal.toLowerCase() != 'desconocida') {
            final isMinor = toneVal.endsWith('m');
            _selectedMode = isMinor ? 'Menor' : 'Mayor';
            _keyController.text = isMinor
                ? toneVal.substring(0, toneVal.length - 1).toUpperCase()
                : toneVal.toUpperCase();
          }
          if (timeSigVal.isNotEmpty) {
            _timeSignatureController.text = timeSigVal;
          }
          if (lyricsVal.isNotEmpty) {
            _lyricsController.text = lyricsVal;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Texto y estructura cargados con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('No se pudo procesar la imagen (respuesta vacía).');
      }
    } catch (e) {
      if (mounted && progressDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogOpen = false;
      }
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (errCtx) => AlertDialog(
          title: const Text('Error en el escaneo'),
          content: const Text(
            'Los servidores de IA están temporalmente ocupados o hubo un error de conexión.\n\nPor favor, intenta nuevamente en un momento.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(errCtx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<_DuplicateAction?> _showDuplicateChoiceDialog(
    BuildContext context,
    Hymn duplicate,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<_DuplicateAction>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF59E0B), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Coincidencia en el Catálogo',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detectamos partes de la letra similares a un canto existente:',
                  style: GoogleFonts.nunito(fontSize: 13.5, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        duplicate.title,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_collectionLabel(duplicate.collection)} (N° ${duplicate.id})',
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Qué deseas hacer con esta propuesta?',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildChoiceTile(
                  icon: Icons.visibility_rounded,
                  color: const Color(0xFF0EA5E9),
                  title: 'Ver Canto en el Himnario',
                  subtitle: 'Comprueba si la versión oficial ya satisface lo que buscas.',
                  onTap: () => Navigator.pop(dialogCtx, _DuplicateAction.viewExisting),
                ),
                _buildChoiceTile(
                  icon: Icons.auto_fix_high_rounded,
                  color: const Color(0xFF10B981),
                  title: 'Solicitar Corrección / Mejora',
                  subtitle: 'Si el canto existente tiene faltas o está desordenado, envía tu versión para mejorarlo.',
                  onTap: () => Navigator.pop(dialogCtx, _DuplicateAction.requestCorrection),
                ),
                _buildChoiceTile(
                  icon: Icons.library_music_rounded,
                  color: const Color(0xFF8B5CF6),
                  title: 'Es un Medley / Popurrí (Guardar Local)',
                  subtitle: 'Ideal para arreglos propios de tu coro. Se guardará en tu móvil para imprimir y compartir.',
                  onTap: () => Navigator.pop(dialogCtx, _DuplicateAction.saveLocalMedley),
                ),
                _buildChoiceTile(
                  icon: Icons.add_circle_outline_rounded,
                  color: const Color(0xFFF59E0B),
                  title: 'Es un Canto Nuevo Diferente',
                  subtitle: 'Enviar como sugerencia de canto independiente al catálogo oficial.',
                  onTap: () => Navigator.pop(dialogCtx, _DuplicateAction.proceedAsNew),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, null),
              child: Text('Cancelar', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChoiceTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 11.5,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSuggestionSuccessDialog(
    BuildContext context, {
    required bool isNewSong,
    required String title,
    required String requesterName,
    required String requesterChurch,
    required bool isCorrection,
    String? targetTitle,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isCorrection ? '¡Corrección Enviada!' : '¡Sugerencia Enviada!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNewSong)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este canto no existe actualmente en el catálogo oficial.',
                          style: GoogleFonts.nunito(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                isCorrection
                    ? 'Tu propuesta de mejora para "$targetTitle" ha sido recibida con éxito junto a tus datos ($requesterName de $requesterChurch).\n\nEl administrador revisará los cambios para dejar el canto impecable en la base de datos oficial próximamente.'
                    : 'Tu sugerencia de "$title" ha sido recibida con éxito junto a tus datos ($requesterName de $requesterChurch).\n\nEl administrador revisará la letra, la ordenará y la incorporará al catálogo oficial próximamente.\n\n¡Muchas gracias por tu valioso aporte!',
                style: GoogleFonts.nunito(fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                '💡 Podrás seguir el estado de esta sugerencia en "Herramientas > Mis Sugerencias al Catálogo".',
                style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
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

  Future<void> _saveHymn({required bool isLocal, required bool isAdmin}) async {
    final title = _titleController.text.trim();
    final lyrics = ChordTransposerService.normalizeLyrics(_lyricsController.text.trim());
    final messenger = ScaffoldMessenger.of(context);

    if (title.isEmpty || lyrics.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa título y letra')),
      );
      return;
    }

    final requesterName = _nameController.text.trim();
    final requesterChurch = _churchController.text.trim();

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
      explicitIumpId = int.tryParse(_idController.text.trim());
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

    String suggestionType = 'new';
    int? targetHymnId;
    String? targetHymnTitle;
    String? targetHymnCollection;
    String? correctionReason;

    final existingHymns = ref.read(allHymnsProvider).value ?? [];
    final duplicate = Hymn.findPossibleDuplicate(lyrics, existingHymns);
    if (duplicate != null) {
      final action = await _showDuplicateChoiceDialog(context, duplicate);
      if (action == null) return; // Canceló el diálogo

      if (action == _DuplicateAction.viewExisting) {
        if (!mounted) return;
        context.push('/hymn-view/${duplicate.collection}-${duplicate.id}');
        return;
      } else if (action == _DuplicateAction.saveLocalMedley) {
        isLocal = true;
      } else if (action == _DuplicateAction.requestCorrection) {
        suggestionType = 'correction';
        targetHymnId = duplicate.id;
        targetHymnTitle = duplicate.title;
        targetHymnCollection = duplicate.collection;
        correctionReason = 'Solicitud de corrección y ordenamiento de letra';
      } else if (action == _DuplicateAction.proceedAsNew) {
        suggestionType = 'new';
      }
    }

    setState(() => _isLoading = true);
    final normalizedTone = Hymn.applyToneMode(_keyController.text, _selectedMode);

    try {
      if (isLocal) {
        await LocalHymnStorageService.saveCustomHymn(
          title.toUpperCase(),
          lyrics,
          _selectedCollection,
          key: normalizedTone,
          beats: _beatsController.text.trim(),
          timeSignature: _timeSignatureController.text.trim(),
          category: _selectedCategory,
        );
        ref.invalidate(hymnsProvider(_selectedCollection));
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Canto guardado localmente en tu dispositivo.'),
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
              beats: _beatsController.text.trim(),
              timeSignature: _timeSignatureController.text.trim(),
              lyrics: lyrics,
              explicitId: explicitIumpId,
              category: _selectedCategory,
            );
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '¡Publicado en ${_collectionLabel(_selectedCollection)} (N° $savedId)!',
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
          'beats': _beatsController.text.trim(),
          'timeSignature': _timeSignatureController.text.trim(),
          'category': _selectedCategory,
          'requesterName': requesterName,
          'requesterChurch': requesterChurch,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'type': suggestionType,
          'source': 'manual',
          'targetHymnId': targetHymnId,
          'targetTitle': targetHymnTitle,
          'targetCollection': targetHymnCollection,
          'reason': correctionReason,
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
            type: suggestionType,
            source: 'manual',
            targetHymnId: targetHymnId,
            targetTitle: targetHymnTitle,
            reason: correctionReason,
            status: 'pending',
          ),
        );

        if (mounted) {
          await _showSuggestionSuccessDialog(
            context,
            isNewSong: duplicate == null,
            title: title.toUpperCase(),
            requesterName: requesterName,
            requesterChurch: requesterChurch,
            isCorrection: suggestionType == 'correction',
            targetTitle: targetHymnTitle,
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al guardar el canto: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = ref.watch(adminModeProvider);
    final backgroundColor = isDark ? const Color(0xFF0F172A) : Colors.grey[50];
    final categoryItems = Hymn.categoriesForCollection(_selectedCollection);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          isAdmin ? 'Publicar Nuevo Canto' : 'Añadir Canto',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!isAdmin)
            IconButton(
              icon: const Icon(Icons.mark_email_read_outlined),
              tooltip: 'Mis Sugerencias Enviadas',
              onPressed: () => context.push('/my-suggestions'),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 140.0),
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
                      initialValue: _selectedCollection,
                      decoration: InputDecoration(
                        labelText: 'Colección / Contenedor',
                        prefixIcon: const Icon(Icons.folder_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      ),
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
                          _prefillNextIdIfIump();
                        });
                      },
                    ),
                    if (isAdmin && _selectedCollection == 'iump') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _idController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Número del Himno (IUMP)',
                          prefixIcon: const Icon(Icons.tag_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                        ),
                      ),
                    ],
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      ),
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _keyController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Tono (Ej: DO, SOL)',
                              prefixIcon: const Icon(Icons.piano),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedMode,
                            decoration: InputDecoration(
                              labelText: 'Modo',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Mayor', child: Text('Mayor (M)')),
                              DropdownMenuItem(value: 'Menor', child: Text('Menor (m)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedMode = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _beatsController,
                            decoration: InputDecoration(
                              labelText: 'Tiempos (Ej: 3)',
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

            // CARD 3: LETRA (Layout limpio sin Row anidada con Expanded no acotado)
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
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Letra del Canto',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.travel_explore_rounded, color: Colors.blueAccent),
                          tooltip: 'Buscar Letra en Internet (IA)',
                          onPressed: () => _searchLyricsWithAI(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
                          tooltip: 'Mejorar Ortografía y Puntuación con IA',
                          onPressed: () async {
                            if (_lyricsController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ingresa la letra antes de pulir con IA'),
                                ),
                              );
                              return;
                            }
                            final result = await GeminiAiService.correctHymnGrammar(
                              context: context,
                              title: _titleController.text.trim(),
                              lyrics: _lyricsController.text.trim(),
                            );
                            if (result != null && mounted) {
                              _titleController.text = result['title']!;
                              _lyricsController.text = result['lyrics']!;
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.document_scanner),
                          tooltip: 'Escanear Foto con IA',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          onPressed: _scanText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    HymnStructureToolbar(
                      controller: _lyricsController,
                      onChanged: () => setState(() {}),
                    ),
                    TextField(
                      controller: _lyricsController,
                      minLines: 12,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
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

            // CARD 4: DATOS DEL SUGERIDOR (Solo visible para usuarios no administradores)
            if (!isAdmin) ...[
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E293B) : Colors.blueGrey[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.blueGrey[800]! : Colors.blueGrey[200]!,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Datos del Sugeridor', Icons.person_outline),
                      Text(
                        'Requerido para sugerencias al catálogo oficial. El administrador sabrá quién realizó el aporte.',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Tu Nombre *',
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
                                labelText: 'Iglesia/Local *',
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
            ] else
              const SizedBox(height: 16),

            // BOTONES DE ACCIÓN
            Row(
              children: [
                if (!kIsWeb) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _saveHymn(isLocal: true, isAdmin: isAdmin),
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Guardar Local'),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isAdmin ? const Color(0xFF10B981) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => _saveHymn(isLocal: false, isAdmin: isAdmin),
                    icon: Icon(isAdmin ? Icons.publish_rounded : Icons.cloud_upload),
                    label: Text(isAdmin ? 'Publicar Oficial' : 'Sugerir Oficial'),
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
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) => OnlineSearchDialog(
        initialQuery: title,
        returnResults: true,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (result['title'] != null && result['title'].toString().isNotEmpty) {
          _titleController.text = result['title'].toString().toUpperCase();
        }
        if (result['lyrics'] != null && result['lyrics'].toString().isNotEmpty) {
          _lyricsController.text = result['lyrics'].toString();
        }
        if (result['key'] != null && result['key'].toString().isNotEmpty) {
          final k = result['key'].toString().trim();
          final isMinor = k.endsWith('m');
          _selectedMode = isMinor ? 'Menor' : 'Mayor';
          _keyController.text = isMinor
              ? k.substring(0, k.length - 1).toUpperCase()
              : k.toUpperCase();
        }
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Datos importados exitosamente.')),
      );
    }
  }
}
