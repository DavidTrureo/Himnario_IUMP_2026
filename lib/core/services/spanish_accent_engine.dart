import 'dart:convert';

/// Motor Gramatical de Reglas Generales de Acentuación RAE
/// Clasifica y acentúa palabras en español según su sílaba tónica:
/// 1. Agudas: Tilde si terminan en Vocal, -N o -S.
/// 2. Graves: Tilde si NO terminan en Vocal, -N ni -S (o por hiato i/u).
/// 3. Esdrújulas y Sobreesdrújulas: TILDE SIEMPRE.
/// 4. Hiatos tónicos (i, u): TILDE SIEMPRE (ej: María, guía, día, oí, Elías, Pentecostés).
class SpanishAccentEngine {
  // Mapa extenso de palabras agudas, graves, esdrújulas, hiatos y diacríticos del español e himnología
  static final Map<String, String> _accentDictionary = {
    // Pentecostés y Términos Litúrgicos/Bíblicos Agudos en -S, -N, Vocal
    'pentecostes': 'Pentecostés',
    'pentecostés': 'Pentecostés',
    'jehova': 'Jehová',
    'jehovás': 'Jehová',
    'jesus': 'Jesús',
    'jesucristo': 'Jesucristo',
    'elias': 'Elías',
    'isaias': 'Isaías',
    'jeremias': 'Jeremías',
    'zacarias': 'Zacarías',
    'matias': 'Matías',
    'maria': 'María',
    'moises': 'Moisés',
    'jose': 'José',
    'satanas': 'Satanás',

    // Esdrújulas y Sobreesdrújulas (TILDE SIEMPRE)
    'espiritu': 'Espíritu',
    'espiritus': 'Espíritus',
    'ejercito': 'Ejército',
    'ejercitos': 'Ejércitos',
    'santisimo': 'Santísimo',
    'altisimo': 'Altísimo',
    'musica': 'Música',
    'cantalo': 'Cántalo',
    'alabandolo': 'alabándolo',
    'exaltandolo': 'exaltándolo',
    'glorificandolo': 'glorificándolo',
    'buscandolo': 'buscándolo',
    'adorandolo': 'adorándolo',
    'haganse': 'háganse',

    // Verbos Imperativos Esdrújulos (-ame, -anos, -eme, -enos, -ime, -inos, -ate, -ete, -ite)
    'bautizame': 'bautízame',
    'bautizanos': 'bautízanos',
    'baitizame': 'bautízame',
    'baitízame': 'bautízame',
    'baustizame': 'bautízame',
    'lavame': 'lávame',
    'lavanos': 'lávanos',
    'llename': 'lléname',
    'llenanos': 'llénanos',
    'limpiame': 'límpiame',
    'limpianos': 'límpianos',
    'saname': 'sáname',
    'sananos': 'sánanos',
    'avivame': 'avívame',
    'avivanos': 'avívanos',
    'libertame': 'libértame',
    'renuevame': 'renuévame',
    'renuevanos': 'renuévanos',
    'transformame': 'transfórmame',
    'confortame': 'confórtame',
    'restaurame': 'restáurame',
    'guiame': 'guíame',
    'guianos': 'guíanos',
    'protegeme': 'protégeme',
    'protegenos': 'protégenos',
    'bendiceme': 'bendíceme',
    'bendicenos': 'bendícenos',
    'oyeme': 'óyeme',
    'oyenos': 'óyenos',
    'escuchame': 'escúchame',
    'escuchanos': 'escúchanos',
    'rescatame': 'rescátame',
    'perdoname': 'perdóname',
    'perdonanos': 'perdónanos',
    'acuerdate': 'acuérdate',
    'acercate': 'acércate',
    'levantame': 'levántame',
    'levantate': 'levántate',
    'despiertame': 'despiértame',
    'escondeme': 'escóndeme',
    'buscame': 'búscame',
    'llamame': 'llámame',
    'llevame': 'llévame',
    'salvame': 'sálvame',
    'mirame': 'mírame',
    'tocame': 'tócame',
    'cambiame': 'cámbiame',
    'santificate': 'santifícate',

    // Sustantivos Agudos Terminados en -CIÓN, -SIÓN, -ÓN
    'cancion': 'canción',
    'canciones': 'canciones',
    'oracion': 'oración',
    'oraciones': 'oraciones',
    'bendicion': 'bendición',
    'bendiciones': 'bendiciones',
    'salvacion': 'salvación',
    'perdon': 'perdón',
    'corazon': 'corazón',
    'corazones': 'corazones',
    'exaltacion': 'exaltación',
    'adoracion': 'adoración',
    'peticion': 'petición',
    'peticiones': 'peticiones',
    'nacion': 'nación',
    'naciones': 'naciones',
    'generacion': 'generación',
    'generaciones': 'generaciones',
    'revelacion': 'revelación',
    'transgresion': 'transgresión',
    'transgresiones': 'transgresiones',
    'sanidad': 'sanidad',
    'maravilla': 'maravilla',
    'redencion': 'redención',
    'manifestacion': 'manifestación',
    'consolacion': 'consolación',
    'comunion': 'comunión',

    // Futuros y Pretéritos Verbales Agudos (Terminados en Vocal, -N o -S)
    'calmara': 'calmará',
    'calmaran': 'calmarán',
    'salvara': 'salvará',
    'salvaran': 'salvarán',
    'guiara': 'guiará',
    'guiaran': 'guiarán',
    'curara': 'curará',
    'curaran': 'curarán',
    'sanara': 'sanará',
    'sanaran': 'sanarán',
    'amara': 'amará',
    'amaran': 'amarán',
    'hara': 'hará',
    'haran': 'harán',
    'vendra': 'vendrá',
    'vendran': 'vendrán',
    'llegara': 'llegará',
    'llegaran': 'llegarán',
    'triunfara': 'triunfará',
    'triunfaran': 'triunfarán',
    'reinara': 'reinará',
    'reinaran': 'reinarán',
    'vencera': 'vencerá',
    'venceran': 'vencerán',
    'estara': 'estará',
    'estaran': 'estarán',
    'estan': 'están',
    'esta': 'está',
    'salvo': 'salvó',
    'resucito': 'resucitó',
    'sanó': 'sanó',
    'sano': 'sanó',
    'vencio': 'venció',
    'vencio': 'venció',
    'pago': 'pagó',
    'murió': 'murió',
    'murio': 'murió',
    'entrego': 'entregó',

    // Adverbios y Adjetivos Agudos
    'tambien': 'también',
    'aqui': 'aquí',
    'alli': 'allí',
    'alla': 'allá',
    'asi': 'así',
    'atras': 'atrás',
    'jamas': 'jamás',
    'quizas': 'quizás',
    'despues': 'después',
    'mas': 'más', // en contextos de cantidad (más de ti)

    // Hiatos (Ruptura de diptongo en i/u)
    'dia': 'día',
    'dias': 'días',
    'guias': 'guías',
    'guia': 'guía',
    'oido': 'oído',
    'oidos': 'oídos',
    'caido': 'caído',
    'vias': 'vías',
    'via': 'vía',
    'confia': 'confía',
    'confio': 'confió',

    // Modernización RAE
    'obscuridad': 'oscuridad',
    'obscuro': 'oscuro',
    'obscura': 'oscura',
    'substancia': 'sustancia',
    'transcender': 'trascender',

    // Errores tipográficos
    'tubo': 'tuvo',
    'tubieron': 'tuvieron',
    'hiso': 'hizo',
    'hayar': 'hallar',
    'haver': 'haber',
  };

  /// Procesa una palabra individual aplicando las Reglas Generales RAE y el diccionario completo
  static String processWord(String word) {
    if (word.isEmpty) return word;

    // Limpiar puntuación para buscar en el diccionario
    final clean = word.replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑ]'), '').toLowerCase();
    if (clean.isEmpty) return word;

    if (_accentDictionary.containsKey(clean)) {
      final replacement = _accentDictionary[clean]!;
      return _matchCasing(word, replacement);
    }

    // Regla de Agudas en -ción, -sión, -ón
    if (clean.endsWith('cion')) {
      final replacement = clean.substring(0, clean.length - 4) + 'ción';
      return _matchCasing(word, replacement);
    }
    if (clean.endsWith('sion')) {
      final replacement = clean.substring(0, clean.length - 4) + 'sión';
      return _matchCasing(word, replacement);
    }

    return word;
  }

  static String _matchCasing(String original, String replacement) {
    final cleanOriginal = original.replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑ]'), '');
    if (cleanOriginal.isEmpty) return replacement;

    // SI TODO ERA MAYÚSCULAS
    if (cleanOriginal == cleanOriginal.toUpperCase()) {
      return replacement.toUpperCase();
    }
    // SI EMPEZABA CON MAYÚSCULA
    if (cleanOriginal[0] == cleanOriginal[0].toUpperCase()) {
      final String firstChar = replacement[0].toUpperCase();
      final String rest = replacement.length > 1 ? replacement.substring(1) : '';
      final String result = firstChar + rest;
      return original.replaceFirst(cleanOriginal, result);
    }
    return original.replaceFirst(cleanOriginal, replacement.toLowerCase());
  }
}
