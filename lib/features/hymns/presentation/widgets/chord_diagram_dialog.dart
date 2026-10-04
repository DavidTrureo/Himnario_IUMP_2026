import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChordDiagramDialog extends StatefulWidget {
  final String chordName;

  const ChordDiagramDialog({super.key, required this.chordName});

  static void show(BuildContext context, String chordName) {
    showDialog(
      context: context,
      builder: (context) => ChordDiagramDialog(chordName: chordName),
    );
  }

  @override
  State<ChordDiagramDialog> createState() => _ChordDiagramDialogState();
}

class _ChordDiagramDialogState extends State<ChordDiagramDialog> {
  int _guitarPosIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final chordData = ChordParser.parse(widget.chordName);
    final posCount = chordData.guitarPositions.length;
    if (_guitarPosIndex >= posCount) {
      _guitarPosIndex = 0;
    }
    final currentPos = chordData.guitarPositions[_guitarPosIndex];

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
                          widget.chordName,
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (posCount > 1)
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  onPressed: () {
                                    setState(() {
                                      _guitarPosIndex = (_guitarPosIndex - 1 + posCount) % posCount;
                                    });
                                  },
                                ),
                              CustomPaint(
                                size: const Size(200, 210),
                                painter: GuitarFretboardPainter(
                                  frets: currentPos.frets,
                                  fingers: currentPos.fingers,
                                  baseFret: currentPos.baseFret,
                                  isDark: isDark,
                                  accentColor: Colors.amber[500]!,
                                ),
                              ),
                              if (posCount > 1)
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  onPressed: () {
                                    setState(() {
                                      _guitarPosIndex = (_guitarPosIndex + 1) % posCount;
                                    });
                                  },
                                ),
                            ],
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

class GuitarPosition {
  final List<int> frets;
  final List<int> fingers;
  final int baseFret;

  const GuitarPosition(this.frets, this.fingers, {this.baseFret = 1});
}

class ChordInfoData {
  final String fullName;
  final List<String> notes;
  final List<GuitarPosition> guitarPositions;
  final List<int> pianoKeys;

  const ChordInfoData(
    this.fullName,
    this.notes,
    this.guitarPositions,
    this.pianoKeys,
  );
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
      return const ChordInfoData('Do Mayor', ['DO', 'MI', 'SOL'], [GuitarPosition([-1, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0])], [0, 4, 7]);
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
    bool isSus4 = lowerSuffix.contains('sus4') || (lowerSuffix.contains('sus') && !lowerSuffix.contains('sus2'));
    bool isSus2 = lowerSuffix.contains('sus2');
    bool has13 = lowerSuffix.contains('13');
    bool hasAdd9 = lowerSuffix.contains('add9') || lowerSuffix.contains('9') || has13;
    bool has9 = lowerSuffix.contains('9') && !lowerSuffix.contains('add9');
    bool has7 = (lowerSuffix.contains('7') && !lowerSuffix.contains('maj7')) || has13 || has9;
    bool hasMaj7 = lowerSuffix.contains('maj7');
    bool is5 = lowerSuffix == '5';

    final List<int> intervals = [0];

    if (is5) {
      intervals.add(7);
    } else if (isDim) {
      intervals.addAll([3, 6]);
      if (has7 || lowerSuffix.contains('b5')) intervals.add(10);
      if (lowerSuffix.contains('dim7')) intervals.add(9); // bb7 = M6 = 9 semitones
    } else if (isAug) {
      intervals.addAll([4, 8]);
      if (has7) intervals.add(10);
    } else {
      // Determinar la tercera (o falta de ella)
      if (isSus4) {
        intervals.add(5);
      } else if (isSus2) {
        intervals.add(2);
      } else if (isMinor) {
        intervals.add(3);
      } else {
        intervals.add(4); // Mayor por defecto
      }
      
      // Quinta justa
      intervals.add(7);

      // Séptimas
      if (has7) intervals.add(10);
      if (hasMaj7) intervals.add(11);
    }

    if (hasAdd9 || has9) {
      if (!intervals.contains(2)) intervals.add(2); // 9th is same as 2nd (2 semitones)
    }
    if (has13) {
      intervals.add(9); // 13th is same as 6th (9 semitones)
    }

    final List<int> pianoKeys = intervals.map((i) => (rootIndex + i) % 12).toSet().toList();
    if (bassIndex != -1 && !pianoKeys.contains(bassIndex)) {
      pianoKeys.insert(0, bassIndex);
    }

    final List<String> notes = pianoKeys.map((idx) => _getSpanishNoteName(idx)).toList();
    final String fullName = _buildFullName(rootStr, suffix, bassNote);

    final guitarPositions = _getGuitarPositions(clean, rootStr, suffix, bassNote, rootIndex);

    return ChordInfoData(
      fullName,
      notes,
      guitarPositions,
      pianoKeys,
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
    } else if (lower.contains('13sus')) {
      quality = '13 Suspendido (13sus)';
    } else if (lower.contains('13')) {
      quality = 'Treceava (13)';
    } else if (lower.contains('sus4') || (lower.contains('sus') && !lower.contains('sus2'))) {
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

  static List<GuitarPosition> _getGuitarPositions(String fullChord, String root, String suffix, String bass, int rootIndex) {
    final clean = fullChord.trim().toUpperCase();

    // Diccionario de acordes comunes y compuestos específicos
    final Map<String, GuitarPosition> dictionary = {
      // DO / C
      'C': const GuitarPosition([-1, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0]),
      'DO': const GuitarPosition([-1, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0]),
      'CM': const GuitarPosition([-1, 3, 5, 5, 4, 3], [0, 1, 3, 4, 2, 1], baseFret: 3),
      'DOM': const GuitarPosition([-1, 3, 5, 5, 4, 3], [0, 1, 3, 4, 2, 1], baseFret: 3),
      'CADD9': const GuitarPosition([-1, 3, 2, 0, 3, 0], [0, 2, 1, 0, 3, 0]),
      'DOADD9': const GuitarPosition([-1, 3, 2, 0, 3, 0], [0, 2, 1, 0, 3, 0]),
      'CSUS4': const GuitarPosition([-1, 3, 3, 0, 1, 1], [0, 3, 4, 0, 1, 1]),
      'DOSUS4': const GuitarPosition([-1, 3, 3, 0, 1, 1], [0, 3, 4, 0, 1, 1]),
      'CSUS2': const GuitarPosition([-1, 3, 0, 0, 1, 0], [0, 3, 0, 0, 1, 0]),
      'DOSUS2': const GuitarPosition([-1, 3, 0, 0, 1, 0], [0, 3, 0, 0, 1, 0]),
      'C7': const GuitarPosition([-1, 3, 2, 3, 1, 0], [0, 3, 2, 4, 1, 0]),
      'DO7': const GuitarPosition([-1, 3, 2, 3, 1, 0], [0, 3, 2, 4, 1, 0]),
      'CMAJ7': const GuitarPosition([-1, 3, 2, 0, 0, 0], [0, 3, 2, 0, 0, 0]),
      'DOMAJ7': const GuitarPosition([-1, 3, 2, 0, 0, 0], [0, 3, 2, 0, 0, 0]),
      'C/E': const GuitarPosition([0, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0]),
      'DO/MI': const GuitarPosition([0, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0]),
      'C/G': const GuitarPosition([3, 3, 2, 0, 1, 0], [3, 4, 2, 0, 1, 0]),
      'DO/SOL': const GuitarPosition([3, 3, 2, 0, 1, 0], [3, 4, 2, 0, 1, 0]),

      // RE / D
      'D': const GuitarPosition([-1, -1, 0, 2, 3, 2], [0, 0, 0, 1, 3, 2]),
      'RE': const GuitarPosition([-1, -1, 0, 2, 3, 2], [0, 0, 0, 1, 3, 2]),
      'DM': const GuitarPosition([-1, -1, 0, 2, 3, 1], [0, 0, 0, 2, 3, 1]),
      'REM': const GuitarPosition([-1, -1, 0, 2, 3, 1], [0, 0, 0, 2, 3, 1]),
      'DADD9': const GuitarPosition([-1, -1, 0, 2, 3, 0], [0, 0, 0, 1, 2, 0]),
      'READD9': const GuitarPosition([-1, -1, 0, 2, 3, 0], [0, 0, 0, 1, 2, 0]),
      'DSUS4': const GuitarPosition([-1, -1, 0, 2, 3, 3], [0, 0, 0, 1, 2, 3]),
      'RESUS4': const GuitarPosition([-1, -1, 0, 2, 3, 3], [0, 0, 0, 1, 2, 3]),
      'DSUS2': const GuitarPosition([-1, -1, 0, 2, 3, 0], [0, 0, 0, 1, 2, 0]),
      'RESUS2': const GuitarPosition([-1, -1, 0, 2, 3, 0], [0, 0, 0, 1, 2, 0]),
      'D7': const GuitarPosition([-1, -1, 0, 2, 1, 2], [0, 0, 0, 2, 1, 3]),
      'RE7': const GuitarPosition([-1, -1, 0, 2, 1, 2], [0, 0, 0, 2, 1, 3]),
      'D/F#': const GuitarPosition([2, 0, 0, 2, 3, 2], [1, 0, 0, 2, 4, 3]),
      'RE/FA#': const GuitarPosition([2, 0, 0, 2, 3, 2], [1, 0, 0, 2, 4, 3]),

      // MI / E
      'E': const GuitarPosition([0, 2, 2, 1, 0, 0], [0, 2, 3, 1, 0, 0]),
      'MI': const GuitarPosition([0, 2, 2, 1, 0, 0], [0, 2, 3, 1, 0, 0]),
      'EM': const GuitarPosition([0, 2, 2, 0, 0, 0], [0, 2, 3, 0, 0, 0]),
      'MIM': const GuitarPosition([0, 2, 2, 0, 0, 0], [0, 2, 3, 0, 0, 0]),
      'E7': const GuitarPosition([0, 2, 0, 1, 0, 0], [0, 2, 0, 1, 0, 0]),
      'MI7': const GuitarPosition([0, 2, 0, 1, 0, 0], [0, 2, 0, 1, 0, 0]),
      'ESUS4': const GuitarPosition([0, 2, 2, 2, 0, 0], [0, 1, 2, 3, 0, 0]),
      'MISUS4': const GuitarPosition([0, 2, 2, 2, 0, 0], [0, 1, 2, 3, 0, 0]),

      // FA / F
      'F': const GuitarPosition([1, 3, 3, 2, 1, 1], [1, 3, 4, 2, 1, 1]),
      'FA': const GuitarPosition([1, 3, 3, 2, 1, 1], [1, 3, 4, 2, 1, 1]),
      'FM': const GuitarPosition([1, 3, 3, 1, 1, 1], [1, 3, 4, 1, 1, 1]),
      'FAM': const GuitarPosition([1, 3, 3, 1, 1, 1], [1, 3, 4, 1, 1, 1]),
      'F#M': const GuitarPosition([2, 4, 4, 2, 2, 2], [1, 3, 4, 1, 1, 1]),
      'FA#M': const GuitarPosition([2, 4, 4, 2, 2, 2], [1, 3, 4, 1, 1, 1]),

      // SOL / G
      'G': const GuitarPosition([3, 2, 0, 0, 0, 3], [2, 1, 0, 0, 0, 3]),
      'SOL': const GuitarPosition([3, 2, 0, 0, 0, 3], [2, 1, 0, 0, 0, 3]),
      'GM': const GuitarPosition([3, 5, 5, 3, 3, 3], [1, 3, 4, 1, 1, 1], baseFret: 3),
      'SOLM': const GuitarPosition([3, 5, 5, 3, 3, 3], [1, 3, 4, 1, 1, 1], baseFret: 3),
      'G7': const GuitarPosition([3, 2, 0, 0, 0, 1], [3, 2, 0, 0, 0, 1]),
      'SOL7': const GuitarPosition([3, 2, 0, 0, 0, 1], [3, 2, 0, 0, 0, 1]),
      'GSUS4': const GuitarPosition([3, 3, 0, 0, 1, 3], [2, 3, 0, 0, 1, 4]),
      'SOLSUS4': const GuitarPosition([3, 3, 0, 0, 1, 3], [2, 3, 0, 0, 1, 4]),
      'G/B': const GuitarPosition([-1, 2, 0, 0, 0, 3], [0, 1, 0, 0, 0, 2]),
      'SOL/SI': const GuitarPosition([-1, 2, 0, 0, 0, 3], [0, 1, 0, 0, 0, 2]),

      // LA / A
      'A': const GuitarPosition([-1, 0, 2, 2, 2, 0], [0, 0, 1, 2, 3, 0]),
      'LA': const GuitarPosition([-1, 0, 2, 2, 2, 0], [0, 0, 1, 2, 3, 0]),
      'AM': const GuitarPosition([-1, 0, 2, 2, 1, 0], [0, 0, 2, 3, 1, 0]),
      'LAM': const GuitarPosition([-1, 0, 2, 2, 1, 0], [0, 0, 2, 3, 1, 0]),
      'A7': const GuitarPosition([-1, 0, 2, 0, 2, 0], [0, 0, 1, 0, 2, 0]),
      'LA7': const GuitarPosition([-1, 0, 2, 0, 2, 0], [0, 0, 1, 0, 2, 0]),
      'AM7': const GuitarPosition([-1, 0, 2, 0, 1, 0], [0, 0, 2, 0, 1, 0]),
      'LAM7': const GuitarPosition([-1, 0, 2, 0, 1, 0], [0, 0, 2, 0, 1, 0]),
      'AADD9': const GuitarPosition([-1, 0, 2, 2, 0, 0], [0, 0, 1, 2, 0, 0]),
      'LAADD9': const GuitarPosition([-1, 0, 2, 2, 0, 0], [0, 0, 1, 2, 0, 0]),
      'AM/G': const GuitarPosition([3, 0, 2, 2, 1, 0], [3, 0, 2, 4, 1, 0]),
      'LAM/SOL': const GuitarPosition([3, 0, 2, 2, 1, 0], [3, 0, 2, 4, 1, 0]),

      // SI / B
      'B': const GuitarPosition([-1, 2, 4, 4, 4, 2], [0, 1, 2, 3, 4, 1], baseFret: 2),
      'SI': const GuitarPosition([-1, 2, 4, 4, 4, 2], [0, 1, 2, 3, 4, 1], baseFret: 2),
      'BM': const GuitarPosition([-1, 2, 4, 4, 3, 2], [0, 1, 3, 4, 2, 1], baseFret: 2),
      'SIM': const GuitarPosition([-1, 2, 4, 4, 3, 2], [0, 1, 3, 4, 2, 1], baseFret: 2),
      'B7': const GuitarPosition([-1, 2, 1, 2, 0, 2], [0, 2, 1, 3, 0, 4]),
      'SI7': const GuitarPosition([-1, 2, 1, 2, 0, 2], [0, 2, 1, 3, 0, 4]),
      // Acordes Semidisminuidos (m7b5) y Disminuidos (dim)
      'CM7(B5)': const GuitarPosition([-1, 3, 4, 3, 4, -1], [0, 1, 3, 2, 4, 0]),
      'DOM7(B5)': const GuitarPosition([-1, 3, 4, 3, 4, -1], [0, 1, 3, 2, 4, 0]),
      'CM7B5': const GuitarPosition([-1, 3, 4, 3, 4, -1], [0, 1, 3, 2, 4, 0]),
      'DOM7B5': const GuitarPosition([-1, 3, 4, 3, 4, -1], [0, 1, 3, 2, 4, 0]),
      'CDIM': const GuitarPosition([-1, 3, 4, 2, 4, -1], [0, 2, 3, 1, 4, 0]),
      'DODIM': const GuitarPosition([-1, 3, 4, 2, 4, -1], [0, 2, 3, 1, 4, 0]),

      'C#M7(B5)': const GuitarPosition([-1, 4, 5, 4, 5, -1], [0, 1, 3, 2, 4, 0]),
      'DO#M7(B5)': const GuitarPosition([-1, 4, 5, 4, 5, -1], [0, 1, 3, 2, 4, 0]),

      'DM7(B5)': const GuitarPosition([-1, 5, 6, 5, 6, -1], [0, 1, 3, 2, 4, 0]),
      'REM7(B5)': const GuitarPosition([-1, 5, 6, 5, 6, -1], [0, 1, 3, 2, 4, 0]),

      'EM7(B5)': const GuitarPosition([0, 1, 0, 0, 0, 0], [0, 1, 0, 0, 0, 0]),
      'MIM7(B5)': const GuitarPosition([0, 1, 0, 0, 0, 0], [0, 1, 0, 0, 0, 0]),

      'F#M7(B5)': const GuitarPosition([2, -1, 2, 2, 1, -1], [2, 0, 3, 4, 1, 0]),
      'FA#M7(B5)': const GuitarPosition([2, -1, 2, 2, 1, -1], [2, 0, 3, 4, 1, 0]),

      'GM7(B5)': const GuitarPosition([3, -1, 3, 3, 2, -1], [2, 0, 3, 4, 1, 0]),
      'SOLM7(B5)': const GuitarPosition([3, -1, 3, 3, 2, -1], [2, 0, 3, 4, 1, 0]),

      'AM7(B5)': const GuitarPosition([-1, 0, 1, 0, 1, 0], [0, 0, 1, 0, 2, 0]),
      'LAM7(B5)': const GuitarPosition([-1, 0, 1, 0, 1, 0], [0, 0, 1, 0, 2, 0]),

      'BM7(B5)': const GuitarPosition([-1, 2, 3, 2, 3, -1], [0, 1, 3, 2, 4, 0]),
      'SIM7(B5)': const GuitarPosition([-1, 2, 3, 2, 3, -1], [0, 1, 3, 2, 4, 0]),
    };

    if (dictionary.containsKey(clean)) {
      final exact = dictionary[clean]!;
      // For exact dictionary matches, we only provide 1 position for now.
      return [exact];
    }

    // Si no está exacto en el diccionario, generar 2 posiciones (Cejuela en 5ta y 6ta cuerda)
    final lower = suffix.toLowerCase();
    
    final bool isHalfDim = lower.contains('m7(b5)') || lower.contains('m7b5');
    final bool isDim = lower.contains('dim') && !isHalfDim;
    final bool is13Sus = lower.contains('13sus');
    final bool is13 = lower.contains('13') && !is13Sus;
    final bool isSus4 = (lower.contains('sus4') || (lower.contains('sus') && !lower.contains('sus2'))) && !is13Sus;
    
    final bool hasAdd9 = lower.contains('add9');
    final bool has9 = lower.contains('9') && !hasAdd9;
    final bool hasMaj7 = lower.contains('maj7');
    final bool has7 = (lower.contains('7') && !hasMaj7) || is13 || has9;
    final bool isMinor = lower.startsWith('m') && !isHalfDim && !isDim;

    // Configuración Base - Cuerda 5 (A shape)
    List<int> aFrets = [-1, 1, 3, 3, 3, 1]; // Mayor
    List<int> aFingers = [0, 1, 2, 3, 4, 1];
    
    // Configuración Base - Cuerda 6 (E shape)
    List<int> eFrets = [1, 3, 3, 2, 1, 1]; // Mayor
    List<int> eFingers = [1, 3, 4, 2, 1, 1];

    if (isHalfDim) {
      aFrets = [-1, 1, 2, 1, 2, -1];
      aFingers = [0, 1, 3, 1, 4, 0];
      eFrets = [1, -1, 1, 1, 0, -1]; // Forma de 6ta cuerda con traste "al aire" local
      eFingers = [1, 0, 2, 3, 0, 0]; // (Nota: será recalculado sin embargo es complejo de transponer. Lo omitiremos de momento al filtrar)
    } else if (isDim) {
      aFrets = [-1, 1, 2, 3, 2, -1];
      aFingers = [0, 1, 2, 4, 3, 0];
      eFrets = [1, -1, 1, 1, -1, -1];
      eFingers = [1, 0, 2, 3, 0, 0];
    } else if (hasAdd9) {
      aFrets = [-1, 1, 3, 3, 1, 3];
      aFingers = [0, 1, 3, 4, 1, 2];
      eFrets = [1, 3, 5, 2, 1, 1];
      eFingers = [1, 2, 4, 3, 1, 1];
    } else if (has9) {
      aFrets = [-1, 1, 3, 1, 3, 1]; // Fallback to 7
      aFingers = [0, 1, 3, 1, 4, 1];
      eFrets = [1, 3, 1, 2, 1, 3];
      eFingers = [1, 3, 1, 2, 1, 4];
    } else if (is13Sus) {
      aFrets = [-1, 1, 1, 1, 1, 3];
      aFingers = [0, 1, 1, 1, 1, 4];
      eFrets = [1, -1, 1, 3, 3, 3];
      eFingers = [1, 0, 1, 2, 3, 4];
    } else if (is13) {
      aFrets = [-1, 1, 3, 1, 3, 1]; // Fallback 7
      aFingers = [0, 1, 3, 1, 4, 1];
      eFrets = [1, -1, 1, 2, 3, -1];
      eFingers = [1, 0, 1, 2, 4, 0];
    } else if (isSus4) {
      aFrets = [-1, 1, 3, 3, 4, 1];
      aFingers = [0, 1, 2, 3, 4, 1];
      eFrets = [1, 3, 3, 3, 1, 1];
      eFingers = [1, 2, 3, 4, 1, 1];
    } else if (hasMaj7) {
      aFrets = [-1, 1, 3, 2, 3, 1];
      aFingers = [0, 1, 3, 2, 4, 1];
      eFrets = [1, -1, 2, 2, 1, -1];
      eFingers = [1, 0, 3, 4, 2, 0];
    } else if (isMinor && has7) { // m7
      aFrets = [-1, 1, 3, 1, 2, 1];
      aFingers = [0, 1, 3, 1, 2, 1];
      eFrets = [1, 3, 1, 1, 1, 1];
      eFingers = [1, 3, 1, 1, 1, 1];
    } else if (has7) { // Dominant 7
      aFrets = [-1, 1, 3, 1, 3, 1];
      aFingers = [0, 1, 3, 1, 4, 1];
      eFrets = [1, 3, 1, 2, 1, 1];
      eFingers = [1, 3, 1, 2, 1, 1];
    } else if (isMinor) { // Minor triad
      aFrets = [-1, 1, 3, 3, 2, 1];
      aFingers = [0, 1, 3, 4, 2, 1];
      eFrets = [1, 3, 3, 1, 1, 1];
      eFingers = [1, 3, 4, 1, 1, 1];
    }

    GuitarPosition generatePos(List<int> patternFrets, List<int> patternFingers, int offset) {
      final int fretOffset = (rootIndex + offset) % 12;
      final int finalBaseFret = fretOffset == 0 ? 12 : fretOffset;
      final int shift = finalBaseFret - 1;
      final absoluteFrets = patternFrets.map((f) => (f == -1 || f == 0) ? f : f + shift).toList();
      return GuitarPosition(absoluteFrets, patternFingers, baseFret: finalBaseFret);
    }

    final posA = generatePos(aFrets, aFingers, 3); // A string (Offset 3)
    final posE = generatePos(eFrets, eFingers, 8); // E string (Offset 8)

    // Si es un acorde muy raro y no hemos definido la forma de E, la ignoramos.
    if (isHalfDim || isDim) {
      return [posA];
    }

    // Ordenar de forma inteligente: el que está más cerca del clavijero se muestra primero
    if (posE.baseFret < posA.baseFret) {
      return [posE, posA];
    } else {
      return [posA, posE];
    }
  }
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
