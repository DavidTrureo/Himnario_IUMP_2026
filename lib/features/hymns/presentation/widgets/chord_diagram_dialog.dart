import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChordDiagramDialog extends StatelessWidget {
  final String chordName;

  const ChordDiagramDialog({super.key, required this.chordName});

  static void show(BuildContext context, String chordName) {
    showDialog(
      context: context,
      builder: (context) => ChordDiagramDialog(chordName: chordName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final chordData = ChordParser.parse(chordName);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      elevation: 16,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(22.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado del Acorde (Badge + Nombre Completo + Cerrar)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber[600]!,
                              Colors.amber[800]!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          chordName,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          chordData.fullName,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white60 : Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
            const SizedBox(height: 16),

            // Selector Tab / Vistas (Guitarra & Piano)
            DefaultTabController(
              length: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      labelColor: Colors.black,
                      unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Colors.amber[500],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      dividerColor: Colors.transparent,
                      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.music_note_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Guitarra'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.piano_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Piano'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 230,
                    child: TabBarView(
                      children: [
                        // Vista Mástil Guitarra
                        Center(
                          child: CustomPaint(
                            size: const Size(200, 210),
                            painter: GuitarFretboardPainter(
                              frets: chordData.guitarFrets,
                              fingers: chordData.guitarFingers,
                              baseFret: chordData.baseFret,
                              isDark: isDark,
                              accentColor: Colors.amber[500]!,
                            ),
                          ),
                        ),

                        // Vista Teclado Piano
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(300, 140),
                                painter: PianoKeyboardPainter(
                                  activeKeys: chordData.pianoKeys,
                                  isDark: isDark,
                                  accentColor: Colors.amber[500]!,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Notas: ${chordData.notes.join(' - ')}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.amber[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChordInfoData {
  final String fullName;
  final List<String> notes;
  final List<int> guitarFrets; // -1 mutada, 0 al aire, 1+ traste
  final List<int> guitarFingers;
  final List<int> pianoKeys; // Índices de 0 a 11 en octava
  final int baseFret;

  const ChordInfoData(
    this.fullName,
    this.notes,
    this.guitarFrets,
    this.guitarFingers,
    this.pianoKeys, {
    this.baseFret = 1,
  });
}

class ChordParser {
  static const List<String> spanishScale = [
    'DO', 'DO#', 'RE', 'RE#', 'MI', 'FA', 'FA#', 'SOL', 'SOL#', 'LA', 'LA#', 'SI'
  ];

  static const Map<String, int> _noteIndexMap = {
    'DO#': 1, 'C#': 1, 'REB': 1, 'DB': 1,
    'DO': 0, 'C': 0,
    'RE#': 3, 'D#': 3, 'MIB': 3, 'EB': 3,
    'RE': 2, 'D': 2,
    'MI': 4, 'E': 4,
    'FA#': 6, 'F#': 6, 'SOLB': 6, 'GB': 6,
    'FA': 5, 'F': 5,
    'SOL#': 8, 'G#': 8, 'LAB': 8, 'AB': 8,
    'SOL': 7, 'G': 7,
    'LA#': 10, 'A#': 10, 'SIB': 10, 'BB': 10,
    'LA': 9, 'A': 9,
    'SI': 11, 'B': 11,
  };

  static int _getNoteIndex(String note) {
    final clean = note.trim().toUpperCase();
    if (_noteIndexMap.containsKey(clean)) {
      return _noteIndexMap[clean]!;
    }
    // Si contiene notas con sufijos (ej: D7, Dm, C#m7)
    for (final entry in _noteIndexMap.entries) {
      if (clean.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return 0;
  }

  static String _getSpanishNoteName(int index) {
    return spanishScale[index % 12];
  }

  static ChordInfoData parse(String rawChord) {
    final clean = rawChord.trim().replaceAll(RegExp(r'\[|\]'), '');
    if (clean.isEmpty) {
      return const ChordInfoData('Do Mayor', ['DO', 'MI', 'SOL'], [-1, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0], [0, 4, 7]);
    }

    String mainChord = clean;
    String bassNote = '';
    if (clean.contains('/')) {
      final parts = clean.split('/');
      mainChord = parts[0].trim();
      bassNote = parts.sublist(1).join('/').trim();
    }

    // Identificar tónica (Root)
    final rootMatch = RegExp(r'^(DO#|DO|RE#|REb|RE|MIB|MI|FA#|FA|SOL#|SOLB|SOL|LAB|LA#|LAb|LA|SIB|SI|C#|Db|C|D#|Eb|D|E|F#|F|G#|Ab|G|A#|Bb|A|B)', caseSensitive: false)
      .firstMatch(mainChord);

    String rootStr = 'C';
    String suffix = '';
    if (rootMatch != null) {
      rootStr = rootMatch.group(1)!;
      suffix = mainChord.substring(rootMatch.end).trim();
    } else {
      rootStr = mainChord;
    }

    final rootIndex = _getNoteIndex(rootStr);
    final bassIndex = bassNote.isNotEmpty ? _getNoteIndex(bassNote) : -1;

    // Sufijos y cualidades
    final lowerSuffix = suffix.toLowerCase();
    bool isMinor = lowerSuffix.startsWith('m') && !lowerSuffix.startsWith('maj');
    bool isDim = lowerSuffix.contains('dim') || lowerSuffix.contains('m7(b5)') || lowerSuffix.contains('m7b5');
    bool isAug = lowerSuffix.contains('aug');
    bool isSus4 = lowerSuffix.contains('sus4');
    bool isSus2 = lowerSuffix.contains('sus2');
    bool hasAdd9 = lowerSuffix.contains('add9') || lowerSuffix.contains('9');
    bool has7 = lowerSuffix.contains('7') && !lowerSuffix.contains('maj7');
    bool hasMaj7 = lowerSuffix.contains('maj7');
    bool is5 = lowerSuffix == '5';

    final List<int> intervals = [0];

    if (is5) {
      intervals.add(7);
    } else if (isSus4) {
      intervals.addAll([5, 7]);
    } else if (isSus2) {
      intervals.addAll([2, 7]);
    } else if (isDim) {
      intervals.addAll([3, 6]);
      if (has7 || lowerSuffix.contains('b5')) intervals.add(10);
    } else if (isAug) {
      intervals.addAll([4, 8]);
    } else if (isMinor) {
      intervals.addAll([3, 7]);
      if (has7) intervals.add(10);
      if (hasMaj7) intervals.add(11);
    } else {
      intervals.addAll([4, 7]);
      if (has7) intervals.add(10);
      if (hasMaj7) intervals.add(11);
    }

    if (hasAdd9) {
      intervals.add(2);
    }

    final List<int> pianoKeys = intervals.map((i) => (rootIndex + i) % 12).toSet().toList();
    if (bassIndex != -1 && !pianoKeys.contains(bassIndex)) {
      pianoKeys.insert(0, bassIndex);
    }

    final List<String> notes = pianoKeys.map((idx) => _getSpanishNoteName(idx)).toList();
    final String fullName = _buildFullName(rootStr, suffix, bassNote);

    final guitarData = _getGuitarPosition(clean, rootStr, suffix, bassNote, rootIndex);

    return ChordInfoData(
      fullName,
      notes,
      guitarData.frets,
      guitarData.fingers,
      pianoKeys,
      baseFret: guitarData.baseFret,
    );
  }

  static String _buildFullName(String root, String suffix, String bass) {
    final rootSpan = _getSpanishNoteName(_getNoteIndex(root));
    final lower = suffix.toLowerCase();

    String quality = 'Mayor';
    if (lower.startsWith('m7(b5)') || lower.startsWith('m7b5')) {
      quality = 'Menor 7 Semidisminuido';
    } else if (lower.startsWith('m7')) {
      quality = 'Menor 7ª';
    } else if (lower.startsWith('m')) {
      quality = 'Menor';
    } else if (lower.contains('maj7')) {
      quality = 'Mayor 7ª (Maj7)';
    } else if (lower.contains('7')) {
      quality = 'Dominante 7ª';
    } else if (lower.contains('add9')) {
      quality = 'con Novena (Add9)';
    } else if (lower.contains('sus4')) {
      quality = 'Suspendido 4ª (Sus4)';
    } else if (lower.contains('sus2')) {
      quality = 'Suspendido 2ª (Sus2)';
    } else if (lower.contains('dim')) {
      quality = 'Disminuido';
    } else if (lower.contains('aug')) {
      quality = 'Aumentado';
    }

    if (bass.isNotEmpty) {
      final bassSpan = _getSpanishNoteName(_getNoteIndex(bass));
      return '$rootSpan $quality con Bajo en $bassSpan';
    }

    return '$rootSpan $quality';
  }

  static _GuitarPos _getGuitarPosition(String fullChord, String root, String suffix, String bass, int rootIndex) {
    final clean = fullChord.trim().toUpperCase();

    // Diccionario de acordes comunes y compuestos específicos
    final Map<String, _GuitarPos> dictionary = {
      // DO / C
      'C': const _GuitarPos([-1, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0]),
      'DO': const _GuitarPos([-1, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0]),
      'CM': const _GuitarPos([-1, 3, 5, 5, 4, 3], [0, 1, 3, 4, 2, 1], baseFret: 3),
      'DOM': const _GuitarPos([-1, 3, 5, 5, 4, 3], [0, 1, 3, 4, 2, 1], baseFret: 3),
      'CADD9': const _GuitarPos([-1, 3, 2, 0, 3, 0], [0, 2, 1, 0, 3, 0]),
      'DOADD9': const _GuitarPos([-1, 3, 2, 0, 3, 0], [0, 2, 1, 0, 3, 0]),
      'CSUS4': const _GuitarPos([-1, 3, 3, 0, 1, 1], [0, 3, 4, 0, 1, 1]),
      'DOSUS4': const _GuitarPos([-1, 3, 3, 0, 1, 1], [0, 3, 4, 0, 1, 1]),
      'CSUS2': const _GuitarPos([-1, 3, 0, 0, 1, 0], [0, 3, 0, 0, 1, 0]),
      'DOSUS2': const _GuitarPos([-1, 3, 0, 0, 1, 0], [0, 3, 0, 0, 1, 0]),
      'C7': const _GuitarPos([-1, 3, 2, 3, 1, 0], [0, 3, 2, 4, 1, 0]),
      'DO7': const _GuitarPos([-1, 3, 2, 3, 1, 0], [0, 3, 2, 4, 1, 0]),
      'CMAJ7': const _GuitarPos([-1, 3, 2, 0, 0, 0], [0, 3, 2, 0, 0, 0]),
      'DOMAJ7': const _GuitarPos([-1, 3, 2, 0, 0, 0], [0, 3, 2, 0, 0, 0]),
      'C/E': const _GuitarPos([0, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0]),
      'DO/MI': const _GuitarPos([0, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0]),
      'C/G': const _GuitarPos([3, 3, 2, 0, 1, 0], [3, 4, 2, 0, 1, 0]),
      'DO/SOL': const _GuitarPos([3, 3, 2, 0, 1, 0], [3, 4, 2, 0, 1, 0]),

      // RE / D
      'D': const _GuitarPos([-1, -1, 0, 2, 3, 2], [0, 0, 0, 1, 3, 2]),
      'RE': const _GuitarPos([-1, -1, 0, 2, 3, 2], [0, 0, 0, 1, 3, 2]),
      'DM': const _GuitarPos([-1, -1, 0, 2, 3, 1], [0, 0, 0, 2, 3, 1]),
      'REM': const _GuitarPos([-1, -1, 0, 2, 3, 1], [0, 0, 0, 2, 3, 1]),
      'DADD9': const _GuitarPos([-1, -1, 0, 2, 3, 0], [0, 0, 0, 1, 2, 0]),
      'READD9': const _GuitarPos([-1, -1, 0, 2, 3, 0], [0, 0, 0, 1, 2, 0]),
      'DSUS4': const _GuitarPos([-1, -1, 0, 2, 3, 3], [0, 0, 0, 1, 2, 3]),
      'RESUS4': const _GuitarPos([-1, -1, 0, 2, 3, 3], [0, 0, 0, 1, 2, 3]),
      'DSUS2': const _GuitarPos([-1, -1, 0, 2, 3, 0], [0, 0, 0, 1, 2, 0]),
      'RESUS2': const _GuitarPos([-1, -1, 0, 2, 3, 0], [0, 0, 0, 1, 2, 0]),
      'D7': const _GuitarPos([-1, -1, 0, 2, 1, 2], [0, 0, 0, 2, 1, 3]),
      'RE7': const _GuitarPos([-1, -1, 0, 2, 1, 2], [0, 0, 0, 2, 1, 3]),
      'D/F#': const _GuitarPos([2, 0, 0, 2, 3, 2], [1, 0, 0, 2, 4, 3]),
      'RE/FA#': const _GuitarPos([2, 0, 0, 2, 3, 2], [1, 0, 0, 2, 4, 3]),

      // MI / E
      'E': const _GuitarPos([0, 2, 2, 1, 0, 0], [0, 2, 3, 1, 0, 0]),
      'MI': const _GuitarPos([0, 2, 2, 1, 0, 0], [0, 2, 3, 1, 0, 0]),
      'EM': const _GuitarPos([0, 2, 2, 0, 0, 0], [0, 2, 3, 0, 0, 0]),
      'MIM': const _GuitarPos([0, 2, 2, 0, 0, 0], [0, 2, 3, 0, 0, 0]),
      'E7': const _GuitarPos([0, 2, 0, 1, 0, 0], [0, 2, 0, 1, 0, 0]),
      'MI7': const _GuitarPos([0, 2, 0, 1, 0, 0], [0, 2, 0, 1, 0, 0]),
      'ESUS4': const _GuitarPos([0, 2, 2, 2, 0, 0], [0, 1, 2, 3, 0, 0]),
      'MISUS4': const _GuitarPos([0, 2, 2, 2, 0, 0], [0, 1, 2, 3, 0, 0]),

      // FA / F
      'F': const _GuitarPos([1, 3, 3, 2, 1, 1], [1, 3, 4, 2, 1, 1]),
      'FA': const _GuitarPos([1, 3, 3, 2, 1, 1], [1, 3, 4, 2, 1, 1]),
      'FM': const _GuitarPos([1, 3, 3, 1, 1, 1], [1, 3, 4, 1, 1, 1]),
      'FAM': const _GuitarPos([1, 3, 3, 1, 1, 1], [1, 3, 4, 1, 1, 1]),
      'F#M': const _GuitarPos([2, 4, 4, 2, 2, 2], [1, 3, 4, 1, 1, 1]),
      'FA#M': const _GuitarPos([2, 4, 4, 2, 2, 2], [1, 3, 4, 1, 1, 1]),

      // SOL / G
      'G': const _GuitarPos([3, 2, 0, 0, 0, 3], [2, 1, 0, 0, 0, 3]),
      'SOL': const _GuitarPos([3, 2, 0, 0, 0, 3], [2, 1, 0, 0, 0, 3]),
      'GM': const _GuitarPos([3, 5, 5, 3, 3, 3], [1, 3, 4, 1, 1, 1], baseFret: 3),
      'SOLM': const _GuitarPos([3, 5, 5, 3, 3, 3], [1, 3, 4, 1, 1, 1], baseFret: 3),
      'G7': const _GuitarPos([3, 2, 0, 0, 0, 1], [3, 2, 0, 0, 0, 1]),
      'SOL7': const _GuitarPos([3, 2, 0, 0, 0, 1], [3, 2, 0, 0, 0, 1]),
      'GSUS4': const _GuitarPos([3, 3, 0, 0, 1, 3], [2, 3, 0, 0, 1, 4]),
      'SOLSUS4': const _GuitarPos([3, 3, 0, 0, 1, 3], [2, 3, 0, 0, 1, 4]),
      'G/B': const _GuitarPos([-1, 2, 0, 0, 0, 3], [0, 1, 0, 0, 0, 2]),
      'SOL/SI': const _GuitarPos([-1, 2, 0, 0, 0, 3], [0, 1, 0, 0, 0, 2]),

      // LA / A
      'A': const _GuitarPos([-1, 0, 2, 2, 2, 0], [0, 0, 1, 2, 3, 0]),
      'LA': const _GuitarPos([-1, 0, 2, 2, 2, 0], [0, 0, 1, 2, 3, 0]),
      'AM': const _GuitarPos([-1, 0, 2, 2, 1, 0], [0, 0, 2, 3, 1, 0]),
      'LAM': const _GuitarPos([-1, 0, 2, 2, 1, 0], [0, 0, 2, 3, 1, 0]),
      'A7': const _GuitarPos([-1, 0, 2, 0, 2, 0], [0, 0, 1, 0, 2, 0]),
      'LA7': const _GuitarPos([-1, 0, 2, 0, 2, 0], [0, 0, 1, 0, 2, 0]),
      'AM7': const _GuitarPos([-1, 0, 2, 0, 1, 0], [0, 0, 2, 0, 1, 0]),
      'LAM7': const _GuitarPos([-1, 0, 2, 0, 1, 0], [0, 0, 2, 0, 1, 0]),
      'AADD9': const _GuitarPos([-1, 0, 2, 2, 0, 0], [0, 0, 1, 2, 0, 0]),
      'LAADD9': const _GuitarPos([-1, 0, 2, 2, 0, 0], [0, 0, 1, 2, 0, 0]),
      'AM/G': const _GuitarPos([3, 0, 2, 2, 1, 0], [3, 0, 2, 4, 1, 0]),
      'LAM/SOL': const _GuitarPos([3, 0, 2, 2, 1, 0], [3, 0, 2, 4, 1, 0]),

      // SI / B
      'B': const _GuitarPos([-1, 2, 4, 4, 4, 2], [0, 1, 2, 3, 4, 1], baseFret: 2),
      'SI': const _GuitarPos([-1, 2, 4, 4, 4, 2], [0, 1, 2, 3, 4, 1], baseFret: 2),
      'BM': const _GuitarPos([-1, 2, 4, 4, 3, 2], [0, 1, 3, 4, 2, 1], baseFret: 2),
      'SIM': const _GuitarPos([-1, 2, 4, 4, 3, 2], [0, 1, 3, 4, 2, 1], baseFret: 2),
      'B7': const _GuitarPos([-1, 2, 1, 2, 0, 2], [0, 2, 1, 3, 0, 4]),
      'SI7': const _GuitarPos([-1, 2, 1, 2, 0, 2], [0, 2, 1, 3, 0, 4]),
      // Acordes Semidisminuidos (m7b5) y Disminuidos (dim)
      'CM7(B5)': const _GuitarPos([-1, 3, 4, 3, 4, -1], [0, 1, 3, 2, 4, 0]),
      'DOM7(B5)': const _GuitarPos([-1, 3, 4, 3, 4, -1], [0, 1, 3, 2, 4, 0]),
      'CM7B5': const _GuitarPos([-1, 3, 4, 3, 4, -1], [0, 1, 3, 2, 4, 0]),
      'DOM7B5': const _GuitarPos([-1, 3, 4, 3, 4, -1], [0, 1, 3, 2, 4, 0]),
      'CDIM': const _GuitarPos([-1, 3, 4, 2, 4, -1], [0, 2, 3, 1, 4, 0]),
      'DODIM': const _GuitarPos([-1, 3, 4, 2, 4, -1], [0, 2, 3, 1, 4, 0]),

      'C#M7(B5)': const _GuitarPos([-1, 4, 5, 4, 5, -1], [0, 1, 3, 2, 4, 0]),
      'DO#M7(B5)': const _GuitarPos([-1, 4, 5, 4, 5, -1], [0, 1, 3, 2, 4, 0]),

      'DM7(B5)': const _GuitarPos([-1, 5, 6, 5, 6, -1], [0, 1, 3, 2, 4, 0]),
      'REM7(B5)': const _GuitarPos([-1, 5, 6, 5, 6, -1], [0, 1, 3, 2, 4, 0]),

      'EM7(B5)': const _GuitarPos([0, 1, 0, 0, 0, 0], [0, 1, 0, 0, 0, 0]),
      'MIM7(B5)': const _GuitarPos([0, 1, 0, 0, 0, 0], [0, 1, 0, 0, 0, 0]),

      'F#M7(B5)': const _GuitarPos([2, -1, 2, 2, 1, -1], [2, 0, 3, 4, 1, 0]),
      'FA#M7(B5)': const _GuitarPos([2, -1, 2, 2, 1, -1], [2, 0, 3, 4, 1, 0]),

      'GM7(B5)': const _GuitarPos([3, -1, 3, 3, 2, -1], [2, 0, 3, 4, 1, 0]),
      'SOLM7(B5)': const _GuitarPos([3, -1, 3, 3, 2, -1], [2, 0, 3, 4, 1, 0]),

      'AM7(B5)': const _GuitarPos([-1, 0, 1, 0, 1, 0], [0, 0, 1, 0, 2, 0]),
      'LAM7(B5)': const _GuitarPos([-1, 0, 1, 0, 1, 0], [0, 0, 1, 0, 2, 0]),

      'BM7(B5)': const _GuitarPos([-1, 2, 3, 2, 3, -1], [0, 1, 3, 2, 4, 0]),
      'SIM7(B5)': const _GuitarPos([-1, 2, 3, 2, 3, -1], [0, 1, 3, 2, 4, 0]),
    };

    if (dictionary.containsKey(clean)) {
      return dictionary[clean]!;
    }

    // Si no está exacto en el diccionario, usar transposición algorítmica por cejuela inteligente
    final bool isHalfDim = suffix.toLowerCase().contains('m7(b5)') || suffix.toLowerCase().contains('m7b5');
    final bool isMinor = suffix.toLowerCase().startsWith('m');
    
    List<int> basePatternFrets = isMinor ? [-1, 1, 3, 3, 2, 1] : [-1, 1, 3, 3, 3, 1];
    List<int> basePatternFingers = isMinor ? [0, 1, 3, 4, 2, 1] : [0, 1, 2, 3, 4, 1];
    if (isHalfDim) {
      basePatternFrets = [-1, 1, 2, 1, 2, -1];
      basePatternFingers = [0, 1, 3, 2, 4, 0];
    }

    final int fretOffset = (rootIndex + 3) % 12;
    final int finalBaseFret = fretOffset == 0 ? 12 : fretOffset;
    final int shift = finalBaseFret - 1;

    final absoluteFrets = basePatternFrets.map((f) => (f == -1 || f == 0) ? f : f + shift).toList();

    return _GuitarPos(absoluteFrets, basePatternFingers, baseFret: finalBaseFret);
  }
}

class _GuitarPos {
  final List<int> frets;
  final List<int> fingers;
  final int baseFret;

  const _GuitarPos(this.frets, this.fingers, {this.baseFret = 1});
}

class GuitarFretboardPainter extends CustomPainter {
  final List<int> frets;
  final List<int> fingers;
  final int baseFret;
  final bool isDark;
  final Color accentColor;

  GuitarFretboardPainter({
    required this.frets,
    required this.fingers,
    required this.baseFret,
    required this.isDark,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int stringsCount = 6;
    const int fretsCount = 5;

    final double topMargin = 30.0;
    final double stringSpacing = size.width / (stringsCount - 1);
    final double fretSpacing = (size.height - topMargin) / fretsCount;

    // Fondo Mástil Madera Oscura Elegante
    final woodRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-8, topMargin - 4, size.width + 16, size.height - topMargin + 8),
      const Radius.circular(10),
    );
    final woodPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFF334155);
    canvas.drawRRect(woodRect, woodPaint);

    // Cejuela Superior Metálica / Marfil
    final nutPaint = Paint()
      ..color = baseFret == 1 ? (isDark ? Colors.amber[300]! : Colors.amber[400]!) : Colors.grey[400]!
      ..strokeWidth = 5.0;
    canvas.drawLine(Offset(0, topMargin), Offset(size.width, topMargin), nutPaint);

    // Trastes Plata
    final fretPaint = Paint()
      ..color = isDark ? Colors.white38 : Colors.white60
      ..strokeWidth = 1.5;

    for (int i = 1; i <= fretsCount; i++) {
      final y = topMargin + i * fretSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fretPaint);
    }

    // Número de Traste Base (Cejuela desplazada)
    if (baseFret > 1) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$baseFretª',
          style: GoogleFonts.outfit(
            color: Colors.amber[400],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(-24, topMargin + fretSpacing / 2 - 6));
    }

    // Cuerdas con grosor variable (Cuerda 6 E baja es gruesa, cuerda 1 E alta es delgada)
    for (int i = 0; i < stringsCount; i++) {
      final x = i * stringSpacing;
      final stringThickness = 2.4 - (i * 0.3); // De 2.4px a 0.9px
      final stringPaint = Paint()
        ..color = isDark ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = stringThickness;

      canvas.drawLine(Offset(x, topMargin), Offset(x, size.height), stringPaint);

      final fret = frets[i];
      final textPainter = TextPainter(textDirection: TextDirection.ltr);

      if (fret == -1) {
        // Cuerda Silenciada (X roja)
        textPainter.text = TextSpan(
          text: 'X',
          style: GoogleFonts.outfit(color: Colors.redAccent[200], fontWeight: FontWeight.w900, fontSize: 13),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, 6));
      } else if (fret == 0) {
        // Cuerda al aire (O verde)
        textPainter.text = TextSpan(
          text: 'O',
          style: GoogleFonts.outfit(color: Colors.greenAccent[400] ?? Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 13),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, 6));
      } else {
        // Punto Neón sobre el traste
        final displayFret = (baseFret > 1) ? (fret - baseFret + 1) : fret;
        final cy = topMargin + (displayFret - 0.5) * fretSpacing;

        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(x, cy), 12, glowPaint);

        final dotPaint = Paint()..color = accentColor;
        canvas.drawCircle(Offset(x, cy), 10, dotPaint);

        final fingerNum = fingers[i];
        if (fingerNum > 0) {
          textPainter.text = TextSpan(
            text: '$fingerNum',
            style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(x - textPainter.width / 2, cy - textPainter.height / 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PianoKeyboardPainter extends CustomPainter {
  final List<int> activeKeys;
  final bool isDark;
  final Color accentColor;

  PianoKeyboardPainter({
    required this.activeKeys,
    required this.isDark,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int whiteKeyCount = 7; // DO, RE, MI, FA, SOL, LA, SI
    final double keyWidth = size.width / whiteKeyCount;

    final whiteKeyPaint = Paint()
      ..color = isDark ? const Color(0xFFF8FAFC) : Colors.white
      ..style = PaintingStyle.fill;

    final whiteBorderPaint = Paint()
      ..color = isDark ? Colors.black45 : Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final blackKeyPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final activeKeyPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final List<int> whiteKeyNotes = [0, 2, 4, 5, 7, 9, 11];

    // Dibujar Teclas Blancas
    for (int i = 0; i < whiteKeyCount; i++) {
      final x = i * keyWidth;
      final noteVal = whiteKeyNotes[i];
      final isPressed = activeKeys.contains(noteVal);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 1, 0, keyWidth - 2, size.height),
        const Radius.circular(6),
      );

      canvas.drawRRect(rrect, isPressed ? activeKeyPaint : whiteKeyPaint);
      canvas.drawRRect(rrect, whiteBorderPaint);

      // Si está presionada, imprimir el nombre de la nota abajo
      if (isPressed) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: ChordParser.spanishScale[noteVal],
            style: GoogleFonts.outfit(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(x + (keyWidth - textPainter.width) / 2, size.height - 18));
      }
    }

    // Teclas Negras (1: DO#, 3: RE#, 6: FA#, 8: SOL#, 10: LA#)
    final Map<int, double> blackKeyOffsets = {
      1: 0.72,
      3: 1.72,
      6: 3.72,
      8: 4.72,
      10: 5.72,
    };

    final double blackKeyWidth = keyWidth * 0.58;
    final double blackKeyHeight = size.height * 0.62;

    blackKeyOffsets.forEach((noteVal, offset) {
      final x = (offset * keyWidth) - (blackKeyWidth / 2);
      final isPressed = activeKeys.contains(noteVal);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, blackKeyWidth, blackKeyHeight),
        const Radius.circular(4),
      );

      canvas.drawRRect(rrect, isPressed ? activeKeyPaint : blackKeyPaint);
      canvas.drawRRect(rrect, whiteBorderPaint);

      if (isPressed) {
        final glowPaint = Paint()
          ..color = Colors.amber.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRRect(rrect, glowPaint);
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
