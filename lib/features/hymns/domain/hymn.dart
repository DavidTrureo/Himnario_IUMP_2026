import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Hymn {
  final int id;
  final String title;
  final String tone;
  final String lyrics;
  final String collection;
  final String audioUrl;

  const Hymn({
    required this.id,
    required this.title,
    required this.tone,
    required this.lyrics,
    required this.collection,
    this.audioUrl = '',
  });

  factory Hymn.fromJson(Map<String, dynamic> json, String collection) {
    return Hymn(
      id: json['id'] as int,
      title: json['title'] as String,
      tone: json['tone'] as String? ?? '',
      lyrics: json['lyrics'] as String,
      collection: collection,
      audioUrl: json['audioUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'tone': tone,
      'lyrics': lyrics,
      'audioUrl': audioUrl,
    };
  }

  Hymn copyWith({
    String? title,
    String? tone,
    String? lyrics,
    String? audioUrl,
  }) {
    return Hymn(
      id: id,
      title: title ?? this.title,
      tone: tone ?? this.tone,
      lyrics: lyrics ?? this.lyrics,
      collection: collection,
      audioUrl: audioUrl ?? this.audioUrl,
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
    
    String formattedText = textWithPlaceholders.toLowerCase();
    
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

  static String formatLyricsForSaving(String lyrics, String collection) {
    // 0. Limpiar abreviaturas de menor "Mn." / "Mn" a "m" dentro de los corchetes
    final regexChords = RegExp(r'\[([^\]]+)\]');
    final cleanedLyrics = lyrics.replaceAllMapped(regexChords, (match) {
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
  String _removeDiacritics(String str) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuyNn';
    
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  // Normaliza eliminando tildes, signos de puntuación y unificando espacios
  String _normalizeString(String str) {
    String normalized = _removeDiacritics(str.toLowerCase());
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Método de conveniencia para búsquedas (poderoso, insensible a acentos y puntuación)
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    
    final normalizedQuery = _normalizeString(query);
    final normalizedTitle = _normalizeString(title);
    final normalizedLyrics = _normalizeString(lyrics);
    final idString = id.toString();

    return idString.contains(normalizedQuery) || 
           normalizedTitle.contains(normalizedQuery) ||
           normalizedLyrics.contains(normalizedQuery);
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
    final uppercaseChord = chord.toUpperCase().trim();
    
    final Map<String, String> toAmerican = {
      'DO': 'C', 'RE': 'D', 'MI': 'E', 'FA': 'F', 'SOL': 'G', 'LA': 'A', 'SI': 'B'
    };
    
    final Map<String, String> toSpanish = {
      'C': 'DO', 'D': 'RE', 'E': 'MI', 'F': 'FA', 'G': 'SOL', 'A': 'LA', 'B': 'SI'
    };

    // Regex para nota en español
    final RegExp spanishNoteRegex = RegExp(
      r'^(DO#|DO|RE#|REB|RE|MI#|MIB|MI|FA#|FA|SOL#|SOLB|SOL|LA#|LAB|LA|SI#|SIB|SI)',
      caseSensitive: false
    );
    // Regex para nota en inglés
    final RegExp englishNoteRegex = RegExp(
      r'^(C#|DB|D#|EB|E|F#|GB|G#|AB|A#|BB|B|C)',
      caseSensitive: false
    );

    if (targetNotation == 'american') {
      final spanishMatch = spanishNoteRegex.firstMatch(uppercaseChord);
      if (spanishMatch != null) {
        final noteMatch = spanishMatch.group(1)!;
        final suffix = chord.substring(noteMatch.length);
        
        String base = noteMatch;
        String accidental = '';
        if (noteMatch.endsWith('#')) {
          base = noteMatch.substring(0, noteMatch.length - 1);
          accidental = '#';
        } else if (noteMatch.endsWith('B') || noteMatch.endsWith('EB') || noteMatch.endsWith('IB') || noteMatch.endsWith('AB')) {
          if (noteMatch.length > 2) {
            base = noteMatch.substring(0, noteMatch.length - 1);
            accidental = 'b';
          }
        }
        
        final americanBase = toAmerican[base];
        if (americanBase != null) {
          final newNote = '$americanBase$accidental';
          final formattedNote = _capitalizeAs(newNote, chord.substring(0, noteMatch.length));
          return '$formattedNote$suffix';
        }
      }
    } else {
      // Convertir a español (latino)
      // Si ya es una nota en español, no intentar convertirla para evitar falsos positivos
      if (spanishNoteRegex.hasMatch(uppercaseChord)) {
        return chord;
      }

      final englishMatch = englishNoteRegex.firstMatch(uppercaseChord);
      if (englishMatch != null) {
        final noteMatch = englishMatch.group(1)!;
        final suffix = chord.substring(noteMatch.length);
        
        String base = noteMatch.substring(0, 1);
        String accidental = noteMatch.length > 1 ? noteMatch.substring(1).toLowerCase() : '';
        
        final spanishBase = toSpanish[base];
        if (spanishBase != null) {
          final newNote = '$spanishBase${accidental.toUpperCase()}';
          final formattedNote = _capitalizeAs(newNote, chord.substring(0, noteMatch.length));
          return '$formattedNote$suffix';
        }
      }
    }
    
    return chord;
  }

  static String formatToneDisplay(String originalTone, String notation) {
    // 1. Quitar el prefijo "TONO: ", limpiar abreviaturas "Mn." / "Mn" a "m", y limpiar espacios
    String clean = originalTone.replaceAll(RegExp(r'^TONO:\s*', caseSensitive: false), '').trim();
    clean = clean.replaceAll(RegExp(r'\s*(Mn\.|Mn|mn\.|mn)\b'), 'm');
    clean = clean.replaceAll(RegExp(r'\s+'), ' '); // normalizar espacios múltiples a un solo espacio
    
    if (clean.isEmpty) return '';

    // 2. Intentar separar el acorde de los tiempos usando la barra "/"
    String chordPart = clean;
    String timesPart = '';
    
    final slashIndex = clean.indexOf('/');
    if (slashIndex != -1) {
      chordPart = clean.substring(0, slashIndex).trim();
      timesPart = clean.substring(slashIndex + 1).trim();
    } else {
      final timesRegex = RegExp(r'(\d+\s*TIEMPOS)', caseSensitive: false);
      final match = timesRegex.firstMatch(clean);
      if (match != null) {
        timesPart = match.group(1)!;
        chordPart = clean.replaceFirst(timesPart, '').trim();
      }
    }

    // 3. Procesar y formatear el acorde (limpiar "MAYOR", cambiar "MENOR" a "m", y convertir notación)
    String processedChord = chordPart;
    
    bool isMinor = false;
    final chordUpper = chordPart.toUpperCase();
    if (chordUpper.contains('MENOR') || chordUpper.contains('MINOR')) {
      isMinor = true;
    } else {
      if (chordPart.contains('m')) {
        isMinor = true;
      } else {
        final minorRegex = RegExp(
          r'^(DO#|DO|RE#|REB|RE|MI#|MIB|MI|FA#|FA|SOL#|SOLB|SOL|LA#|LAB|LA|SI#|SIB|SI|[A-G])(?:#|B|b)?(M)(?:[^a-zA-Z0-9]|$)',
        );
        final match = minorRegex.firstMatch(chordPart);
        if (match != null) {
          isMinor = true;
        }
      }
    }
    
    // Extraer la nota raíz y sus alteraciones
    final RegExp noteRegex = RegExp(
      r'^(DO#|DO|RE#|REB|RE|MI#|MIB|MI|FA#|FA|SOL#|SOLB|SOL|LA#|LAB|LA|SI#|SIB|SI|[A-G]#|[A-G]b|[A-G])',
      caseSensitive: false
    );
    
    final match = noteRegex.firstMatch(chordPart);
    if (match != null) {
      final rootNote = match.group(1)!;
      String suffix = chordPart.substring(match.end).trim();
      
      // Quitar palabras de menor/mayor
      suffix = suffix.replaceAll(RegExp(r'(MAYOR|MAJOR|MENOR|MINOR)', caseSensitive: false), '').trim();
      if (isMinor) {
        if (suffix.startsWith('m') || suffix.startsWith('M')) {
          suffix = suffix.substring(1).trim();
        }
      }
      
      // Convertir la nota raíz según la notación seleccionada
      final convertedRoot = convertChordNotation(rootNote, notation);
      
      // Reconstruir el acorde
      processedChord = '$convertedRoot${isMinor ? "m" : ""}$suffix';
    } else {
      processedChord = chordPart.toUpperCase();
    }
    
    // Normalizar a mayúsculas
    processedChord = processedChord.toUpperCase();
    // Pero si es menor, el estándar es "m" minúscula. Pongamos la "M" minúscula al final de la nota raíz
    if (isMinor) {
      final RegExp rootWithMRegex = RegExp(
        r'^(DO#|DO|RE#|REB|RE|MI#|MIB|MI|FA#|FA|SOL#|SOLB|SOL|LA#|LAB|LA|SI#|SIB|SI|[A-G]#|[A-G]b|[A-G])(M)',
        caseSensitive: false
      );
      final mMatch = rootWithMRegex.firstMatch(processedChord);
      if (mMatch != null) {
        processedChord = processedChord.replaceFirst('M', 'm', mMatch.group(1)!.length);
      }
    }

    if (timesPart.isNotEmpty) {
      String cleanedTimes = timesPart.toUpperCase().trim();
      if (RegExp(r'^\d+$').hasMatch(cleanedTimes)) {
        cleanedTimes = '$cleanedTimes TIEMPOS';
      } else {
        final match = RegExp(r'^(\d+)\s*(?:TIEMPOS|TIEMPO)?$', caseSensitive: false).firstMatch(cleanedTimes);
        if (match != null) {
          cleanedTimes = '${match.group(1)} TIEMPOS';
        }
      }
      return '$processedChord / $cleanedTimes';
    } else {
      return processedChord;
    }
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

    // Suscribirse a cambios en tiempo real
    final subscription = firestore.collection(collection).snapshots().listen(
      (snapshot) async {
        if (snapshot.docs.isEmpty) {
          // Semillar si está vacío en Firestore (flujo original)
          try {
            final baseHymns = await _loadBaseHymns(collection);
            final batch = firestore.batch();
            for (final hymn in baseHymns) {
              final docRef = firestore.collection(collection).doc(hymn.id.toString());
              batch.set(docRef, {
                ...hymn.toJson(),
                'collection': collection,
              });
            }
            await batch.commit();
            state = AsyncValue.data(baseHymns);
          } catch (e) {
            debugPrint('>>> Error al semillar colección: $e');
          }
          return;
        }

        final List<Hymn> list = snapshot.docs.map((doc) {
          final data = doc.data();
          return Hymn(
            id: data['id'] as int,
            title: data['title'] as String,
            tone: data['tone'] as String? ?? '',
            lyrics: data['lyrics'] as String,
            collection: collection,
            audioUrl: data['audioUrl'] as String? ?? '',
          );
        }).toList();

        // Ordenar
        if (collection == 'iump') {
          list.sort((a, b) => a.id.compareTo(b.id));
        } else {
          list.sort((a, b) => a.title.compareTo(b.title));
        }

        state = AsyncValue.data(list);
        ref.read(databaseStatusProvider.notifier).setStatus('Conectado');
      },
      onError: (error) {
        debugPrint('>>> Error en stream de Firestore: $error. Cargando base local...');
        ref.read(databaseStatusProvider.notifier).setStatus('Offline: $error');
        _loadBaseHymns(collection).then((localList) {
          state = AsyncValue.data(localList);
        });
      },
    );

    // Cancelar la suscripción al eliminar/recargar el notifier
    ref.onDispose(() {
      subscription.cancel();
    });

    // Cargar inicialmente para retornar el valor esperado por build() de inmediato
    try {
      final firstSnapshot = await firestore.collection(collection).get();
      ref.read(databaseStatusProvider.notifier).setStatus('Conectado');

      if (firstSnapshot.docs.isEmpty) {
        final baseHymns = await _loadBaseHymns(collection);
        return baseHymns;
      }

      final List<Hymn> list = firstSnapshot.docs.map((doc) {
        final data = doc.data();
        return Hymn(
          id: data['id'] as int,
          title: data['title'] as String,
          tone: data['tone'] as String? ?? '',
          lyrics: data['lyrics'] as String,
          collection: collection,
          audioUrl: data['audioUrl'] as String? ?? '',
        );
      }).toList();

      if (collection == 'iump') {
        list.sort((a, b) => a.id.compareTo(b.id));
      } else {
        list.sort((a, b) => a.title.compareTo(b.title));
      }
      return list;
    } catch (e) {
      debugPrint('>>> Error en primer fetch de Firestore: $e. Cargando base local...');
      ref.read(databaseStatusProvider.notifier).setStatus('Offline: $e');
      return _loadBaseHymns(collection);
    }
  }

  Future<List<Hymn>> _loadBaseHymns(String collection) async {
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
    return jsonList.map((json) => Hymn.fromJson(json, collection)).toList();
  }

  // Guardar (Crear o Editar)
  Future<void> saveHymn({
    required int id,
    required String title,
    required String tone,
    required String lyrics,
    required bool isNew,
    String? audioUrl,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final formattedLyrics = Hymn.formatLyricsForSaving(lyrics, collection);
    final data = {
      'id': id,
      'title': title.trim().toUpperCase(),
      'tone': tone.trim().toUpperCase(),
      'lyrics': formattedLyrics,
      'collection': collection,
      'audioUrl': audioUrl ?? '',
    };
    
    try {
      await firestore.collection(collection).doc(id.toString()).set(data);
      ref.read(databaseStatusProvider.notifier).setStatus('Conectado');
    } catch (e) {
      ref.read(databaseStatusProvider.notifier).setStatus('Offline: $e');
      rethrow;
    }
    
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
    final data = {
      'id': nextId,
      'title': hymn.title.trim().toUpperCase(),
      'tone': hymn.tone.trim().toUpperCase(),
      'lyrics': formattedLyrics,
      'collection': targetCollection,
      'audioUrl': hymn.audioUrl,
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
  String build() => 'Conectando...';

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
