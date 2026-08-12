class ChordTransposerService {
  static const List<String> _notesSharp = [
    'DO', 'DO#', 'RE', 'RE#', 'MI', 'FA', 'FA#', 'SOL', 'SOL#', 'LA', 'LA#', 'SI'
  ];

  static const List<String> _notesFlat = [
    'DO', 'REb', 'RE', 'MIb', 'MI', 'FA', 'SOLb', 'SOL', 'LAb', 'LA', 'SIb', 'SI'
  ];

  static const Map<String, int> _noteMap = {
    'DO': 0, 'C': 0,
    'DO#': 1, 'C#': 1, 'REB': 1, 'DB': 1,
    'RE': 2, 'D': 2,
    'RE#': 3, 'D#': 3, 'MIB': 3, 'EB': 3,
    'MI': 4, 'E': 4,
    'FA': 5, 'F': 5,
    'FA#': 6, 'F#': 6, 'SOLB': 6, 'GB': 6,
    'SOL': 7, 'G': 7,
    'SOL#': 8, 'G#': 8, 'LAB': 8, 'AB': 8,
    'LA': 9, 'A': 9,
    'LA#': 10, 'A#': 10, 'SIB': 10, 'BB': 10,
    'SI': 11, 'B': 11,
  };

  /// Transpone una letra completa que contiene corchetes de acordes como `[DO]`, `[SOL#m7]`
  static String transposeLyrics(String lyrics, int semitones, {bool useFlats = false}) {
    if (semitones == 0) return lyrics;

    final RegExp chordRegex = RegExp(r'\[([^\]]+)\]');
    return lyrics.replaceAllMapped(chordRegex, (match) {
      final inner = match.group(1)!;
      final transposedInner = transposeSingleChord(inner, semitones, useFlats: useFlats);
      return '[$transposedInner]';
    });
  }

  /// Transpone un acorde individual como `SOL#m7(b5)/FA#`
  static String transposeSingleChord(String chord, int semitones, {bool useFlats = false}) {
    if (semitones == 0 || chord.trim().isEmpty) return chord;

    // Si es un acorde compuesto con bajo (ej. SOL/SI o FA#/LA#)
    if (chord.contains('/')) {
      final parts = chord.split('/');
      final mainChord = transposeSingleChord(parts[0], semitones, useFlats: useFlats);
      final bassNote = transposeNote(parts[1], semitones, useFlats: useFlats);
      return '$mainChord/$bassNote';
    }

    // Expresión regular para extraer la nota raíz y los sufijos (m, 7, maj7, dim, aug, etc.)
    final RegExp noteExtract = RegExp(r'^(DO#|DOb|RE#|REb|MIb|FA#|SOL#|SOLb|LAb|LA#|SIb|C#|Db|D#|Eb|F#|G#|Ab|A#|Bb|DO|RE|MI|FA|SOL|LA|SI|A|B|C|D|E|F|G)(.*)$', caseSensitive: false);

    final match = noteExtract.firstMatch(chord.trim());
    if (match == null) return chord;

    final root = match.group(1)!;
    final suffix = match.group(2) ?? '';

    final transposedRoot = transposeNote(root, semitones, useFlats: useFlats);
    return '$transposedRoot$suffix';
  }

  /// Transpone una nota raíz individual
  static String transposeNote(String note, int semitones, {bool useFlats = false}) {
    final cleanNote = note.trim().toUpperCase();
    final index = _noteMap[cleanNote];
    if (index == null) return note;

    int newIndex = (index + semitones) % 12;
    if (newIndex < 0) newIndex += 12;

    final scale = useFlats ? _notesFlat : _notesSharp;
    return scale[newIndex];
  }
}
