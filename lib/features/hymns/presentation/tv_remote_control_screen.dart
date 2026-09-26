import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/hymn.dart';

class TvRemoteControlScreen extends StatefulWidget {
  final Hymn hymn;
  final String roomId;

  const TvRemoteControlScreen({super.key, required this.hymn, required this.roomId});

  @override
  State<TvRemoteControlScreen> createState() => _TvRemoteControlScreenState();
}

class _TvRemoteControlScreenState extends State<TvRemoteControlScreen> {
  int _currentBlockIndex = -1;
  bool _isBlank = false;
  double _fontSize = 64.0;
  String _theme = 'darkPremium';
  late List<String> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = widget.hymn.lyrics.split('\n\n').map((b) {
      final text = b.trim();
      final match = RegExp(r'^(\d+\.|[Cc][Oo][Rr][Oo]:?)\s+').firstMatch(text);
      if (match != null) {
        final prefix = match.group(1)!;
        final rest = text.substring(match.end);
        return '$prefix\n$rest';
      }
      return text;
    }).toList();
    _syncWithTv();
  }

  String? _getActiveHighlight(int index) {
    if (index < 0 || index >= _blocks.length) return null;
    String? currentHighlight;
    for (int i = 0; i <= index; i++) {
      String b = _blocks[i].trim().toLowerCase();
      if (b.startsWith('coro')) {
        currentHighlight = 'CORO';
      } else if (b.startsWith('puente')) {
        currentHighlight = 'PUENTE';
      } else if (b.startsWith('final')) {
        currentHighlight = 'FINAL';
      } else if (RegExp(r'^\d+\.').hasMatch(b) || b.startsWith('est.') || b.startsWith('estrofa')) {
        currentHighlight = null;
      }
    }
    return currentHighlight;
  }

  Future<void> _syncWithTv() async {
    final block = _currentBlockIndex >= 0 && _currentBlockIndex < _blocks.length 
        ? _blocks[_currentBlockIndex] 
        : '';
        
    final title = widget.hymn.collection == 'iump'
        ? '${widget.hymn.id}. ${widget.hymn.title}'
        : widget.hymn.title;
        
    await FirebaseFirestore.instance.collection('tv_rooms').doc(widget.roomId).update({
      'hymnId': widget.hymn.id,
      'hymnTitle': title,
      'currentBlock': block,
      'isChorus': _getActiveHighlight(_currentBlockIndex) != null, // backwards compatibility
      'activeHighlight': _getActiveHighlight(_currentBlockIndex),
      'isBlank': _isBlank,
      'fontSize': _fontSize,
      'theme': _theme,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _nextBlock() {
    if (_currentBlockIndex < _blocks.length - 1) {
      setState(() {
        _currentBlockIndex++;
        _isBlank = false;
      });
      _syncWithTv();
    }
  }

  void _prevBlock() {
    if (_currentBlockIndex > -1) {
      setState(() {
        _currentBlockIndex--;
        _isBlank = false;
      });
      _syncWithTv();
    }
  }

  void _toggleBlank() {
    setState(() {
      _isBlank = !_isBlank;
    });
    _syncWithTv();
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar'),
        content: const Text('¿Deseas desconectar este proyector? La pantalla volverá al código de espera.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desconectar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Clear the screen on TV
    await FirebaseFirestore.instance.collection('tv_rooms').doc(widget.roomId).update({
      'currentBlock': '',
      'hymnTitle': '',
      'isBlank': false,
    });

    // Forget the room on this device
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_tv_room');

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Control Proyector',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Text('A-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: () {
              setState(() => _fontSize = (_fontSize - 4).clamp(32.0, 120.0));
              _syncWithTv();
            },
            tooltip: 'Reducir tamaño',
          ),
          IconButton(
            icon: const Text('A+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            onPressed: () {
              setState(() => _fontSize = (_fontSize + 4).clamp(32.0, 120.0));
              _syncWithTv();
            },
            tooltip: 'Aumentar tamaño',
          ),
          IconButton(
            icon: Icon(_isBlank ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: _toggleBlank,
            tooltip: 'Ocultar/Mostrar texto',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.palette_rounded),
            tooltip: 'Tema visual',
            onSelected: (String theme) {
              setState(() => _theme = theme);
              _syncWithTv();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'darkPremium',
                child: Text('Oscuro Premium (Degradado)'),
              ),
              const PopupMenuItem<String>(
                value: 'vitralChurch',
                child: Text('Vitral Iglesia (Degradado)'),
              ),
              const PopupMenuItem<String>(
                value: 'highContrast',
                child: Text('Alto Contraste (Negro)'),
              ),
              const PopupMenuItem<String>(
                value: 'whiteProjector',
                child: Text('Fondo Blanco'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.connected_tv_rounded, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conectado a Sala',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: subtitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        widget.roomId,
                        style: GoogleFonts.notoSans(
                          fontSize: 16,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _disconnect,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Desconectar', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _blocks.length + 1, // +1 for the Title block
              itemBuilder: (context, i) {
                final index = i - 1; // -1 is Title, 0 is first block
                final isSelected = _currentBlockIndex == index;
                final isTitle = index == -1;
                
                String blockText = isTitle ? 'Portada del Himno' : _blocks[index];
                bool isChorus = !isTitle && _getActiveHighlight(index) != null;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBlockIndex = index;
                      _isBlank = false;
                    });
                    _syncWithTv();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? primaryColor 
                          : (isChorus && !isDark ? const Color(0xFFFEF3C7) : cardBgColor), // Soft yellow for chorus in light mode
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? primaryColor 
                            : (isChorus ? Colors.amber.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black12)),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isTitle)
                          Row(
                            children: [
                              Icon(Icons.slideshow_rounded, 
                                color: isSelected ? Colors.white70 : primaryColor, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'TÍTULO',
                                style: GoogleFonts.notoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white70 : primaryColor,
                                ),
                              ),
                            ],
                          )
                        else if (isChorus)
                          Row(
                            children: [
                              Icon(Icons.star_rounded, 
                                color: isSelected ? Colors.white70 : Colors.amber.shade700, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'CORO',
                                style: GoogleFonts.notoSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white70 : Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: (isTitle || isChorus) ? 8 : 0),
                        Text(
                          isTitle ? widget.hymn.title : blockText,
                          style: GoogleFonts.notoSans(
                            fontSize: isTitle ? 20 : 18,
                            color: isSelected 
                                ? Colors.white 
                                : (isChorus && isDark ? Colors.amber.shade200 : textColor),
                            fontWeight: (isSelected || isTitle) ? FontWeight.bold : FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _currentBlockIndex > -1 ? _prevBlock : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        foregroundColor: textColor,
                        disabledBackgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                        disabledForegroundColor: isDark ? Colors.white30 : Colors.black26,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.arrow_upward_rounded),
                      label: Text('Anterior', style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _currentBlockIndex < _blocks.length - 1 ? _nextBlock : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                        disabledForegroundColor: isDark ? Colors.white30 : Colors.black26,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shadowColor: primaryColor.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.arrow_downward_rounded),
                      label: Text('Siguiente', style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}