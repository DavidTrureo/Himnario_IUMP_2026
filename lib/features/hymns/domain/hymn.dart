import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/local_hymn_storage_service.dart';

class Hymn {
  final int id;
  final String title;
  final String toneNote;       // Tono / Nota (ej: "D" o "RE")
  final String beats;          // Tiempos (ej: "3")
  final String timeSignature;  // Métrica (ej: "4/4")
  final String lyrics;
  final String collection;
  final String audioUrl;
  final String category;
  final List<String> sheetMusicUrls;
  final bool isLocalOnly;
  final String normalizedTitle;
  final String normalizedSearchableText;

  Hymn({
    required this.id,
    required this.title,
    required this.toneNote,
    required this.beats,
    required this.timeSignature,
    required this.lyrics,
    required this.collection,
    this.audioUrl = '',
    this.category = '',
    this.sheetMusicUrls = const [],
    this.isLocalOnly = false,
  })  : normalizedTitle = normalizeString(title),
        normalizedSearchableText = normalizeString('$id $title $lyrics');

  static final Map<String, List<Hymn>> _staticCache = {};

  static List<Hymn> getCachedBaseHymns(String collection) {
    return _staticCache[collection] ?? const [];
  }

  static Future<void> preloadAssets() async {
    for (final coll in ['iump', 'especiales', 'coros']) {
      String path;
      if (coll == 'especiales') {
        path = 'assets/json/special_hymns.json';
      } else if (coll == 'coros') {
        path = 'assets/json/coros.json';
      } else {
        path = 'assets/json/hymns.json';
      }
      try {
        final jsonString = await rootBundle.loadString(path);
        final List<dynamic> jsonList = json.decode(jsonString);
        _staticCache[coll] = jsonList.map((j) => Hymn.fromJson(j, coll)).toList();
      } catch (e) {
        debugPrint('>>> Error al precargar asset $path: $e');
      }
    }
  }

  String get collectionName {
    if (collection == 'especiales') return 'Alabanzas Especiales';
    if (collection == 'coros') return 'Coros de Avivamiento';
    return 'Himnario IUMP';
  }

  String get tone {
    return Hymn.buildToneString(
      toneNote: toneNote,
      beats: beats,
      timeSignature: timeSignature,
    );
  }

  factory Hymn.fromJson(Map<String, dynamic> json, String collection) {
    final rawTone = json['tone'] as String? ?? '';
    String toneNote = json['toneNote'] as String? ?? '';
    String beats = json['beats'] as String? ?? '';
    String timeSignature = json['timeSignature'] as String? ?? '';

    if (toneNote.isEmpty && beats.isEmpty && timeSignature.isEmpty && rawTone.isNotEmpty) {
      final parsed = Hymn.parseToneComponents(rawTone);
      toneNote = parsed['toneNote'] ?? '';
      beats = parsed['beats'] ?? '';
      timeSignature = parsed['timeSignature'] ?? '';
    }

    return Hymn(
      id: json['id'] as int,
      title: json['title'] as String,
      toneNote: toneNote,
      beats: beats,
      timeSignature: timeSignature,
      lyrics: json['lyrics'] as String,
      collection: collection,
      audioUrl: json['audioUrl'] as String? ?? '',
      category: json['category'] as String? ?? '',
      sheetMusicUrls: (json['sheetMusicUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'toneNote': toneNote,
      'beats': beats,
      'timeSignature': timeSignature,
      'tone': tone,
      'lyrics': lyrics,
      'audioUrl': audioUrl,
      'sheetMusicUrls': sheetMusicUrls,
      'category': category,
    };
  }

  Hymn copyWith({
    String? title,
    String? toneNote,
    String? beats,
    String? timeSignature,
    String? lyrics,
    String? audioUrl,
    String? category,
    List<String>? sheetMusicUrls,
  }) {
    return Hymn(
      id: id,
      title: title ?? this.title,
      toneNote: toneNote ?? this.toneNote,
      beats: beats ?? this.beats,
      timeSignature: timeSignature ?? this.timeSignature,
      lyrics: lyrics ?? this.lyrics,
      collection: collection,
      audioUrl: audioUrl ?? this.audioUrl,
      category: category ?? this.category,
    );
  }

  static String formatLineCasing(String line) {
    // Corregir 'el' pronombre sin acento al final de línea o antes de puntuación
    final RegExp pronounElRegExp = RegExp(r'\b[eE][lL]\b(?=\s*($|[,;.:?!)»"“\r\n]))');
    final processedLine = line.replaceAll(pronounElRegExp, 'él');

    final RegExp bracketRegExp = RegExp(r'\[([^\]]*)\]');
    final List<String> chords = [];
    final String textWithPlaceholders = processedLine.replaceAllMapped(bracketRegExp, (match) {
      chords.add(match.group(1)!.toUpperCase());
      return '___${chords.length - 1}___';
    });

    String formattedText = textWithPlaceholders;
    
    // Si la línea está en MAYÚSCULAS sostenidas, se convierte a minúsculas antes de aplicar formato orativo
    final testStr = formattedText.replaceAll(RegExp(r'___\d+___'), '').trim();
    if (testStr.length > 3 && testStr == testStr.toUpperCase() && !testStr.startsWith('CORO') && !testStr.startsWith('PUENTE')) {
      formattedText = formattedText.toLowerCase();
    }

    if (formattedText.isNotEmpty) {
      int firstLetterIdx = -1;
      for (int i = 0; i < formattedText.length; i++) {
        if (RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]').hasMatch(formattedText[i])) {
          firstLetterIdx = i;
          break;
        }
      }
      if (firstLetterIdx != -1) {
        formattedText = formattedText.substring(0, firstLetterIdx) +
            formattedText[firstLetterIdx].toUpperCase() +
            formattedText.substring(firstLetterIdx + 1);
      }
    }
    
    final List<String> wordsToCapitalize = [
      'dios', 'jesús', 'jesus', 'cristo', 'jesucristo', 'nazareno', 'maestro', 
      'señor', 'senor', 'salvador', 'redentor', 'mesías', 'mesias', 'jehová', 
      'jehova', 'emanuel', 'shalom', 'santo', 'espíritu', 'espiritu', 'padre', 
      'hijo', 'rey', 'reyes', 'jerusalén', 'jerusalen', 'sión', 'sion', 'marta', 
      'lázaro', 'lazaro', 'canaán', 'canaan', 'david', 'juan', 'israel',
      'abraham', 'sara', 'sarah', 'isaac', 'jacob', 'josé', 'jose', 'moisés', 'moises',
      'aarón', 'aaron', 'josué', 'josue', 'caleb', 'rut', 'ruth', 'samuel', 'saúl', 'saul',
      'salomón', 'salomon', 'elías', 'elias', 'eliseo', 'isaías', 'isaias', 'jeremías', 'jeremias',
      'ezequiel', 'daniel', 'oseas', 'joel', 'amós', 'amos', 'abdías', 'abdias', 'jonás', 'jonas',
      'miqueas', 'nahúm', 'nahum', 'habacuc', 'sofonías', 'sofonias', 'hageo', 'zacarías', 'zacarias',
      'malaquías', 'malaquias', 'mateo', 'marcos', 'lucas', 'pedro', 'pablo', 'silas', 'esteban',
      'felipe', 'tomás', 'tomas', 'simón', 'simon', 'andrés', 'andres', 'santiago', 'bartolomé', 'bartolome',
      'judas', 'nicodemo', 'zaqueo', 'bernabé', 'bernabe', 'timoteo', 'tito', 'filemón', 'filemon',
      'sansón', 'sanson', 'goliat', 'job', 'noé', 'noe', 'adán', 'adan', 'eva', 'abel', 'enoc',
      'matusalén', 'matusalen', 'lot', 'agar', 'ismael', 'rebeca', 'lea', 'raquel', 'miriam', 'jetro',
      'débora', 'debora', 'barac', 'gedeón', 'gedeon', 'jefté', 'jefte', 'dalila', 'elí', 'eli', 'ana',
      'jonatán', 'jonatan', 'betsabé', 'betsabe', 'absalón', 'absalon', 'jeroboam', 'roboam', 'acab',
      'jezabel', 'manasés', 'manases', 'josías', 'josias', 'nabucodonosor', 'belsasar', 'ciro', 'darío', 'dario',
      'ester', 'mardoqueo', 'nehemías', 'nehemias', 'esdras', 'gabriel', 'miguel', 'herodes', 'pilato',
      'caifás', 'caifas', 'ananías', 'ananias', 'safira', 'cornelio', 'lidia', 'apolo', 'aquila',
      'priscila', 'dorcas', 'eutico', 'onesíforo', 'onesiforo', 'diótrefe', 'diotrefes', 'satán', 'satan',
      'satanás', 'satanas', 'luzbel', 'belén', 'belen', 'nazaret', 'nazareth', 'beulah', 'edén', 'eden',
      'galilea', 'judea', 'palestina', 'genesaret', 'chile', 'getsemaní', 'getsemani', 'jordán', 'jordan',
      'betlehem', 'sarón', 'saron', 'calvario', 'horeb', 'sinaí', 'sinai', 'carmelo', 'olivos', 'gólgota', 'golgota',
      'egipto', 'asiria', 'babilonia', 'roma', 'grecia', 'samaria', 'damasco', 'antioquía', 'antioquia',
      'tarso', 'éfeso', 'efeso', 'filipos', 'colosas', 'tesalónica', 'tesalonica', 'corinto', 'atenas',
      'patmos', 'jericó', 'jerico', 'betania', 'betel', 'peniel', 'nínive', 'ninive', 'ur', 'sodoma',
      'gomorra', 'tiberias', 'efrata', 'sicar', 'siloé', 'siloe', 'siquem', 'cedrón', 'cedron', 'silo',
      'galaad', 'basán', 'basan', 'moab', 'edom', 'amón', 'amon', 'fenicia', 'tiro', 'sidón', 'sidon',
      'nilo', 'éufrates', 'eufrates', 'samaritano', 'pentecostés', 'pentecostes',
      'tú', 'ti', 'él', 'oh', 'amén', 'amen', 'aleluya'
    ];
    
    for (final word in wordsToCapitalize) {
      final RegExp wordRegExp = RegExp(
        r'(?<=^|[^a-zA-ZáéíóúÁÉÍÓÚñÑ])' + RegExp.escape(word) + r'(?=$|[^a-zA-ZáéíóúÁÉÍÓÚñÑ])',
        caseSensitive: false
      );
      formattedText = formattedText.replaceAllMapped(wordRegExp, (match) {
        final matched = match.group(0)!;
        return matched[0].toUpperCase() + matched.substring(1);
      });
    }
    
    for (int i = 0; i < chords.length; i++) {
      formattedText = formattedText.replaceFirst('___${i}___', '[${chords[i]}]');
    }
    
    return formattedText;
  }

  /// Garantiza que números de estrofa (1. , 2. ) y cabeceras de coro (CORO:) queden siempre en su propia línea
  static String ensureHeadersOnOwnLine(String lyrics) {
    if (lyrics.trim().isEmpty) return lyrics;

    final lines = lyrics.split('\n');
    final List<String> resultLines = [];

    final RegExp verseInlineHeader = RegExp(
      r'^((?:\d+|[IVXivx]+|Estrofa\s*\d+)\s*[\.\-:]?)\s+(.+)$',
      caseSensitive: false,
    );

    final RegExp chorusInlineHeader = RegExp(
      r'^((?:CORO|PUENTE|FINAL|SOLISTA|INTERLUDIO)(?:\s+(?:\d+|[IVXivx]+|FINAL))?\s*[\.\-:]?)\s+(.+)$',
      caseSensitive: false,
    );

    for (final line in lines) {
      final trimmed = line.trim();

      final chorusMatch = chorusInlineHeader.firstMatch(trimmed);
      if (chorusMatch != null) {
        final header = chorusMatch.group(1)!.trim();
        final rest = chorusMatch.group(2)!.trim();
        resultLines.add(header);
        if (rest.isNotEmpty) {
          resultLines.add(rest);
        }
        continue;
      }

      final verseMatch = verseInlineHeader.firstMatch(trimmed);
      if (verseMatch != null) {
        final header = verseMatch.group(1)!.trim();
        final rest = verseMatch.group(2)!.trim();
        
        final parsedNum = _parseVerseNumber(header);
        if (parsedNum != null) {
          resultLines.add('$parsedNum.');
        } else {
          resultLines.add(header);
        }
        
        if (rest.isNotEmpty) {
          resultLines.add(rest);
        }
        continue;
      }

      // Además, si la línea ya es un header por sí sola, la normalizamos
      final standaloneMatch = RegExp(r'^((?:\d+|[IVXivx]+|Estrofa\s*\d+)\s*[\.\-:]?)$', caseSensitive: false).firstMatch(trimmed);
      if (standaloneMatch != null && trimmed.length <= 15) {
        final header = standaloneMatch.group(1)!.trim();
        final parsedNum = _parseVerseNumber(header);
        if (parsedNum != null) {
          resultLines.add('$parsedNum.');
          continue;
        }
      }

      resultLines.add(line);
    }

    return resultLines.join('\n');
  }

  static int? _parseVerseNumber(String header) {
    final clean = header.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();
    if (clean.startsWith('estrofa')) {
      final numStr = clean.replaceAll('estrofa', '');
      return int.tryParse(numStr);
    }
    if (int.tryParse(clean) != null) {
      return int.parse(clean);
    }
    const romanMap = {
      'i': 1, 'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 
      'vi': 6, 'vii': 7, 'viii': 8, 'ix': 9, 'x': 10,
      'xi': 11, 'xii': 12, 'xiii': 13, 'xiv': 14, 'xv': 15,
      'xvi': 16, 'xvii': 17, 'xviii': 18, 'xix': 19, 'xx': 20
    };
    return romanMap[clean];
  }

  /// Sanitiza y embellece cualquier texto de letra para su despliegue visual
  static String sanitizeLyricsDisplay(String rawLyrics, {String? title}) {
    if (rawLyrics.trim().isEmpty) return '';

    final lines = rawLyrics.split('\n');
    final List<String> cleanedLines = [];
    final cleanTitleNorm = title != null ? normalizeString(title) : '';

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) {
        cleanedLines.add('');
        continue;
      }

      // 1. Descartar metadatos redundantes tipo "Tiempo 4 / Nota: Slm." o "Tiempo 2 / Nota: DO."
      if (RegExp(r'^tiempo\s+\d+.*nota\s*:', caseSensitive: false).hasMatch(line) ||
          RegExp(r'^nota\s*:.*tiempo\s*:', caseSensitive: false).hasMatch(line) ||
          RegExp(r'^tiempo\s+\d+\b', caseSensitive: false).hasMatch(line)) {
        continue;
      }

      // 2. Descartar líneas duplicadas del título al inicio de la letra
      if (i <= 1 && cleanTitleNorm.isNotEmpty) {
        final lineNorm = normalizeString(line);
        if (lineNorm == cleanTitleNorm || 
            lineNorm.startsWith('16 sueno') || 
            lineNorm == 'gracias senor' || 
            lineNorm == 'te seguire amando') {
          continue;
        }
      }

      // 3. Corregir palabras pegadas y errores tipográficos comunes
      line = line.replaceAll(RegExp(r'^ISIENTO\b', caseSensitive: false), 'SIENTO');
      line = line.replaceAll(RegExp(r'^IFELIZ\b', caseSensitive: false), 'FELIZ');
      line = line.replaceAll(RegExp(r'([a-záéíóúñ])([A-ZÁÉÍÓÚÑ])'), r'$1 $2');

      // Reemplazos específicos de palabras pegadas
      line = line.replaceAll('CONMIGOTE', 'CONMIGO TE');
      line = line.replaceAll('AMIGOTOMA', 'AMIGO TOMA');
      line = line.replaceAll('VIDATOMA', 'VIDA TOMA');
      line = line.replaceAll('SENTIRTEQUIERO', 'SENTIRTE QUIERO');
      line = line.replaceAll('AMORPUES', 'AMOR PUES');
      line = line.replaceAll('TRISTEHOY', 'TRISTE HOY');
      line = line.replaceAll('DÍAGRACIAS', 'DÍA GRACIAS');
      line = line.replaceAll('DIAGRACIAS', 'DIA GRACIAS');
      line = line.replaceAll('FELIZIIGRACIAS', 'FELIZ. GRACIAS');
      line = line.replaceAll('AMORCIENTO', 'AMOR. SIENTO');

      // 4. Formatear oraciones en Mayúsculas sostenidas
      if (line.length > 5 &&
          line == line.toUpperCase() &&
          !line.startsWith('CORO') &&
          !line.startsWith('PUENTE') &&
          !line.contains('[')) {
        line = formatLineCasing(line);
      }

      cleanedLines.add(line);
    }

    final joined = cleanedLines.join('\n');
    return ensureHeadersOnOwnLine(joined);
  }

  static String formatLyricsForSaving(String lyrics, String collection) {
    final sanitizedHeaders = ensureHeadersOnOwnLine(lyrics);
    // 0. Limpiar abreviaturas de menor "Mn." / "Mn" a "m" dentro de los corchetes
    final regexChords = RegExp(r'\[([^\]]+)\]');
    final cleanedLyrics = sanitizedHeaders.replaceAllMapped(regexChords, (match) {
      final inside = match.group(1)!;
      final cleaned = inside.replaceAll(RegExp(r'\s*(Mn\.|Mn|mn\.|mn)\b'), 'm');
      return '[$cleaned]';
    });

    final trimmed = cleanedLyrics.trim();
    if (trimmed.isEmpty) return '';
    
    if (collection == 'coros') {
      final lines = trimmed.split('\n');
      final formattedLines = lines.map((l) => formatLineCasing(l)).toList();
      return formattedLines.join('\n');
    }
    
    // Para 'iump' o 'especiales', separamos por bloques
    final blocks = trimmed.split(RegExp(r'\n\s*\n'));
    final RegExp keywordRegExp = RegExp(
      r'^(coro\s+[ivx]+|coro\s+\d+|coro\s+final|coro|final|solista|puente|interludio)(?:\s*:\s*|\s+|$)', 
      caseSensitive: false
    );
    
    final List<String> formattedBlocks = [];
    for (final block in blocks) {
      final trimmedBlock = block.trim();
      if (trimmedBlock.isEmpty) continue;
      
      final lines = trimmedBlock.split('\n');
      final firstLine = lines.first.trim();
      
      final match = keywordRegExp.firstMatch(firstLine);
      final formattedLines = lines.map((l) => formatLineCasing(l)).toList();
      
      if (match != null) {
        // Mantenemos la cabecera (CORO, PUENTE, etc.) en mayúsculas
        final headerMatch = keywordRegExp.firstMatch(formattedLines.first);
        if (headerMatch != null) {
          final headerText = headerMatch.group(1)!.toUpperCase();
          formattedLines[0] = formattedLines[0].replaceFirst(headerMatch.group(1)!, headerText);
        }
      }
      formattedBlocks.add(formattedLines.join('\n'));
    }
    
    return formattedBlocks.join('\n\n');
  }


  // Helper para remover tildes y caracteres especiales
  static String removeDiacritics(String str) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuyNn';
    
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  // Normaliza eliminando tildes, signos de puntuación y unificando espacios
  static String normalizeString(String str) {
    if (str.trim().isEmpty) return '';
    String normalized = removeDiacritics(str.toLowerCase());
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Método de conveniencia para búsquedas ultra-rápidas (insensible a acentos y puntuación)
  bool matchesSearch(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return true;
    
    final normalizedQuery = normalizeString(cleanQuery);
    if (normalizedQuery.isEmpty) return true;

    // 1. Coincidencia de substring normalizado en ID, Título o Letra
    if (normalizedSearchableText.contains(normalizedQuery)) return true;

    // 2. Coincidencia por palabras clave
    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty);
    if (queryWords.isEmpty) return true;

    return queryWords.every((w) => normalizedSearchableText.contains(w));
  }

  static String transposeLyrics(String lyrics, int semitones) {
    // Buscar todos los bloques entre corchetes [Acorde]
    final RegExp chordRegex = RegExp(r'\[([^\]]+)\]');
    
    return lyrics.replaceAllMapped(chordRegex, (match) {
      final insideBrackets = match.group(1)!;
      // Limpiar abreviaciones de menor "Mn." / "Mn" a "m"
      final cleaned = insideBrackets.replaceAll(RegExp(r'\s*(Mn\.|Mn|mn\.|mn)\b'), 'm');
      if (semitones == 0) return '[$cleaned]';
      final transposed = transposeChord(cleaned, semitones);
      return '[$transposed]';
    });
  }

  static String transposeChord(String chord, int semitones) {
    // Limpiar abreviaciones de menor "Mn." / "Mn" a "m"
    final cleaned = chord.replaceAll(RegExp(r'\s*(Mn\.|Mn|mn\.|mn)\b'), 'm');

    // Escalas de notas para buscar y transponer
    final List<String> englishScale = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
    ];
    final List<String> englishScaleFlats = [
      'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
    ];
    final List<String> spanishScale = [
      'DO', 'DO#', 'RE', 'RE#', 'MI', 'FA', 'FA#', 'SOL', 'SOL#', 'LA', 'LA#', 'SI'
    ];
    final List<String> spanishScaleFlats = [
      'DO', 'REB', 'RE', 'MIB', 'MI', 'FA', 'SOLB', 'SOL', 'LAB', 'LA', 'SIB', 'SI'
    ];

    final uppercaseChord = cleaned.toUpperCase().trim();

    // 1. Intentar hacer coincidir la nota en español
    final RegExp spanishNoteRegex = RegExp(
      r'^(DO#|DO|RE#|REB|RE|MI#|MIB|MI|FA#|FA|SOL#|SOLB|SOL|LA#|LAB|LA|SI#|SIB|SI)',
      caseSensitive: false
    );
    final spanishMatch = spanishNoteRegex.firstMatch(uppercaseChord);

    if (spanishMatch != null) {
      final noteMatch = spanishMatch.group(1)!;
      final suffix = cleaned.substring(noteMatch.length);
      
      // Buscar índice de la nota en la escala española (tanto sostenidos como bemoles)
      int idx = spanishScale.indexOf(noteMatch);
      if (idx == -1) {
        idx = spanishScaleFlats.indexOf(noteMatch);
      }
      
      if (idx != -1) {
        final newIdx = (idx + semitones) % 12;
        final finalIdx = newIdx < 0 ? newIdx + 12 : newIdx;
        
        // Decidir si usamos la escala de sostenidos o bemoles basada en el acorde original
        final useFlats = noteMatch.contains('B') || noteMatch == 'REB' || noteMatch == 'MIB' || noteMatch == 'LAB' || noteMatch == 'SIB';
        final newNote = useFlats ? spanishScaleFlats[finalIdx] : spanishScale[finalIdx];
        
        // Formatear la nueva nota respetando la capitalización original (ej: Do -> Re, DO -> RE, do -> re)
        final formattedNote = _capitalizeAs(newNote, cleaned.substring(0, noteMatch.length));
        return '$formattedNote$suffix';
      }
    }

    // 2. Intentar hacer coincidir la nota en inglés
    final RegExp englishNoteRegex = RegExp(
      r'^(C#|DB|D#|EB|E|F#|GB|G#|AB|A#|BB|B|C)',
      caseSensitive: false
    );
    final englishMatch = englishNoteRegex.firstMatch(uppercaseChord);

    if (englishMatch != null) {
      final noteMatch = englishMatch.group(1)!;
      final suffix = cleaned.substring(noteMatch.length);
      
      int idx = englishScale.indexOf(noteMatch);
      if (idx == -1) {
        idx = englishScaleFlats.indexOf(noteMatch);
      }
      
      if (idx != -1) {
        final newIdx = (idx + semitones) % 12;
        final finalIdx = newIdx < 0 ? newIdx + 12 : newIdx;
        
        final useFlats = noteMatch.contains('B') || noteMatch == 'Db' || noteMatch == 'Eb' || noteMatch == 'Ab' || noteMatch == 'Bb';
        final newNote = useFlats ? englishScaleFlats[finalIdx] : englishScale[finalIdx];
        
        final formattedNote = _capitalizeAs(newNote, cleaned.substring(0, noteMatch.length));
        return '$formattedNote$suffix';
      }
    }

    return cleaned; // Devolver intacto si no coincide
  }

  // Capitaliza una nota resultante basándose en el estilo de la nota original
  static String _capitalizeAs(String target, String source) {
    if (source.isEmpty) return target;
    
    // Si la original era toda en mayúsculas (ej: DO)
    if (source == source.toUpperCase()) {
      return target.toUpperCase();
    }
    // Si la original era toda en minúsculas (ej: do)
    if (source == source.toLowerCase()) {
      return target.toLowerCase();
    }
    // Si la original era en formato título (ej: Do, Sol#)
    if (source[0] == source[0].toUpperCase()) {
      return target[0].toUpperCase() + target.substring(1).toLowerCase();
    }
    
    return target;
  }

  static String convertChordNotation(String chord, String targetNotation) {
    if (chord.trim().isEmpty) return chord;

    // Manejo de bajo alternativo (Slash chord) ej: DOm/SOL, Cm/G, /DO, /C
    if (chord.contains('/')) {
      final parts = chord.split('/');
      final formattedMain = parts[0].isNotEmpty ? _convertSingleChordToken(parts[0], targetNotation) : '';
      final formattedBass = parts[1].isNotEmpty ? _convertSingleChordToken(parts[1], targetNotation) : '';
      
      // Ajustar nota de bajo: Nota principal en MAYÚSCULAS y bemol en minúscula 'b' (ej: /DO, /C, /REb, /Db)
      String cleanBass = formattedBass;
      if (cleanBass.isNotEmpty) {
        if (cleanBass.endsWith('b')) {
          final noteName = cleanBass.substring(0, cleanBass.length - 1).toUpperCase();
          cleanBass = '${noteName}b';
        } else {
          cleanBass = cleanBass.toUpperCase();
        }
      }
      
      return '$formattedMain/$cleanBass';
    }

    return _convertSingleChordToken(chord, targetNotation);
  }

  static String _convertSingleChordToken(String chord, String targetNotation) {
    final trimmed = chord.trim();
    if (trimmed.isEmpty) return trimmed;

    final Map<String, String> toAmerican = {
      'DO': 'C', 'RE': 'D', 'MI': 'E', 'FA': 'F', 'SOL': 'G', 'LA': 'A', 'SI': 'B'
    };

    final Map<String, String> toSpanish = {
      'C': 'DO', 'D': 'RE', 'E': 'MI', 'F': 'FA', 'G': 'SOL', 'A': 'LA', 'B': 'SI'
    };

    final RegExp spanishNoteRegex = RegExp(
      r'^(DO#|DO|RE#|REb|REB|RE|MI#|MIb|MIB|MI|FA#|FA|SOL#|SOLb|SOLB|SOL|LA#|LAb|LAB|LA|SI#|SIb|SIB|SI)',
      caseSensitive: false
    );
    final RegExp englishNoteRegex = RegExp(
      r'^(C#|Db|DB|D#|Eb|EB|E|F#|Gb|GB|G#|Ab|AB|A#|Bb|BB|B|C|D|F|G|A)',
      caseSensitive: false
    );

    String rootNote = '';
    String suffix = '';

    final spanishMatch = spanishNoteRegex.firstMatch(trimmed);
    final englishMatch = englishNoteRegex.firstMatch(trimmed);

    if (targetNotation == 'american') {
      if (spanishMatch != null) {
        final matchText = spanishMatch.group(1)!;
        suffix = trimmed.substring(matchText.length);

        String base = matchText.toUpperCase();
        String accidental = '';
        if (base.endsWith('#')) {
          base = base.substring(0, base.length - 1);
          accidental = '#';
        } else if (base.endsWith('B')) {
          base = base.substring(0, base.length - 1);
          accidental = 'b';
        }

        final americanBase = toAmerican[base];
        if (americanBase != null) {
          rootNote = '$americanBase$accidental';
        } else {
          rootNote = matchText.toUpperCase();
        }
      } else if (englishMatch != null) {
        final matchText = englishMatch.group(1)!;
        suffix = trimmed.substring(matchText.length);

        String base = matchText.substring(0, 1).toUpperCase();
        String accidental = matchText.length > 1 ? matchText.substring(1).toLowerCase() : '';
        rootNote = '$base$accidental';
      } else {
        return trimmed;
      }
    } else {
      // Latino (Español)
      if (spanishMatch != null) {
        final matchText = spanishMatch.group(1)!;
        suffix = trimmed.substring(matchText.length);

        String base = matchText.toUpperCase();
        String accidental = '';
        if (base.endsWith('#')) {
          base = base.substring(0, base.length - 1);
          accidental = '#';
        } else if (base.endsWith('B')) {
          base = base.substring(0, base.length - 1);
          accidental = 'b';
        }

        final standardBase = toSpanish[toAmerican[base] ?? base] ?? base;
        rootNote = '$standardBase$accidental';
      } else if (englishMatch != null) {
        final matchText = englishMatch.group(1)!;
        suffix = trimmed.substring(matchText.length);

        String base = matchText.substring(0, 1).toUpperCase();
        String accidental = matchText.length > 1 ? matchText.substring(1).toLowerCase() : '';

        final spanishBase = toSpanish[base];
        if (spanishBase != null) {
          rootNote = '$spanishBase$accidental';
        } else {
          rootNote = matchText.toUpperCase();
        }
      } else {
        return trimmed;
      }
    }

    // Regla de minúsculas para la compañía del acorde (sufijos: m, sus4, sus2, add9, m7(b5), etc.)
    final formattedSuffix = suffix.toLowerCase();

    // Validar que el resultado no sea solo basura antes de aplicar formato
    if (rootNote.isEmpty) return trimmed;

    return '$rootNote$formattedSuffix';
  }

  static String formatToneDisplay(String originalTone, String notation) {
    String clean = originalTone.replaceAll(RegExp(r'^TONO:\s*', caseSensitive: false), '').trim();
    if (clean.isEmpty) return '';

    final components = parseToneComponents(clean);
    final toneNote = components['toneNote'] ?? '';
    final beats = components['beats'] ?? '';
    final timeSignature = components['timeSignature'] ?? '';

    if (toneNote.isEmpty && beats.isEmpty && timeSignature.isEmpty) {
      return clean
          .replaceAll(RegExp(r'\s*\|\s*'), '  /  ')
          .replaceAll(RegExp(r'\s+/\s+'), '  /  ')
          .trim();
    }

    final convertedNote = toneNote.isNotEmpty ? convertChordNotation(toneNote, notation) : '';
    return buildToneString(
      toneNote: convertedNote,
      beats: beats,
      timeSignature: timeSignature,
    );
  }

  static Map<String, String> parseToneComponents(String rawTone) {
    String clean = rawTone.replaceAll(RegExp(r'^TONO:\s*', caseSensitive: false), '').trim();
    if (clean.isEmpty) return {'toneNote': '', 'beats': '', 'timeSignature': ''};

    String timeSignature = '';
    String beats = '';
    String toneNote = '';

    final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(clean);
    if (parenMatch != null) {
      timeSignature = parenMatch.group(1)!.replaceAll('|', '/').replaceAll(' ', '').trim();
      clean = clean.replaceFirst(parenMatch.group(0)!, '').trim();
    } else {
      final tsMatch = RegExp(r'(\d+\s*[/|]\s*\d+)').firstMatch(clean);
      if (tsMatch != null) {
        timeSignature = tsMatch.group(1)!.replaceAll('|', '/').replaceAll(' ', '').trim();
        clean = clean.replaceFirst(tsMatch.group(0)!, '').trim();
      }
    }

    final timesMatch = RegExp(r'(\d+)\s*(?:TIEMPOS|TIEMPO|T)?', caseSensitive: false).firstMatch(clean);
    if (timesMatch != null) {
      final possibleBeats = timesMatch.group(1)!;
      if (RegExp(r'TIEMPOS?|T\b', caseSensitive: false).hasMatch(clean)) {
        beats = possibleBeats;
        clean = clean.replaceFirst(RegExp(r'(\d+)\s*(?:TIEMPOS|TIEMPO|T)?', caseSensitive: false), '').trim();
      }
    }

    toneNote = clean
        .replaceAll('|', '')
        .replaceAll('/', '')
        .replaceAll(RegExp(r'\bTIEMPOS?\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (beats.isEmpty && timesMatch != null) {
      final possible = timesMatch.group(1)!;
      if (toneNote.contains(possible)) {
        final toneWithoutDigits = toneNote.replaceAll(RegExp(r'\d+'), '').trim();
        if (toneWithoutDigits.isNotEmpty) {
          beats = possible;
          toneNote = toneWithoutDigits;
        }
      }
    }

    String cleanNote = toneNote.trim();
    String suffix = '';

    // Extraer sufijos armónicos conocidos antes de procesar la nota tónica
    final suffixRegex = RegExp(r'(m7b5|m7\(b5\)|m7|m9|m11|dim7|dim|sus4|sus2|add9|aug|maj7|m|\+|-|\d+)$', caseSensitive: false);
    final matchSuffix = suffixRegex.firstMatch(cleanNote);
    if (matchSuffix != null && !cleanNote.toUpperCase().endsWith('MAYOR') && !cleanNote.toUpperCase().endsWith('MAJOR')) {
      suffix = matchSuffix.group(1)!.toLowerCase();
      cleanNote = cleanNote.substring(0, cleanNote.length - matchSuffix.group(1)!.length).trim();
    }

    if (RegExp(r'\b(MENOR|MINOR)\b', caseSensitive: false).hasMatch(cleanNote)) {
      if (suffix.isEmpty) suffix = 'm';
    }

    cleanNote = cleanNote.replaceAll(RegExp(r'\b(MAYOR|MAJOR|MENOR|MINOR)\b', caseSensitive: false), '').trim();

    // Procesar la nota raíz respetando bemol en minúscula (b) y sostenido (#)
    String rootNote = cleanNote;
    if (rootNote.isNotEmpty) {
      if (rootNote.toLowerCase().endsWith('b') && rootNote.length > 1) {
        rootNote = '${rootNote.substring(0, rootNote.length - 1).toUpperCase()}b';
      } else {
        rootNote = rootNote.toUpperCase();
      }
    }

    String finalNote = '$rootNote$suffix';

    return {
      'toneNote': finalNote,
      'beats': beats,
      'timeSignature': timeSignature,
    };
  }

  static String buildToneString({
    required String toneNote,
    required String beats,
    required String timeSignature,
  }) {
    final cleanTone = toneNote.trim();
    final cleanBeats = beats.trim();
    final cleanSignature = timeSignature.replaceAll('|', '/').trim();

    if (cleanTone.isEmpty && cleanBeats.isEmpty && cleanSignature.isEmpty) return '';

    final buffer = StringBuffer();
    if (cleanTone.isNotEmpty) buffer.write(cleanTone);

    if (cleanBeats.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('  /  ');
      buffer.write('$cleanBeats TIEMPOS');
    }

    if (cleanSignature.isNotEmpty) {
      if (buffer.isNotEmpty) {
        if (cleanBeats.isNotEmpty) {
          buffer.write(' ($cleanSignature)');
        } else {
          buffer.write('  /  $cleanSignature');
        }
      } else {
        buffer.write(cleanSignature);
      }
    }

    return buffer.toString();
  }
}

// Notifier para el modo Administrador
class AdminModeNotifier extends Notifier<bool> {
  static const _prefsKey = 'admin_mode_active';

  @override
  bool build() {
    _loadAdminMode();
    return false;
  }

  Future<void> _loadAdminMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_prefsKey) ?? false;
    final currentUser = FirebaseAuth.instance.currentUser;
    Future.microtask(() {
      state = isActive && currentUser != null && currentUser.email == 'admin@himnario.com';
    });
  }

  Future<bool> verifyAndActivate(String password) async {
    if (password == 'himnario2026') {
      try {
        // Iniciar sesión en Firebase con el correo admin oficial
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: 'admin@himnario.com',
          password: password,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsKey, true);
        state = true;
        return true;
      } catch (e) {
        debugPrint('>>> Error al iniciar sesión en Firebase: $e');
        return false;
      }
    }
    return false;
  }

  Future<void> deactivate() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, false);
    state = false;
  }
}

final adminModeProvider = NotifierProvider<AdminModeNotifier, bool>(() {
  return AdminModeNotifier();
});

// Notifier para manejar todos los himnos por colección
class HymnsNotifier extends AsyncNotifier<List<Hymn>> {
  final String collection;

  HymnsNotifier(this.collection);

  @override
  Future<List<Hymn>> build() async {
    final firestore = FirebaseFirestore.instance;

    // 1. Cargar los cantos locales embebidos de inmediato (0.01s)
    final baseHymns = await _loadBaseHymns(collection);

    // 2. Suscribirse a actualizaciones de Firestore en segundo plano
    final subscription = firestore.collection(collection).snapshots().listen(
      (snapshot) async {
        if (snapshot.metadata.hasPendingWrites && state.hasValue) {
          return;
        }

        if (snapshot.docs.isEmpty) return;

        final List<Hymn> list = snapshot.docs.map((doc) {
          final data = doc.data();
          return Hymn.fromJson(data, collection);
        }).toList();

        // Mezclar cantos locales creados por el usuario
        final localHymnsRaw = await LocalHymnStorageService.getCustomHymns();
        final localHymns = localHymnsRaw
            .where((h) => h['collection'] == collection)
            .map((h) => Hymn(
                  id: h['id'],
                  title: h['title'],
                  toneNote: h['key'] ?? '',
                  beats: '',
                  timeSignature: '',
                  lyrics: h['lyrics'],
                  collection: h['collection'],
                  category: '',
                  isLocalOnly: true,
                ))
            .toList();
        
        list.addAll(localHymns);

        if (collection == 'iump') {
          list.sort((a, b) => a.id.compareTo(b.id));
        } else {
          list.sort((a, b) => a.title.compareTo(b.title));
        }

        state = AsyncValue.data(list);
        ref.read(databaseStatusProvider.notifier).setStatus('Conectado');
      },
      onError: (error) {
        debugPrint('>>> Error en stream de Firestore: $error');
        ref.read(databaseStatusProvider.notifier).setStatus('Offline: $error');
      },
    );

    ref.onDispose(() {
      subscription.cancel();
    });

    return baseHymns;
  }

  Future<void> _migrateFirestoreCollection() async {
    final firestore = FirebaseFirestore.instance;
    try {
      final baseHymns = await _loadBaseHymns(collection);
      final baseMap = {for (var h in baseHymns) h.id: h};

      final snapshot = await firestore.collection(collection).get();
      final batch = firestore.batch();
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = data['id'] as int? ?? int.tryParse(doc.id) ?? 0;
        final base = baseMap[id];
        if (base != null) {
          final cloudLyrics = data['lyrics'] as String? ?? '';
          final existingNote = data['toneNote'] as String?;
          
          bool needsUpdate = false;
          final Map<String, dynamic> updates = {};

          if (existingNote == null || existingNote.isEmpty) {
            updates['toneNote'] = base.toneNote;
            updates['beats'] = base.beats;
            updates['timeSignature'] = base.timeSignature;
            updates['tone'] = base.tone;
            needsUpdate = true;
          }

          if (cloudLyrics.length > 30 && !cloudLyrics.contains('\n') && base.lyrics.contains('\n')) {
            updates['lyrics'] = base.lyrics;
            needsUpdate = true;
          }

          if (needsUpdate) {
            batch.update(doc.reference, updates);
            count++;
          }
        }
      }
      if (count > 0) {
        await batch.commit();
        debugPrint('>>> Sincronizados $count cantos en Firestore Cloud DB ($collection)');
      }
    } catch (e) {
      debugPrint('>>> Error al migrar colección $collection en Firestore: $e');
    }
  }

  static final Map<String, List<Hymn>> _staticCache = {};

  static List<Hymn> getCachedBaseHymns(String collection) {
    return _staticCache[collection] ?? const [];
  }

  static Future<void> preloadAssets() async {
    for (final coll in ['iump', 'especiales', 'coros']) {
      String path;
      if (coll == 'especiales') {
        path = 'assets/json/special_hymns.json';
      } else if (coll == 'coros') {
        path = 'assets/json/coros.json';
      } else {
        path = 'assets/json/hymns.json';
      }
      try {
        final jsonString = await rootBundle.loadString(path);
        final List<dynamic> jsonList = json.decode(jsonString);
        _staticCache[coll] = jsonList.map((j) => Hymn.fromJson(j, coll)).toList();
      } catch (e) {
        debugPrint('>>> Error al precargar asset $path: $e');
      }
    }
  }

  Future<List<Hymn>> _loadBaseHymns(String collection) async {
    if (_staticCache.containsKey(collection) && _staticCache[collection]!.isNotEmpty) {
      return List<Hymn>.from(_staticCache[collection]!);
    }

    String path;
    if (collection == 'especiales') {
      path = 'assets/json/special_hymns.json';
    } else if (collection == 'coros') {
      path = 'assets/json/coros.json';
    } else {
      path = 'assets/json/hymns.json';
    }
    
    final jsonString = await rootBundle.loadString(path);
    final List<dynamic> jsonList = json.decode(jsonString);
    final list = jsonList.map((json) => Hymn.fromJson(json, collection)).toList();
    _staticCache[collection] = list;
    return List<Hymn>.from(list);
  }

  // Guardar (Crear o Editar)
  Future<void> saveHymn({
    required int id,
    required String title,
    required String toneNote,
    required String beats,
    required String timeSignature,
    required String lyrics,
    required bool isNew,
    String? audioUrl,
    String? category,
    List<String>? sheetMusicUrls,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final formattedLyrics = Hymn.formatLyricsForSaving(lyrics, collection);
    final cleanToneNote = toneNote.trim();
    final fullTone = Hymn.buildToneString(
      toneNote: cleanToneNote,
      beats: beats.trim(),
      timeSignature: timeSignature.trim(),
    );
    final data = {
      'id': id,
      'title': title.trim().toUpperCase(),
      'toneNote': cleanToneNote,
      'beats': beats.trim(),
      'timeSignature': timeSignature.trim(),
      'tone': fullTone,
      'lyrics': formattedLyrics,
      'collection': collection,
      'audioUrl': audioUrl ?? '',
      'category': category ?? '',
      'sheetMusicUrls': sheetMusicUrls ?? [],
    };
    
    // Actualización optimista inmediata en memoria (0 ms)
    final updatedHymn = Hymn(
      id: id,
      title: title.trim().toUpperCase(),
      toneNote: cleanToneNote,
      beats: beats.trim(),
      timeSignature: timeSignature.trim(),
      lyrics: formattedLyrics,
      collection: collection,
      audioUrl: audioUrl ?? '',
      category: category ?? '',
      sheetMusicUrls: sheetMusicUrls ?? [],
    );

    if (state.hasValue) {
      final currentList = List<Hymn>.from(state.value!);
      currentList.removeWhere((h) => h.id == id);
      currentList.add(updatedHymn);
      if (collection == 'iump') {
        currentList.sort((a, b) => a.id.compareTo(b.id));
      } else {
        currentList.sort((a, b) => a.title.compareTo(b.title));
      }
      state = AsyncValue.data(currentList);
    }

    // Persistir en Firestore en segundo plano (sin bloquear la interfaz)
    firestore.collection(collection).doc(id.toString()).set(data).then((_) {
      ref.read(databaseStatusProvider.notifier).setStatus('Conectado');
    }).catchError((e) {
      ref.read(databaseStatusProvider.notifier).setStatus('Offline: $e');
    });
    
    // Escribir en caliente al archivo local en modo debug de desarrollo
    if (!kIsWeb && kDebugMode) {
      await _syncToSourceFile();
    }
  }

  // Eliminar
  Future<void> deleteHymn(int id) async {
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.collection(collection).doc(id.toString()).delete();
      ref.read(databaseStatusProvider.notifier).setStatus('Conectado');
    } catch (e) {
      ref.read(databaseStatusProvider.notifier).setStatus('Offline: $e');
      rethrow;
    }
    
    if (!kIsWeb && kDebugMode) {
      await _syncToSourceFile();
    }
  }

  // Trasladar/Mover a otro contenedor
  Future<void> moveHymnTo(Hymn hymn, String targetCollection) async {
    final firestore = FirebaseFirestore.instance;
    
    // Forzar carga de la colección de destino para tener la lista de cantos actualizada
    final targetHymns = await ref.read(hymnsProvider(targetCollection).future);
    
    int nextId = 1;
    if (targetHymns.isNotEmpty) {
      nextId = targetHymns.map((h) => h.id).reduce((a, b) => a > b ? a : b) + 1;
    }
    
    final formattedLyrics = Hymn.formatLyricsForSaving(hymn.lyrics, targetCollection);
    final cleanToneNote = hymn.toneNote.trim();
    final fullTone = Hymn.buildToneString(
      toneNote: cleanToneNote,
      beats: hymn.beats.trim(),
      timeSignature: hymn.timeSignature.trim(),
    );
    final data = {
      'id': nextId,
      'title': hymn.title.trim().toUpperCase(),
      'toneNote': cleanToneNote,
      'beats': hymn.beats.trim(),
      'timeSignature': hymn.timeSignature.trim(),
      'tone': fullTone,
      'lyrics': formattedLyrics,
      'collection': targetCollection,
      'audioUrl': hymn.audioUrl,
      'sheetMusicUrls': hymn.sheetMusicUrls,
    };
    
    try {
      // Escribir en la colección destino
      await firestore.collection(targetCollection).doc(nextId.toString()).set(data);
      
      // Eliminar de la colección origen
      await firestore.collection(collection).doc(hymn.id.toString()).delete();
      
      ref.read(databaseStatusProvider.notifier).setStatus('Conectado');
    } catch (e) {
      ref.read(databaseStatusProvider.notifier).setStatus('Offline: $e');
      rethrow;
    }
    
    // Sincronizar en caliente localmente si estamos en modo debug
    if (!kIsWeb && kDebugMode) {
      await _syncToSourceFile();
      // Obtener el notifier de destino y sincronizar su archivo local
      final targetNotifier = ref.read(hymnsProvider(targetCollection).notifier);
      await targetNotifier._syncToSourceFile();
    }
  }

  // Sincronización directa al archivo del proyecto en macOS
  Future<void> _syncToSourceFile() async {
    try {
      final hymnsList = state.value;
      if (hymnsList == null) return;
      
      String filename;
      if (collection == 'especiales') {
        filename = 'special_hymns.json';
      } else if (collection == 'coros') {
        filename = 'coros.json';
      } else {
        filename = 'hymns.json';
      }
      
      final path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/assets/json/$filename';
      final file = File(path);
      if (await file.exists()) {
        final List<Hymn> sortedList = List.from(hymnsList);
        if (collection == 'iump') {
          sortedList.sort((a, b) => a.id.compareTo(b.id));
        } else {
          sortedList.sort((a, b) => a.title.compareTo(b.title));
        }

        final jsonList = sortedList.map((h) => h.toJson()).toList();
        final encoder = const JsonEncoder.withIndent('  ');
        final jsonString = encoder.convert(jsonList);
        await file.writeAsString(jsonString);
        debugPrint('>>> Sincronización exitosa: Archivo $path actualizado.');
      }
    } catch (e) {
      debugPrint('>>> Error al escribir archivo fuente JSON: $e');
    }
  }
}

class DatabaseStatusNotifier extends Notifier<String> {
  @override
  String build() => 'Conectado';

  void setStatus(String status) {
    state = status;
  }
}

final databaseStatusProvider = NotifierProvider<DatabaseStatusNotifier, String>(() {
  return DatabaseStatusNotifier();
});

final hymnsProvider = AsyncNotifierProvider.family<HymnsNotifier, List<Hymn>, String>((collection) {
  return HymnsNotifier(collection);
});
