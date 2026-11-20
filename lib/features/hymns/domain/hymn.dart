import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/local_hymn_storage_service.dart';
import '../../../core/services/suggestion_tracking_service.dart';

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

  static Future<void> _preloadSingle(String coll, String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final List<dynamic> jsonList = json.decode(jsonString);
      _staticCache[coll] = jsonList.map((j) => Hymn.fromJson(j, coll)).toList();
    } catch (e) {
      debugPrint('>>> Error al precargar asset $path: $e');
    }
  }

  static Future<void> preloadAssets() async {
    await Future.wait([
      _preloadSingle('iump', 'assets/json/hymns.json'),
      _preloadSingle('especiales', 'assets/json/special_hymns.json'),
      _preloadSingle('coros', 'assets/json/coros.json'),
    ]);
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

  bool get isYoutube =>
      audioUrl.contains('youtube.com') || audioUrl.contains('youtu.be');

  bool get hasAudioFile =>
      audioUrl.trim().isNotEmpty && !isYoutube;

  bool get hasYoutube =>
      audioUrl.trim().isNotEmpty && isYoutube;

  bool get hasSheetMusic => sheetMusicUrls.isNotEmpty;

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
    } else if (toneNote.isNotEmpty) {
      toneNote = Hymn.normalizeToneNote(toneNote);
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

  static String formatLineCasing(String line, {bool preserveInnerCase = false}) {
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
    if (!preserveInnerCase && testStr.length > 3 && testStr == testStr.toUpperCase() && !testStr.startsWith('CORO') && !testStr.startsWith('PUENTE')) {
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
    
    // Si la línea ya fue procesada por la IA con análisis contextual gramatical,
    // se preservan las mayúsculas/minúsculas internas intactas y no se aplican reemplazos ciegos
    if (!preserveInnerCase) {
      final List<String> wordsToCapitalize = [
        'hijo de dios', 'hijo del hombre', 'padre celestial', 'padre nuestro', 'padre santo', 'santo padre', 'dios padre',
        'dios', 'jesús', 'jesus', 'cristo', 'jesucristo', 'nazareno', 'maestro', 
        'señor', 'senor', 'salvador', 'redentor', 'mesías', 'mesias', 'jehová', 
        'jehova', 'emanuel', 'shalom', 'espíritu santo', 'espiritu santo',
        'rey de reyes', 'rey de gloria', 'cristo rey',
        'jerusalén', 'jerusalen', 'sión', 'sion', 'marta', 
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
        'oh', 'amén', 'amen', 'aleluya'
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
    }
    
    for (int i = 0; i < chords.length; i++) {
      formattedText = formattedText.replaceFirst('___${i}___', '[${chords[i]}]');
    }
    
    return formattedText;
  }

  /// Detecta con precisión si una línea comienza con una etiqueta estructural real
  /// (CORO, CORO 1..10, SOLISTA, PUENTE, TODOS, HOMBRES, MUJERES, SOLO, FINAL, etc.)
  /// sin confundir versos cotidianos en español como "Todos oímos resonar" o "Solo en Jesús".
  static ({String header, String rest})? matchStructuralHeader(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    // 1. Etiquetas musicales inequívocas (con o sin número / romano / FINAL)
    final unambiguousRe = RegExp(
      r'^(CORO(?:\s+(?:\d+|[IVXivx]+|FINAL))?|PRE-?CORO|ESTRIBILLO|SOLISTA(?:\s+\d+)?|INTERLUDIO|INTRODUCCIÓN|INTRODUCCION|INTRO|OUTRO|CODA)(?:(\s*[:\-]\s*)|\s+|$)(.*)$',
      caseSensitive: false,
    );
    final uMatch = unambiguousRe.firstMatch(trimmed);
    if (uMatch != null) {
      final rawTag = uMatch.group(1)!.trim();
      final delim = (uMatch.group(2) ?? '').trim();
      final rest = (uMatch.group(3) ?? '').trim();

      if (rest.isEmpty) {
        return (header: rawTag.toUpperCase(), rest: '');
      }
      final hasQualifier = rawTag.contains(' ');
      final isAllCaps = rawTag == rawTag.toUpperCase();
      if (delim.isNotEmpty || hasQualifier || isAllCaps) {
        return (header: rawTag.toUpperCase(), rest: rest);
      }
      return null;
    }

    // 2. Etiquetas que también son palabras cotidianas en español
    //    (TODOS, HOMBRES, MUJERES, SOLO, FINAL, PUENTE)
    final ambiguousRe = RegExp(
      r'^(TODOS|HOMBRES|MUJERES|SOLO|FINAL|PUENTE(?:\s+\d+)?)(?:(\s*[:\-]\s*)|\s+|$)(.*)$',
      caseSensitive: false,
    );
    final aMatch = ambiguousRe.firstMatch(trimmed);
    if (aMatch != null) {
      final rawTag = aMatch.group(1)!.trim();
      final delim = (aMatch.group(2) ?? '').trim();
      final rest = (aMatch.group(3) ?? '').trim();
      final hasQualifier = rawTag.contains(' ');
      final isAllCaps = rawTag == rawTag.toUpperCase();

      if (rest.isEmpty) {
        // Sola en su propia línea: válida en MAYÚSCULAS (como inserta la barra rápida: "TODOS"),
        // con delimitador explícito ("Todos:") o numerada ("Puente 1").
        if (isAllCaps || delim.isNotEmpty || hasQualifier) {
          return (header: rawTag.toUpperCase(), rest: '');
        }
        return null;
      }

      // Con texto en la misma línea: exige delimitador explícito ":" o "-" (ej. "Todos: Aleluya")
      // o número explícito ("Puente 1 ..."). Jamás parte versos como "Todos oímos resonar".
      if (delim.isNotEmpty || hasQualifier) {
        return (header: rawTag.toUpperCase(), rest: rest);
      }
      return null;
    }

    return null;
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

    for (final line in lines) {
      final trimmed = line.trim();

      final structMatch = matchStructuralHeader(trimmed);
      if (structMatch != null) {
        resultLines.add(structMatch.header);
        if (structMatch.rest.isNotEmpty) {
          resultLines.add(structMatch.rest);
        }
        continue;
      }

      final verseMatch = verseInlineHeader.firstMatch(trimmed);
      if (verseMatch != null) {
        final header = verseMatch.group(1)!.trim();
        final rest = verseMatch.group(2)!.trim();
        
        // Falso positivo con la palabra "Vi" (verbo ver) en lugar del número romano VI.
        if (header.toLowerCase() == 'vi') {
          // Si es exactamente "vi" sin punto ni guion, lo tratamos como letra normal.
          resultLines.add(trimmed);
          continue;
        }
        
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
      if (standaloneMatch != null && trimmed.length <= 15 && trimmed.toLowerCase() != 'vi') {
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
    final List<String> formattedBlocks = [];
    for (final block in blocks) {
      final trimmedBlock = block.trim();
      if (trimmedBlock.isEmpty) continue;

      final lines = trimmedBlock.split('\n');
      final formattedLines = lines.map((l) {
        final structMatch = matchStructuralHeader(l);
        if (structMatch != null && structMatch.rest.isEmpty) {
          // Mantener las etiquetas estructurales reales (CORO, TODOS, HOMBRES, PUENTE, etc.) en MAYÚSCULAS
          return structMatch.header;
        }
        return formatLineCasing(l);
      }).toList();

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
    if (semitones == 0) return normalizeToneNote(chord);

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
        return normalizeToneNote('$formattedNote$suffix');
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
        return normalizeToneNote('$formattedNote$suffix');
      }
    }

    return normalizeToneNote(cleaned); // Devolver normalizado si no coincide
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

    // Regla de normalización de sufijos armónicos:
    // 1. Quitar 'MAYOR', 'MAJOR' o 'M' mayúscula sola (los acordes mayores no llevan apellido)
    suffix = suffix.replaceAll(RegExp(r'\b(MAYOR|MAJOR)\b', caseSensitive: false), '').trim();
    if (suffix == 'M' || suffix == ' M') {
      suffix = '';
    }

    // 2. Convertir 'MENOR' o 'MINOR' a 'm' en minúscula (los acordes menores siempre llevan apellido en minúscula)
    suffix = suffix.replaceAll(RegExp(r'\b(MENOR|MINOR)\b', caseSensitive: false), 'm').trim();

    // 3. Sufijo armónico en minúsculas (m, sus4, add9, maj7, etc.)
    final formattedSuffix = suffix.toLowerCase().trim();

    // Validar que el resultado no sea solo basura antes de aplicar formato
    if (rootNote.isEmpty) return trimmed;

    return '$rootNote$formattedSuffix';
  }

  /// Normaliza una nota musical o acorde según la regla oficial del himnario:
  /// - Los acordes mayores NO llevan apellido (ej: SOL MAYOR -> SOL, DO M -> DO).
  /// - Los acordes menores SIEMPRE llevan apellido y siempre en minúscula (ej: LA MENOR -> LAm, LAm -> LAm).
  /// - Tónicas en mayúsculas, bemol en minúscula 'b' y sostenido '#'.
  static String normalizeToneNote(String rawNote) {
    final trimmed = rawNote.trim();
    if (trimmed.isEmpty) return '';

    // Manejo de bajo alternativo (Slash chord) ej: DOm/SOL, SOL MAYOR/SI
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      final main = normalizeToneNote(parts[0]);
      final bass = normalizeToneNote(parts[1]);
      return '$main/$bass';
    }

    final RegExp spanishNoteRegex = RegExp(
      r'^(DO#|DO|RE#|REb|REB|RE|MI#|MIb|MIB|MI|FA#|FA|SOL#|SOLb|SOLB|SOL|LA#|LAb|LAB|LA|SI#|SIb|SIB|SI)',
      caseSensitive: false,
    );
    final RegExp englishNoteRegex = RegExp(
      r'^(C#|Db|DB|D#|Eb|EB|E|F#|Gb|GB|G#|Ab|AB|A#|Bb|BB|B|C|D|F|G|A)',
      caseSensitive: false,
    );

    String rootNote = '';
    String suffix = '';

    final spanishMatch = spanishNoteRegex.firstMatch(trimmed);
    final englishMatch = englishNoteRegex.firstMatch(trimmed);

    if (spanishMatch != null) {
      final matchText = spanishMatch.group(1)!;
      suffix = trimmed.substring(matchText.length);

      String base = matchText.toUpperCase();
      if (base.endsWith('B')) {
        base = '${base.substring(0, base.length - 1)}b';
      }
      rootNote = base;
    } else if (englishMatch != null) {
      final matchText = englishMatch.group(1)!;
      suffix = trimmed.substring(matchText.length);

      String base = matchText.substring(0, 1).toUpperCase();
      String accidental = matchText.length > 1 ? matchText.substring(1).toLowerCase() : '';
      rootNote = '$base$accidental';
    } else {
      return trimmed;
    }

    // 1. Quitar 'MAYOR', 'MAJOR' o 'M' mayúscula de Mayor
    suffix = suffix.replaceAll(RegExp(r'\b(MAYOR|MAJOR)\b', caseSensitive: false), '').trim();
    if (suffix == 'M' || suffix == ' M') {
      suffix = '';
    }

    // 2. Convertir 'MENOR' o 'MINOR' a 'm' en minúscula
    suffix = suffix.replaceAll(RegExp(r'\b(MENOR|MINOR)\b', caseSensitive: false), 'm').trim();

    // 3. Sufijo armónico en minúsculas
    final formattedSuffix = suffix.toLowerCase().trim();

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

    final String finalNote = normalizeToneNote(toneNote);

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
    final cleanTone = normalizeToneNote(toneNote.trim());
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

  /// Retorna la lista de categorías válidas para la colección dada.
  static List<Map<String, String>> categoriesForCollection(String collection) {
    if (collection == 'especiales') {
      return const [
        {'id': '', 'name': 'Sin Categoría / Ninguna'},
        {'id': 'Coro Nacional', 'name': 'Coro Nacional'},
        {'id': 'Coros Unidos', 'name': 'Coros Unidos'},
      ];
    } else if (collection == 'coros') {
      return const [
        {'id': '', 'name': 'Sin Categoría / Ninguna'},
        {'id': 'Con Acordes', 'name': 'Con Acordes'},
        {'id': 'DO', 'name': 'Tono DO'},
        {'id': 'RE', 'name': 'Tono RE'},
        {'id': 'MI', 'name': 'Tono MI'},
        {'id': 'FA', 'name': 'Tono FA'},
        {'id': 'SOL', 'name': 'Tono SOL'},
        {'id': 'LA', 'name': 'Tono LA'},
        {'id': 'SI', 'name': 'Tono SI'},
        {'id': 'Menores', 'name': 'Ritmo / Modo Menor'},
      ];
    }
    return const [
      {'id': '', 'name': 'Sin Categoría / Ninguna'},
      {'id': 'Predicación', 'name': 'Predicación'},
      {'id': 'Adoración', 'name': 'Adoración'},
      {'id': 'Consagración', 'name': 'Consagración'},
      {'id': 'Santa Cena', 'name': 'Santa Cena'},
      {'id': 'Coritos', 'name': 'Coritos'},
      {'id': 'Fúnebre', 'name': 'Fúnebre'},
      {'id': 'Navidad', 'name': 'Navidad'},
    ];
  }

  /// Detecta si una letra nueva coincide en >80% (por trigramas) con algún canto existente.
  static Hymn? findPossibleDuplicate(String newLyrics, List<Hymn> existingHymns) {
    String normalize(String s) =>
        s.replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ]'), '').toLowerCase();

    final cleanNew = normalize(newLyrics);
    if (cleanNew.length < 20) return null;

    Set<String> trigramsOf(String str) {
      final result = <String>{};
      for (int i = 0; i <= str.length - 3; i++) {
        result.add(str.substring(i, i + 3));
      }
      return result;
    }

    final newTrigrams = trigramsOf(cleanNew);
    if (newTrigrams.isEmpty) return null;

    for (final hymn in existingHymns) {
      final cleanExisting = normalize(hymn.lyrics);
      if (cleanExisting.length < 20) continue;
      if (cleanNew.contains(cleanExisting) || cleanExisting.contains(cleanNew)) {
        return hymn;
      }
      final existingTrigrams = trigramsOf(cleanExisting);
      if (existingTrigrams.isEmpty) continue;
      int intersection = 0;
      for (final t in newTrigrams) {
        if (existingTrigrams.contains(t)) intersection++;
      }
      final similarity = (2.0 * intersection) / (newTrigrams.length + existingTrigrams.length);
      if (similarity > 0.8) return hymn;
    }
    return null;
  }

  /// Combina una nota musical con su modo ('Mayor' o 'Menor').
  static String applyToneMode(String toneNote, String mode) {
    final trimmed = toneNote.trim();
    if (trimmed.isEmpty) return '';
    String root = trimmed.toUpperCase();
    if (root.endsWith('M') && !root.endsWith('MI')) {
      root = root.substring(0, root.length - 1);
    }
    return mode == 'Menor' ? '${root}m' : root;
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

  Future<List<Hymn>> _mergeLocalCustomHymns(List<Hymn> baseList) async {
    final list = List<Hymn>.from(baseList);
    final localHymnsRaw = await LocalHymnStorageService.getCustomHymns();
    final localHymns = localHymnsRaw
        .where((h) => h['collection'] == collection)
        .map((h) => Hymn(
              id: h['id'],
              title: h['title'],
              toneNote: h['key'] ?? '',
              beats: h['beats'] ?? '',
              timeSignature: h['timeSignature'] ?? '',
              lyrics: h['lyrics'],
              collection: h['collection'],
              category: h['category'] ?? '',
              isLocalOnly: true,
            ))
        .toList();

    list.addAll(localHymns);
    if (collection == 'iump') {
      list.sort((a, b) => a.id.compareTo(b.id));
    } else {
      list.sort((a, b) => a.title.compareTo(b.title));
    }
    return list;
  }

  @override
  Future<List<Hymn>> build() async {
    final firestore = FirebaseFirestore.instance;

    // 1. Cargar los cantos locales embebidos + personalizados locales de inmediato (0.01s)
    final baseHymns = await _loadBaseHymns(collection);
    final initialWithLocals = await _mergeLocalCustomHymns(baseHymns);

    // 2. Suscribirse a actualizaciones de Firestore en segundo plano
    final subscription = firestore.collection(collection).snapshots().listen(
      (snapshot) async {
        if (snapshot.metadata.hasPendingWrites && state.hasValue) {
          return;
        }

        if (snapshot.docs.isEmpty) return;

        final List<Hymn> firestoreList = snapshot.docs.map((doc) {
          final data = doc.data();
          return Hymn.fromJson(data, collection);
        }).toList();

        final merged = await _mergeLocalCustomHymns(firestoreList);
        state = AsyncValue.data(merged);
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

    return initialWithLocals;
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

  static Future<void> _preloadSingle(String coll, String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      final List<dynamic> jsonList = json.decode(jsonString);
      _staticCache[coll] = jsonList.map((j) => Hymn.fromJson(j, coll)).toList();
    } catch (e) {
      debugPrint('>>> Error al precargar asset $path: $e');
    }
  }

  static Future<void> preloadAssets() async {
    await Future.wait([
      _preloadSingle('iump', 'assets/json/hymns.json'),
      _preloadSingle('especiales', 'assets/json/special_hymns.json'),
      _preloadSingle('coros', 'assets/json/coros.json'),
    ]);
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

  /// Calcula el ID oficial disponible (ignorando IDs locales) y publica un nuevo canto en Firestore.
  Future<int> publishNewOfficialHymn({
    required String title,
    required String toneNote,
    required String beats,
    required String timeSignature,
    required String lyrics,
    int? explicitId,
    String? audioUrl,
    String? category,
    List<String>? sheetMusicUrls,
  }) async {
    final currentHymns = state.value ?? await future;
    final officialHymns = currentHymns.where((h) => !h.isLocalOnly).toList();

    final int idToSave;
    if (collection == 'iump' && explicitId != null) {
      if (officialHymns.any((h) => h.id == explicitId)) {
        throw StateError('El número de himno $explicitId ya existe en el Himnario IUMP.');
      }
      idToSave = explicitId;
    } else {
      idToSave = officialHymns.isEmpty
          ? 1
          : officialHymns.map((h) => h.id).reduce((a, b) => a > b ? a : b) + 1;
    }

    await saveHymn(
      id: idToSave,
      title: title,
      toneNote: toneNote,
      beats: beats,
      timeSignature: timeSignature,
      lyrics: lyrics,
      isNew: true,
      audioUrl: audioUrl,
      category: category,
      sheetMusicUrls: sheetMusicUrls,
    );
    return idToSave;
  }

  // Eliminar
  Future<void> deleteHymn(int id) async {
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.collection(collection).doc(id.toString()).delete();
      await SuggestionTrackingService.cleanupSuggestionsForDeletedHymn(
        collection: collection,
        id: id,
      );
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
    
    // Actualización optimista de la colección destino (previene sobreescrituras en movimientos rápidos)
    final targetNotifier = ref.read(hymnsProvider(targetCollection).notifier);
    if (targetNotifier.state.hasValue) {
      final currentTargetList = targetNotifier.state.value!.toList();
      currentTargetList.add(Hymn.fromJson(data, targetCollection));
      targetNotifier.state = AsyncValue.data(currentTargetList);
    }
    
    // Actualización optimista de la colección origen
    if (state.hasValue) {
      final currentSourceList = state.value!.toList();
      currentSourceList.removeWhere((h) => h.id == hymn.id);
      state = AsyncValue.data(currentSourceList);
    }

    try {
      // Escribir en la colección destino
      await firestore.collection(targetCollection).doc(nextId.toString()).set(data);
      
      // Eliminar de la colección origen
      await firestore.collection(collection).doc(hymn.id.toString()).delete();

      // Mantener sincronizada cualquier sugerencia aprobada vinculada a este canto
      await SuggestionTrackingService.updateSuggestionsForMovedHymn(
        oldCollection: collection,
        oldId: hymn.id,
        newCollection: targetCollection,
        newId: nextId,
        title: hymn.title.trim().toUpperCase(),
      );
      
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
