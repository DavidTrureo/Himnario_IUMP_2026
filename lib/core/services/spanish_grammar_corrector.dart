import 'dart:convert';

import 'spanish_accent_engine.dart';

class GrammarCorrectionResult {
  final String title;
  final String lyrics;
  final int correctionsCount;

  GrammarCorrectionResult({
    required this.title,
    required this.lyrics,
    required this.correctionsCount,
  });
}

class SpanishGrammarCorrector {
  // Diccionario de correcciones de palabras sin tilde -> con tilde y erratas comunes
  static final Map<Pattern, String> _wordReplacements = {
    // Errores tipográficos específicos y verbos esdrújulos de alabanza (-ame, -anos, -eme, -enos, -ime, -inos)
    RegExp(r'\bpentecostes\b', caseSensitive: false): 'Pentecostés',
    RegExp(r'\bbaitizame\b', caseSensitive: false): 'bautízame',
    RegExp(r'\bbaitízame\b', caseSensitive: false): 'bautízame',
    RegExp(r'\bbaustizame\b', caseSensitive: false): 'bautízame',
    RegExp(r'\bbautizame\b', caseSensitive: false): 'bautízame',
    RegExp(r'\bbautizanos\b', caseSensitive: false): 'bautízanos',
    RegExp(r'\blavame\b', caseSensitive: false): 'lávame',
    RegExp(r'\blavanos\b', caseSensitive: false): 'lávanos',
    RegExp(r'\bllename\b', caseSensitive: false): 'lléname',
    RegExp(r'\bllenanos\b', caseSensitive: false): 'llénanos',
    RegExp(r'\blimpiame\b', caseSensitive: false): 'límpiame',
    RegExp(r'\blimpianos\b', caseSensitive: false): 'límpianos',
    RegExp(r'\bsaname\b', caseSensitive: false): 'sáname',
    RegExp(r'\bsananos\b', caseSensitive: false): 'sánanos',
    RegExp(r'\bavivame\b', caseSensitive: false): 'avívame',
    RegExp(r'\bavivanos\b', caseSensitive: false): 'avívanos',
    RegExp(r'\blibertame\b', caseSensitive: false): 'libértame',
    RegExp(r'\brenuevame\b', caseSensitive: false): 'renuévame',
    RegExp(r'\brenuevanos\b', caseSensitive: false): 'renuévanos',
    RegExp(r'\btransformame\b', caseSensitive: false): 'transfórmame',
    RegExp(r'\bconfortame\b', caseSensitive: false): 'confórtame',
    RegExp(r'\brestaurame\b', caseSensitive: false): 'restáurame',
    RegExp(r'\bguiame\b', caseSensitive: false): 'guíame',
    RegExp(r'\bguianos\b', caseSensitive: false): 'guíanos',
    RegExp(r'\bprotegeme\b', caseSensitive: false): 'protégeme',
    RegExp(r'\bprotegenos\b', caseSensitive: false): 'protégenos',
    RegExp(r'\bbendiceme\b', caseSensitive: false): 'bendíceme',
    RegExp(r'\bbendicenos\b', caseSensitive: false): 'bendícenos',
    RegExp(r'\boyeme\b', caseSensitive: false): 'óyeme',
    RegExp(r'\boyenos\b', caseSensitive: false): 'óyenos',
    RegExp(r'\bescuchame\b', caseSensitive: false): 'escúchame',
    RegExp(r'\bescuchanos\b', caseSensitive: false): 'escúchanos',
    RegExp(r'\brescatame\b', caseSensitive: false): 'rescátame',
    RegExp(r'\bperdoname\b', caseSensitive: false): 'perdóname',
    RegExp(r'\bperdonanos\b', caseSensitive: false): 'perdónanos',
    RegExp(r'\bacuerdate\b', caseSensitive: false): 'acuérdate',
    RegExp(r'\bacercate\b', caseSensitive: false): 'acércate',
    RegExp(r'\blevantame\b', caseSensitive: false): 'levántame',
    RegExp(r'\blevantate\b', caseSensitive: false): 'levántate',
    RegExp(r'\bdespiertame\b', caseSensitive: false): 'despiértame',
    RegExp(r'\bescondeme\b', caseSensitive: false): 'escóndeme',
    RegExp(r'\bbuscame\b', caseSensitive: false): 'búscame',
    RegExp(r'\bllamame\b', caseSensitive: false): 'llámame',
    RegExp(r'\bllevame\b', caseSensitive: false): 'llévame',
    RegExp(r'\bsalvame\b', caseSensitive: false): 'sálvame',
    RegExp(r'\bmirame\b', caseSensitive: false): 'mírame',
    RegExp(r'\btocame\b', caseSensitive: false): 'tócame',
    RegExp(r'\bcambiame\b', caseSensitive: false): 'cámbiame',
    RegExp(r'\bsantificate\b', caseSensitive: false): 'santifícate',
    RegExp(r'\bhaganse\b', caseSensitive: false): 'háganse',

    // Futuros y pretéritos verbales de 3ª persona
    RegExp(r'\bcalmara\b', caseSensitive: false): 'calmará',
    RegExp(r'\bsalvara\b', caseSensitive: false): 'salvará',
    RegExp(r'\bguiara\b', caseSensitive: false): 'guiará',
    RegExp(r'\bcurara\b', caseSensitive: false): 'curará',
    RegExp(r'\bsanara\b', caseSensitive: false): 'sanará',
    RegExp(r'\bamara\b', caseSensitive: false): 'amará',
    RegExp(r'\bhara\b', caseSensitive: false): 'hará',
    RegExp(r'\bvendra\b', caseSensitive: false): 'vendrá',
    RegExp(r'\bllegara\b', caseSensitive: false): 'llegará',
    RegExp(r'\btriunfara\b', caseSensitive: false): 'triunfará',
    RegExp(r'\breinara\b', caseSensitive: false): 'reinará',
    RegExp(r'\bvencera\b', caseSensitive: false): 'vencerá',
    RegExp(r'\bestara\b', caseSensitive: false): 'estará',
    RegExp(r'\bestan\b', caseSensitive: false): 'están',

    // Sustantivos y adverbios comunes
    RegExp(r'\bcancion\b', caseSensitive: false): 'canción',
    RegExp(r'\boracion\b', caseSensitive: false): 'oración',
    RegExp(r'\bbendicion\b', caseSensitive: false): 'bendición',
    RegExp(r'\bsalvacion\b', caseSensitive: false): 'salvación',
    RegExp(r'\bperdon\b', caseSensitive: false): 'perdón',
    RegExp(r'\bcorazon\b', caseSensitive: false): 'corazón',
    RegExp(r'\bexaltacion\b', caseSensitive: false): 'exaltación',
    RegExp(r'\badoracion\b', caseSensitive: false): 'adoración',
    RegExp(r'\bpeticion\b', caseSensitive: false): 'petición',
    RegExp(r'\bnacion\b', caseSensitive: false): 'nación',
    RegExp(r'\bgeneracion\b', caseSensitive: false): 'generación',
    RegExp(r'\brevelacion\b', caseSensitive: false): 'revelación',
    RegExp(r'\btransgresion\b', caseSensitive: false): 'transgresión',
    RegExp(r'\btambien\b', caseSensitive: false): 'también',
    RegExp(r'\baqui\b', caseSensitive: false): 'aquí',
    RegExp(r'\balli\b', caseSensitive: false): 'allí',
    RegExp(r'\balla\b', caseSensitive: false): 'allá',
    RegExp(r'\basi\b', caseSensitive: false): 'así',
    RegExp(r'\batras\b', caseSensitive: false): 'atrás',
    RegExp(r'\bjamas\b', caseSensitive: false): 'jamás',
    RegExp(r'\bquizas\b', caseSensitive: false): 'quizás',

    // Términos Sagrados
    RegExp(r'\bespiritu\b', caseSensitive: false): 'espíritu',
    RegExp(r'\bjesus\b', caseSensitive: false): 'Jesús',
    RegExp(r'\bjehova\b', caseSensitive: false): 'Jehová',
    RegExp(r'\bsenor\b', caseSensitive: false): 'Señor',
    RegExp(r'\bdios\b', caseSensitive: false): 'Dios',
    RegExp(r'\bcristo\b', caseSensitive: false): 'Cristo',
    RegExp(r'\baltisimo\b', caseSensitive: false): 'Altísimo',

    // Vocativos
    RegExp(r'\b[Oo]h\s+Señor\b'): '¡Oh, Señor!,',
    RegExp(r'\b[Oo]h\s+Dios\b'): '¡Oh, Dios!,',
    RegExp(r'\b[Oo]h\s+Jesús\b'): '¡Oh, Jesús!,',
    RegExp(r'\b[Oo]h\s+Padre\b'): '¡Oh, Padre!,',

    // Modernización Ortográfica RAE (arcaísmos y variantes gráficas)
    RegExp(r'\bobscuridad\b', caseSensitive: false): 'oscuridad',
    RegExp(r'\bobscuridades\b', caseSensitive: false): 'oscuridades',
    RegExp(r'\bobscuro\b', caseSensitive: false): 'oscuro',
    RegExp(r'\bobscura\b', caseSensitive: false): 'oscura',
    RegExp(r'\bobscuros\b', caseSensitive: false): 'oscuros',
    RegExp(r'\bobscuras\b', caseSensitive: false): 'oscuras',
    RegExp(r'\bsubstancia\b', caseSensitive: false): 'sustancia',
    RegExp(r'\btranscender\b', caseSensitive: false): 'trascender',
    RegExp(r'\btranscendencia\b', caseSensitive: false): 'trascendencia',

    // Errores tipográficos y ortográficos comunes en cantos
    RegExp(r'\btubo\b', caseSensitive: false): 'tuvo',
    RegExp(r'\btubieron\b', caseSensitive: false): 'tuvieron',
    RegExp(r'\btubiste\b', caseSensitive: false): 'tuviste',
    RegExp(r'\bhiso\b', caseSensitive: false): 'hizo',
    RegExp(r'\bhayar\b', caseSensitive: false): 'hallar',
    RegExp(r'\bhaver\b', caseSensitive: false): 'haber',

    // Correcciones Contextuales de Acentuación RAE (ej: me amo -> me amó)
    RegExp(r'\bnadie\s+me\s+amo\b', caseSensitive: false): 'nadie me amó',
    RegExp(r'\bél\s+me\s+amo\b', caseSensitive: false): 'Él me amó',
    RegExp(r'\bel\s+me\s+amo\b', caseSensitive: false): 'Él me amó',
    RegExp(r'\bdios\s+me\s+amo\b', caseSensitive: false): 'Dios me amó',
    RegExp(r'\bjesus\s+me\s+amo\b', caseSensitive: false): 'Jesús me amó',
    RegExp(r'\bjesús\s+me\s+amo\b', caseSensitive: false): 'Jesús me amó',
    RegExp(r'\bquien\s+me\s+amo\b', caseSensitive: false): 'quien me amó',
    RegExp(r'\bquién\s+me\s+amo\b', caseSensitive: false): 'quién me amó',
    RegExp(r'\bque\s+me\s+amo\b', caseSensitive: false): 'que me amó',
    RegExp(r'\bqué\s+me\s+amo\b', caseSensitive: false): 'qué me amó',
    RegExp(r'\bse\s+transformo\b', caseSensitive: false): 'se transformó',
    RegExp(r'\bse\s+avivo\b', caseSensitive: false): 'se avivó',
    RegExp(r'\bvida\s+transformo\b', caseSensitive: false): 'vida transformó',
  };

  /// Procesa globalmente la letra y título del canto garantizando tildes, mayúsculas y puntuación multilínea.
  static GrammarCorrectionResult correctText({
    required String title,
    required String lyrics,
  }) {
    int count = 0;

    // 1. Corregir Título
    String newTitle = title.trim();
    for (final entry in _wordReplacements.entries) {
      if (entry.key is RegExp) {
        final reg = entry.key as RegExp;
        if (reg.hasMatch(newTitle)) {
          newTitle = newTitle.replaceAllMapped(reg, (match) {
            count++;
            final word = match.group(0)!;
            return _preserveCasing(word, entry.value);
          });
        }
      }
    }
    newTitle = newTitle.toUpperCase();

    // 2. Separar versos y líneas pegadas por descargas externas (ej: gloriaA Dios -> gloria\nA Dios)
    final String ungluedLyrics = _separateGluedLines(lyrics);
    if (ungluedLyrics != lyrics) {
      count += (ungluedLyrics.split('\n').length - lyrics.split('\n').length).abs();
    }

    // 3. Procesar Letra por bloques (estrofas) para mantener contexto multilínea de ¡! y ¿?
    final stanzas = ungluedLyrics.split(RegExp(r'\n\s*\n'));
    final List<String> correctedStanzas = [];

    for (final stanza in stanzas) {
      final lines = stanza.split('\n');
      final List<String> stanzaLines = [];

      // Verificar si la estrofa completa ya tiene pares balanceados de ¡! y ¿?
      final String stanzaText = lines.join(' ');
      final bool hasOpeningExclamation = stanzaText.contains('¡');
      final bool hasClosingExclamation = stanzaText.contains('!');
      final bool exclamationBalanced = hasOpeningExclamation && hasClosingExclamation;

      final bool hasOpeningQuestion = stanzaText.contains('¿');
      final bool hasClosingQuestion = stanzaText.contains('?');
      final bool questionBalanced = hasOpeningQuestion && hasClosingQuestion;

      for (int i = 0; i < lines.length; i++) {
        String trimmed = lines[i].trim();
        if (trimmed.isEmpty) {
          stanzaLines.add('');
          continue;
        }

        // Reemplazo de palabras sin tilde -> con tilde
        for (final entry in _wordReplacements.entries) {
          if (entry.key is RegExp) {
            final reg = entry.key as RegExp;
            if (reg.hasMatch(trimmed)) {
              trimmed = trimmed.replaceAllMapped(reg, (match) {
                count++;
                final word = match.group(0)!;
                return _preserveCasing(word, entry.value);
              });
            }
          }
        }

        // Motor Gramatical RAE: Clasificación por Sílaba Tónica (Agudas, Graves, Esdrújulas, Hiatos)
        final words = trimmed.split(' ');
        final List<String> accentWords = [];
        for (final w in words) {
          final processed = SpanishAccentEngine.processWord(w);
          if (processed != w) count++;
          accentWords.add(processed);
        }
        trimmed = accentWords.join(' ');

        // Pronombres diacríticos: "El calmara" -> "Él calmará", "Tu eres" -> "Tú eres"
        trimmed = trimmed.replaceAllMapped(
          RegExp(r'\b([Ee]l)\s+(calmará|salvará|guiará|curará|sanará|amará|hará|vendrá|llegará|triunfará|reinará|vencerá|estará|está|están|es|fue|dijo|escucha|ama|vive|reina)\b'),
          (match) {
            count++;
            return 'Él ${match.group(2)}';
          },
        );

        trimmed = trimmed.replaceAllMapped(
          RegExp(r'\b([Tt]u)\s+(eres|sabes|me|has|tienes|reinas|sanas|salvas|guias|guías)\b'),
          (match) {
            count++;
            return 'Tú ${match.group(2)}';
          },
        );

        // Nombres sagrados siempre con inicial Mayúscula
        trimmed = trimmed
            .replaceAll(RegExp(r'\bdios\b', caseSensitive: false), 'Dios')
            .replaceAll(RegExp(r'\bjesús\b', caseSensitive: false), 'Jesús')
            .replaceAll(RegExp(r'\bcristo\b', caseSensitive: false), 'Cristo')
            .replaceAll(RegExp(r'\bjehová\b', caseSensitive: false), 'Jehová')
            .replaceAll(RegExp(r'\bseñor\b', caseSensitive: false), 'Señor')
            .replaceAll(RegExp(r'\bespíritu santo\b', caseSensitive: false), 'Espíritu Santo')
            .replaceAll(RegExp(r'\bsalvador\b', caseSensitive: false), 'Salvador');

        // Capitalizar palabras inmediatamente después de barras de repetición '//' o '/'
        trimmed = trimmed.replaceAllMapped(
          RegExp(r'(\/+\s*(?:\[\s*[A-Za-z0-9#\/]+\s*\]\s*)?)([a-záéíóúñ])'),
          (m) {
            count++;
            return '${m[1]}${m[2]!.toUpperCase()}';
          },
        );

        // Mayúscula al inicio de verso (respetando acordes [DO], números 1., o barras //)
        trimmed = _capitalizeLineStart(trimmed);

        // Ajustar apertura de ¡! y ¿? SOLO si NO están ya balanceados multilínea en la estrofa
        if (!exclamationBalanced && trimmed.contains('!') && !trimmed.contains('¡')) {
          trimmed = _addOpeningPunctuation(trimmed, '¡');
          count++;
        }

        if (!questionBalanced && trimmed.contains('?') && !trimmed.contains('¿')) {
          trimmed = _addOpeningPunctuation(trimmed, '¿');
          count++;
        }

        // Punto final de verso si la línea carece de signos de cierre, división o si no es parte de una frase multilínea con ¡...!
        final bool isPartOfMultiLineExclamation = exclamationBalanced && !trimmed.contains('!');
        if (!isSectionHeader(trimmed) &&
            !isPartOfMultiLineExclamation &&
            !trimmed.endsWith('.') &&
            !trimmed.endsWith(',') &&
            !trimmed.endsWith(';') &&
            !trimmed.endsWith(':') &&
            !trimmed.endsWith('!') &&
            !trimmed.endsWith('?') &&
            !trimmed.endsWith('/') &&
            !trimmed.endsWith(']')) {
          trimmed += '.';
          count++;
        }

        stanzaLines.add(trimmed);
      }

      correctedStanzas.add(stanzaLines.join('\n'));
    }

    final newLyrics = correctedStanzas.join('\n\n');
    return GrammarCorrectionResult(
      title: newTitle,
      lyrics: newLyrics,
      correctionsCount: count,
    );
  }

  static bool isSectionHeader(String line) {
    final clean = line.replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑ]'), '').toUpperCase();
    return clean == 'CORO' ||
        clean == 'FINAL' ||
        clean == 'INTRO' ||
        clean == 'INTRODUCCION' ||
        clean == 'ESTROFA' ||
        clean == 'PUENTE';
  }

  static String _addOpeningPunctuation(String line, String symbol) {
    final chordRegex = RegExp(r'^((?:\[\s*[A-Za-z0-9#\/]+\s*\]|\d+\.|\/+|\s+)*)(.+)$');
    return line.replaceFirstMapped(chordRegex, (m) {
      final prefix = m.group(1) ?? '';
      final rest = m.group(2) ?? '';
      return '$prefix$symbol$rest';
    });
  }

  static String _capitalizeLineStart(String line) {
    if (line.isEmpty) return line;
    final chordRegex = RegExp(r'^((?:\[\s*[A-Za-z0-9#\/]+\s*\]|\d+\.|\/+|\s+)*)([a-záéíóúñ])');
    return line.replaceFirstMapped(chordRegex, (m) {
      final prefix = m.group(1) ?? '';
      final letter = m.group(2) ?? '';
      return '$prefix${letter.toUpperCase()}';
    });
  }

  static String _separateGluedLines(String text) {
    if (text.isEmpty) return text;
    String result = text;
    String prev = '';
    while (prev != result) {
      prev = result;
      // 1. Minúscula o puntuación pegada a Mayúscula con minúscula (ej: gloriaA Dios -> gloria\nA Dios)
      result = result.replaceAllMapped(
        RegExp(r'([a-záéíóúñ,.!?:;/])([A-ZÁÉÍÓÚ][a-záéíóúñ])'),
        (m) => '${m[1]}\n${m[2]}',
      );
      // 2. Minúscula pegada a palabra en MAYÚSCULAS SOSTENIDAS (ej: encendidoEN EL ALTAR -> encendido\nEN EL ALTAR)
      result = result.replaceAllMapped(
        RegExp(r'([a-záéíóúñ])([A-ZÁÉÍÓÚ]{2,})'),
        (m) => '${m[1]}\n${m[2]}',
      );
      // 3. Frase en MAYÚSCULAS terminada en punto pegada a otra frase en MAYÚSCULAS (ej: DIOS.EL FUEGO -> DIOS.\nEL FUEGO)
      result = result.replaceAllMapped(
        RegExp(r'([A-ZÁÉÍÓÚ]{2,}\.)([A-ZÁÉÍÓÚ]{2,})'),
        (m) => '${m[1]}\n${m[2]}',
      );
    }
    return result;
  }

  static String _preserveCasing(String original, String replacement) {
    if (original.isEmpty) return replacement;
    if (original == original.toUpperCase()) {
      return replacement.toUpperCase();
    }
    if (original[0] == original[0].toUpperCase()) {
      return replacement[0].toUpperCase() + (replacement.length > 1 ? replacement.substring(1) : '');
    }
    return replacement.toLowerCase();
  }
}
