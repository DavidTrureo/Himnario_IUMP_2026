import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../features/hymns/domain/hymn.dart';

/// Motor híbrido de recuperación semántica y temática sobre TODA la base de datos.
///
/// Cumple dos funciones clave:
/// 1. Preselecciona en milisegundos los mejores candidatos de cada colección
///    (`iump`, `especiales`, `coros`) leyendo el contenido real de las letras
///    (sin acordes ni estribillos duplicados) + similitud vectorial si existe índice.
/// 2. Sirve como motor local/offline de alta precisión (hasta 10 por colección)
///    cuando el usuario no tiene conexión o se alcanza la cuota gratuita de Gemini.
class HymnSemanticRetriever {
  static const List<String> collectionOrder = ['iump', 'especiales', 'coros'];
  static const int maxResultsPerCollection = 10;
  static const int additionalBatchSize = 10;
  static const int maxAdditionalBatchesPerCollection = 3;
  static const int maxAdditionalResultsPerCollection =
      additionalBatchSize * maxAdditionalBatchesPerCollection;

  // Caché en memoria del índice vectorial compacto (si está empaquetado en assets)
  static bool _embeddingsLoadAttempted = false;
  static int _embeddingDims = 0;
  static Uint8List? _embeddingVectorsRaw;
  static Map<String, int> _embeddingRowByKey = const {};
  static Map<String, String> _embeddingHashByKey = const {};

  static final RegExp _chordBracketRegex = RegExp(r'\[[^\]]*\]');
  static final RegExp _whitespaceRegex = RegExp(r'\s+');
  static final RegExp _nonAlnumSpaceRegex = RegExp(r'[^a-z0-9\s]');

  static const Set<String> _stopwords = {
    'a', 'al', 'algo', 'algun', 'alguna', 'algunas', 'alguno', 'algunos',
    'ante', 'antes', 'aquel', 'aquella', 'aqui', 'asi', 'aun', 'aunque',
    'bajo', 'bien', 'cada', 'casi', 'como', 'con', 'contra', 'cual', 'cuando',
    'cuanto', 'de', 'del', 'desde', 'donde', 'dos', 'el', 'ella', 'ellas',
    'ello', 'ellos', 'en', 'entre', 'era', 'eres', 'es', 'esa', 'esas', 'ese',
    'eso', 'esos', 'esta', 'estaba', 'estan', 'estas', 'este', 'esto', 'estos',
    'fue', 'fueron', 'fui', 'ha', 'habia', 'hace', 'hacer', 'hacia', 'han',
    'hasta', 'hay', 'he', 'hemos', 'la', 'las', 'le', 'les', 'lo', 'los',
    'mas', 'me', 'mi', 'mis', 'mismo', 'mucho', 'muy', 'nada', 'ni', 'no',
    'nos', 'nosotros', 'nuestra', 'nuestro', 'o', 'otra', 'otro', 'para',
    'pero', 'poco', 'por', 'porque', 'pues', 'que', 'quien', 'quienes',
    'se', 'sea', 'ser', 'si', 'siempre', 'sin', 'sino', 'sobre', 'solo',
    'somos', 'son', 'soy', 'su', 'sus', 'tal', 'tambien', 'tan', 'tanto',
    'te', 'tengo', 'ti', 'tiene', 'tienen', 'toda', 'todas', 'todo', 'todos',
    'tu', 'tus', 'un', 'una', 'unas', 'uno', 'unos', 'va', 'vamos', 'van',
    'vez', 'vos', 'vosotros', 'vuestro', 'y', 'ya', 'yo',
    // Palabras comunes de consulta que no identifican tema por sí solas
    'canto', 'cantos', 'himno', 'himnos', 'alabanza', 'alabanzas', 'coro',
    'coros', 'especial', 'especiales', 'cancion', 'canciones', 'predicacion',
    'sermon', 'mensaje', 'tema', 'pasaje', 'versiculo', 'biblia', 'biblico',
    'hable', 'hablen', 'habla', 'trate', 'traten', 'acerca', 'busca',
    'buscar', 'encontrar', 'dame', 'quiero', 'necesito',
  };

  /// Diccionario teológico-bíblico para expandir consultas de predicación o metáfora
  /// hacia el vocabulario real que usan los himnos, alabanzas especiales y coros.
  static final List<_BiblicalConcept> _biblicalConcepts = [
    _BiblicalConcept(
      id: 'pastor_salmo23',
      label: 'Buen Pastor y Salmo 23',
      triggers: [
        'salmo 23', 'salmos 23', 'pastor', 'valle', 'sombra', 'muerte',
        'delicados', 'pastos', 'aderezas', 'mesa', 'vara', 'cayado',
        'nada me faltara', 'oveja', 'ovejas', 'noventa y nueve', 'redil',
      ],
      expansions: [
        'pastor', 'oveja', 'ovino', 'redil', 'rebano', 'valle', 'sombra',
        'cuidado', 'guia', 'consuelo', 'temor', 'temere', 'descanso', 'paz',
        'sendas', 'justicia', 'camino', 'seguridad', 'refugio',
      ],
      worshipMoment: 'Consuelo y Confianza',
    ),
    _BiblicalConcept(
      id: 'prueba_isaias43_aguas_fuego',
      label: 'Promesa en Aguas, Fuego y Tempestad',
      triggers: [
        'isaias 43', 'aguas', 'rios', 'fuego', 'llama', 'quemar', 'anegar',
        'tempestad', 'tormenta', 'mar', 'tempestuoso', 'olas', 'barca',
        'viento', 'ancla', 'naufragio', 'calmar', 'galilea',
      ],
      expansions: [
        'agua', 'aguas', 'mar', 'tempestad', 'tormenta', 'ola', 'olas',
        'barca', 'ancla', 'puerto', 'fuego', 'prueba', 'lucha', 'peligro',
        'contigo', 'calma', 'roca', 'refugio', 'amparo', 'salva', 'temas',
      ],
      worshipMoment: 'Fe en la Prueba',
    ),
    _BiblicalConcept(
      id: 'elias_fuerzas_aguilas',
      label: 'Renovación de Fuerzas y Ánimo (Elías / Isaías 40)',
      triggers: [
        'elias', 'enebro', 'desierto', 'cansado', 'desanimado', 'desanimo',
        'debil', 'fuerzas', 'aguila', 'aguilas', 'isaias 40', 'fatiga',
        'desmayar', '1 reyes 19', 'cueva', 'silbo', 'apacible', 'esperan',
      ],
      expansions: [
        'fuerza', 'fuerzas', 'aguila', 'aguilas', 'cansado', 'fatigado',
        'animo', 'aliento', 'renueva', 'renovar', 'desierto', 'desmayes',
        'levanta', 'levantate', 'esperanza', 'fortaleza', 'poder', 'sosten',
      ],
      worshipMoment: 'Oración de Fe / Afligidos',
    ),
    _BiblicalConcept(
      id: 'guerra_armadura_efesios6',
      label: 'Guerra Espiritual y Armadura de Dios',
      triggers: [
        'efesios 6', 'armadura', 'guerra', 'batalla', 'soldado', 'espada',
        'escudo', 'yelmo', 'coraza', 'asechanzas', 'enemigo', 'diablo',
        'satanas', 'tinieblas', 'potestades', 'victoria', 'lucha', 'firme',
      ],
      expansions: [
        'armadura', 'soldado', 'guerra', 'batalla', 'lucha', 'espada',
        'escudo', 'pelea', 'victoria', 'vencedor', 'vencer', 'firme',
        'enemigo', 'triunfo', 'bandera', 'valiente', 'ejercito', 'fe',
      ],
      worshipMoment: 'Alabanza y Guerra Espiritual',
    ),
    _BiblicalConcept(
      id: 'cruz_isaias53_sangre_sanidad',
      label: 'La Cruz, Sacrificio y Sanidad',
      triggers: [
        'isaias 53', 'cruz', 'calvario', 'golgota', 'sangre', 'llaga',
        'llagas', 'herido', 'molido', 'curado', 'sanidad', 'enfermedad',
        'enfermo', 'cordero', 'redencion', 'rescate', 'clavos', 'madero',
      ],
      expansions: [
        'cruz', 'calvario', 'sangre', 'cordero', 'herida', 'llaga', 'sana',
        'sanidad', 'salud', 'medico', 'redentor', 'precio', 'murio',
        'sacrificio', 'perdon', 'limpio', 'vida', 'salvo',
      ],
      worshipMoment: 'Llamado al Altar / Santa Cena',
    ),
    _BiblicalConcept(
      id: 'prodigo_perdon_gracia',
      label: 'Arrepentimiento, Gracia y Restauración (Hijo Pródigo)',
      triggers: [
        'lucas 15', 'prodigo', 'arrepentido', 'arrepentimiento', 'perdon',
        'pecado', 'pecador', 'gracia', 'misericordia', 'volver', 'regresar',
        'restauracion', 'quebrantamiento', 'humillacion', 'padre', 'casa',
      ],
      expansions: [
        'perdon', 'gracia', 'misericordia', 'pecado', 'pecador', 'culpa',
        'limpia', 'lava', 'arrepentido', 'humilde', 'quebranta', 'vuelve',
        'regresa', 'brazos', 'padre', 'salvacion', 'nuevo', 'corazon',
      ],
      worshipMoment: 'Llamado al Altar / Consagración',
    ),
    _BiblicalConcept(
      id: 'espiritu_pentecostes_fuego',
      label: 'Espíritu Santo, Pentecostés y Avivamiento',
      triggers: [
        'hechos 2', 'pentecostes', 'espiritu santo', 'fuego', 'viento',
        'lenguas', 'derramamiento', 'uncion', 'avivamiento', 'consolador',
        'lluvia', 'tardia', 'temprana', 'aposento', 'zarza', 'sinai', 'arde',
      ],
      expansions: [
        'espiritu', 'santo', 'fuego', 'llama', 'lluvia', 'uncion', 'poder',
        'aviva', 'avivamiento', 'consolador', 'derrama', 'llena', 'llename',
        'pentecostes', 'zarza', 'ardiendo', 'paloma', 'gloria',
      ],
      worshipMoment: 'Ministración / Avivamiento',
    ),
    _BiblicalConcept(
      id: 'alfarero_consagracion_entrega',
      label: 'El Alfarero y Consagración Total',
      triggers: [
        'alfarero', 'barro', 'vaso', 'jeremias 18', 'consagracion', 'entrega',
        'altar', 'rendicion', 'moldear', 'rompe', 'transforma', 'santidad',
        'obediencia', 'voluntad', 'servir', 'llamado',
      ],
      expansions: [
        'alfarero', 'barro', 'vaso', 'moldea', 'altar', 'entrega', 'entrego',
        'rindo', 'rendido', 'consagro', 'santo', 'santidad', 'obedecer',
        'voluntad', 'siervo', 'tuyo', 'manos', 'transforma', 'corazon',
      ],
      worshipMoment: 'Consagración / Sellar la Predicación',
    ),
    _BiblicalConcept(
      id: 'consuelo_esperanza_afliccion',
      label: 'Consuelo en la Aflicción y Paz',
      triggers: [
        'consuelo', 'afliccion', 'dolor', 'lagrimas', 'llanto', 'tristeza',
        'angustia', 'prueba', 'dificil', 'romanos 8', 'salmo 91', 'salmo 121',
        'socorro', 'amparo', 'pronto auxilio', 'soledad', 'esperanza',
      ],
      expansions: [
        'consuelo', 'consuela', 'paz', 'dolor', 'llanto', 'lagrima', 'pena',
        'triste', 'afliccion', 'socorro', 'amparo', 'refugio', 'fortaleza',
        'confia', 'confianza', 'espera', 'esperanza', 'promesa', 'fiel',
      ],
      worshipMoment: 'Oración de Fe / Afligidos',
    ),
    _BiblicalConcept(
      id: 'segunda_venida_cielo_eternidad',
      label: 'Segunda Venida de Cristo y Patria Celestial',
      triggers: [
        'venida', 'regreso', 'arrebatamiento', 'trompeta', 'bodas', 'cordero',
        'cielo', 'gloria', 'eterna', 'jerusalen', 'mansiones', 'patria',
        'celestial', 'apocalipsis', 'nubes', 'velad', 'pronto viene',
      ],
      expansions: [
        'viene', 'vendra', 'pronto', 'trompeta', 'nubes', 'cielo', 'gloria',
        'eterno', 'eterna', 'jerusalen', 'bodas', 'novia', 'morada',
        'mansiones', 'corona', 'reino', 'reinar', 'velando', 'esperando',
      ],
      worshipMoment: 'Sellar la Predicación / Esperanza',
    ),
    _BiblicalConcept(
      id: 'adoracion_gratitud_honra',
      label: 'Adoración, Gratitud y Exaltación',
      triggers: [
        'adoracion', 'adorar', 'alabanza', 'alabar', 'gratitud', 'gracias',
        'honra', 'gloria', 'majestad', 'santo', 'digno', 'rey', 'senor',
        'agradecimiento', 'bendecir', 'exaltar', 'cantico',
      ],
      expansions: [
        'alaba', 'alabanza', 'adora', 'adoracion', 'gracias', 'gratitud',
        'honra', 'gloria', 'majestad', 'santo', 'digno', 'exalta',
        'bendito', 'aleluya', 'hosanna', 'cantico', 'rey', 'poderoso',
      ],
      worshipMoment: 'Alabanza Congregacional',
    ),
    _BiblicalConcept(
      id: 'evangelismo_salvacion_mision',
      label: 'Salvación, Evangelismo y Llamado',
      triggers: [
        'salvacion', 'evangelio', 'almas', 'predicar', 'mision', 'mies',
        'obreros', 'ven a cristo', 'juan 3', 'nicodemo', 'nacer de nuevo',
        'puerta', 'llama a la puerta', 'perdido', 'pecadores',
      ],
      expansions: [
        'salva', 'salvacion', 'alma', 'almas', 'evangelio', 'mies', 'obrero',
        'sembrar', 'cosecha', 'predica', 'llama', 'puerta', 'ven', 'acepta',
        'eterna', 'vida', 'luz', 'camino', 'verdad',
      ],
      worshipMoment: 'Llamado Evangelístico',
    ),
  ];

  static bool get hasEmbeddingsLoaded =>
      _embeddingVectorsRaw != null &&
      _embeddingDims > 0 &&
      _embeddingRowByKey.isNotEmpty;

  /// Carga de forma segura (sin fallar si aún no existe) el índice binario de embeddings.
  static Future<void> ensureEmbeddingsLoaded() async {
    if (_embeddingsLoadAttempted) return;
    _embeddingsLoadAttempted = true;
    try {
      final metaStr = await rootBundle.loadString(
        'assets/json/hymn_embeddings_meta.json',
      );
      final metaJson = jsonDecode(metaStr) as Map<String, dynamic>;
      final dims = (metaJson['dims'] as num?)?.toInt() ?? 0;
      final items = (metaJson['items'] as List?) ?? const [];
      if (dims <= 0 || items.isEmpty) return;

      final ByteData binData = await rootBundle.load(
        'assets/json/hymn_embeddings.bin',
      );
      final rawBytes = binData.buffer.asUint8List(
        binData.offsetInBytes,
        binData.lengthInBytes,
      );
      if (rawBytes.length < items.length * dims) return;

      final rowMap = <String, int>{};
      final hashMap = <String, String>{};
      for (int i = 0; i < items.length; i++) {
        final item = items[i] as Map<String, dynamic>;
        final col = item['c']?.toString() ?? '';
        final id = item['i']?.toString() ?? '';
        final h = item['h']?.toString() ?? '';
        if (col.isEmpty || id.isEmpty) continue;
        final key = '$col-$id';
        rowMap[key] = i;
        if (h.isNotEmpty) hashMap[key] = h;
      }

      _embeddingDims = dims;
      _embeddingVectorsRaw = rawBytes;
      _embeddingRowByKey = rowMap;
      _embeddingHashByKey = hashMap;
    } catch (_) {
      // Es seguro continuar sin el binario si todavía no se ha generado.
    }
  }

  /// Limpia acordes entre corchetes y compacta espacios innecesarios.
  static String cleanLyrics(String rawLyrics) {
    return rawLyrics
        .replaceAll(_chordBracketRegex, '')
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  /// Construye un resumen compacto pero fiel de la letra real (título + coro + estrofas distintas),
  /// eliminando repeticiones del coro para maximizar cobertura dentro del límite de tokens.
  static String buildCompactDigest(Hymn hymn, {int maxChars = 480}) {
    final cleaned = cleanLyrics(hymn.lyrics);
    if (cleaned.isEmpty) return hymn.title;

    final rawLines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final seenNormLines = <String>{};
    final uniqueLines = <String>[];
    for (final line in rawLines) {
      final norm = Hymn.normalizeString(line);
      // Mantener etiquetas estructurales como "CORO:" o "1.", pero evitar versos repetidos idénticos
      final isLabel = line.length <= 10 &&
          (line.endsWith(':') || RegExp(r'^\d+\.?$').hasMatch(line));
      if (norm.length >= 6 && !isLabel) {
        if (!seenNormLines.add(norm)) continue;
      }
      uniqueLines.add(line);
    }

    final joined = uniqueLines.join(' / ');
    if (joined.length <= maxChars) return joined;
    return '${joined.substring(0, maxChars - 1).trimRight()}…';
  }

  /// Firma determinística breve del catálogo activo para invalidar caché ante cantos nuevos/editados.
  static String computeCatalogSignature(
    List<Hymn> catalog,
    Set<String> allowedCollections,
  ) {
    final counts = <String, int>{'iump': 0, 'especiales': 0, 'coros': 0};
    final maxIds = <String, int>{'iump': 0, 'especiales': 0, 'coros': 0};
    int customCount = 0;

    for (final h in catalog) {
      if (!allowedCollections.contains(h.collection)) continue;
      counts[h.collection] = (counts[h.collection] ?? 0) + 1;
      if (h.id > (maxIds[h.collection] ?? 0)) {
        maxIds[h.collection] = h.id;
      }
      if (h.isLocalOnly) customCount++;
    }

    final sortedCols = allowedCollections.toList()..sort();
    return 'v2_${sortedCols.join(',')}_'
        'i${counts['iump']}m${maxIds['iump']}_'
        'e${counts['especiales']}m${maxIds['especiales']}_'
        'c${counts['coros']}m${maxIds['coros']}_'
        'loc$customCount';
  }

  /// Normaliza una palabra española a una raíz aproximada para tolerar plurales y conjugaciones.
  static String stemSpanishWord(String word) {
    var w = word.trim();
    if (w.length <= 4) return w;

    for (final suffix in const [
      'amientos', 'amiento', 'aciones', 'acion', 'iciones', 'icion',
      'mente', 'idades', 'idad', 'anzas', 'anza', 'adores', 'ador',
      'ando', 'iendo', 'ieron', 'aron', 'emos', 'aran', 'eran',
      'ajes', 'aje', 'osas', 'osos', 'osa', 'oso',
    ]) {
      if (w.length > suffix.length + 3 && w.endsWith(suffix)) {
        return w.substring(0, w.length - suffix.length);
      }
    }

    if (w.length > 5 && w.endsWith('es')) {
      w = w.substring(0, w.length - 2);
    } else if (w.length > 4 && w.endsWith('s')) {
      w = w.substring(0, w.length - 1);
    }

    if (w.length > 5 &&
        (w.endsWith('ar') || w.endsWith('er') || w.endsWith('ir'))) {
      w = w.substring(0, w.length - 2);
    }
    return w;
  }

  static _AnalyzedQuery _analyzeQuery(String query) {
    final norm = Hymn.normalizeString(query);
    final tokens = norm
        .replaceAll(_nonAlnumSpaceRegex, ' ')
        .split(_whitespaceRegex)
        .where((w) => w.length >= 2 && !_stopwords.contains(w))
        .toList();

    final primaryTerms = <String>[];
    final primaryStems = <String>{};
    for (final t in tokens) {
      if (t.length >= 3) {
        if (!primaryTerms.contains(t)) primaryTerms.add(t);
        primaryStems.add(stemSpanishWord(t));
      }
    }

    final matchedConcepts = <_BiblicalConcept>[];
    final expansionTerms = <String>{};
    final expansionStems = <String>{};

    for (final concept in _biblicalConcepts) {
      bool triggered = false;
      for (final trig in concept.triggers) {
        if (norm.contains(trig)) {
          triggered = true;
          break;
        }
        final trigStem = stemSpanishWord(trig);
        if (!trig.contains(' ') &&
            trig.length >= 4 &&
            primaryStems.any((ps) => ps == trigStem || ps == trig)) {
          triggered = true;
          break;
        }
      }
      if (triggered) {
        matchedConcepts.add(concept);
        for (final exp in concept.expansions) {
          if (!primaryTerms.contains(exp)) {
            expansionTerms.add(exp);
            expansionStems.add(stemSpanishWord(exp));
          }
        }
      }
    }

    // Construir frases bigram de 2 palabras clave del usuario para premio extra
    final bigrams = <String>[];
    for (int i = 0; i < tokens.length - 1; i++) {
      if (tokens[i].length >= 3 && tokens[i + 1].length >= 3) {
        bigrams.add('${tokens[i]} ${tokens[i + 1]}');
      }
    }

    return _AnalyzedQuery(
      normalizedQuery: norm,
      primaryTerms: primaryTerms,
      primaryStems: primaryStems.toList(),
      expansionTerms: expansionTerms.toList(),
      expansionStems: expansionStems.toList(),
      matchedConcepts: matchedConcepts,
      bigrams: bigrams,
    );
  }

  /// Calcula la similitud coseno contra el vector int8 precomputado del canto (si existe).
  static double? _vectorSimilarity(Hymn hymn, List<double>? queryVector) {
    if (queryVector == null ||
        _embeddingVectorsRaw == null ||
        _embeddingDims <= 0 ||
        queryVector.length != _embeddingDims) {
      return null;
    }
    final key = '${hymn.collection}-${hymn.id}';
    final rowIdx = _embeddingRowByKey[key];
    if (rowIdx == null) return null;

    final offset = rowIdx * _embeddingDims;
    final bytes = _embeddingVectorsRaw!;
    if (offset + _embeddingDims > bytes.length) return null;

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int d = 0; d < _embeddingDims; d++) {
      // Los bytes almacenan int8 firmado en complemento a dos
      int signedVal = bytes[offset + d];
      if (signedVal > 127) signedVal -= 256;
      final a = signedVal / 127.0;
      final b = queryVector[d];
      dot += a * b;
      normA += a * a;
      normB += b * b;
    }
    if (normA <= 0 || normB <= 0) return null;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  static _HymnScore _scoreHymn(
    Hymn hymn,
    _AnalyzedQuery analyzed, {
    List<double>? queryVector,
  }) {
    final normTitle = hymn.normalizedTitle;
    final normCleanLyrics = Hymn.normalizeString(cleanLyrics(hymn.lyrics));
    final lyricWords = normCleanLyrics
        .replaceAll(_nonAlnumSpaceRegex, ' ')
        .split(_whitespaceRegex)
        .where((w) => w.length >= 2)
        .toList();
    final titleWords = normTitle
        .replaceAll(_nonAlnumSpaceRegex, ' ')
        .split(_whitespaceRegex)
        .where((w) => w.length >= 2)
        .toList();

    final lyricWordSet = lyricWords.toSet();
    final lyricStems = lyricWordSet.map(stemSpanishWord).toSet();
    final titleWordSet = titleWords.toSet();
    final titleStems = titleWordSet.map(stemSpanishWord).toSet();

    double score = 0.0;
    final matchedPrimary = <String>[];
    final matchedExpanded = <String>[];
    bool titleHit = false;

    // 1. Coincidencias directas del texto de búsqueda en Título y Letra completa
    for (final term in analyzed.primaryTerms) {
      final stem = stemSpanishWord(term);
      final inTitle = titleWordSet.contains(term) ||
          normTitle.contains(term) ||
          (stem.length >= 4 && titleStems.contains(stem));
      final inLyricsExact = lyricWordSet.contains(term);
      final inLyricsStem = stem.length >= 4 && lyricStems.contains(stem);

      if (inTitle) {
        score += 24.0;
        titleHit = true;
        if (!matchedPrimary.contains(term)) matchedPrimary.add(term);
      }
      if (inLyricsExact) {
        score += 14.0;
        if (!matchedPrimary.contains(term)) matchedPrimary.add(term);
      } else if (inLyricsStem) {
        score += 10.0;
        if (!matchedPrimary.contains(term)) matchedPrimary.add(term);
      }
    }

    // 2. Coincidencia de frases (bigramas) y frase completa
    if (analyzed.normalizedQuery.length >= 6 &&
        normCleanLyrics.contains(analyzed.normalizedQuery)) {
      score += 45.0;
    }
    for (final bg in analyzed.bigrams) {
      if (normTitle.contains(bg)) {
        score += 26.0;
        titleHit = true;
      } else if (normCleanLyrics.contains(bg)) {
        score += 18.0;
      }
    }

    // 3. Coincidencias conceptuales / teológicas en Título y Letra completa
    for (final exp in analyzed.expansionTerms) {
      final expStem = stemSpanishWord(exp);
      final inTitle = titleWordSet.contains(exp) ||
          (expStem.length >= 4 && titleStems.contains(expStem));
      final inLyrics = lyricWordSet.contains(exp) ||
          (expStem.length >= 4 && lyricStems.contains(expStem));

      if (inTitle) {
        score += 11.0;
        if (!matchedExpanded.contains(exp)) matchedExpanded.add(exp);
      } else if (inLyrics) {
        score += 6.5;
        if (!matchedExpanded.contains(exp)) matchedExpanded.add(exp);
      }
    }

    // 4. Cobertura múltiple (premia cantos que conectan con varios conceptos a la vez)
    if (matchedPrimary.length >= 2) {
      score += matchedPrimary.length * 7.0;
    }
    if (matchedExpanded.length >= 3) {
      score += math.min(matchedExpanded.length, 6) * 3.5;
    }

    // 5. Similitud coseno vectorial (si está disponible el vector del query)
    final vecSim = _vectorSimilarity(hymn, queryVector);
    if (vecSim != null && vecSim > 0.48) {
      // Escala suave para combinar semántica profunda con señales léxicas
      score += (vecSim - 0.45) * 140.0;
    }

    // 6. Verificar si es canto nuevo o modificado respecto al asset embebido
    final key = '${hymn.collection}-${hymn.id}';
    final isNewOrModified = hymn.isLocalOnly ||
        (_embeddingHashByKey.isNotEmpty && !_embeddingRowByKey.containsKey(key));

    return _HymnScore(
      hymn: hymn,
      score: score,
      vectorSimilarity: vecSim,
      titleHit: titleHit,
      matchedPrimary: matchedPrimary,
      matchedExpanded: matchedExpanded,
      matchedConcepts: analyzed.matchedConcepts,
      isNewOrModified: isNewOrModified,
    );
  }

  /// Construye un pool compacto de candidatos (top `perCollectionLimit` por colección seleccionada),
  /// incluyendo resúmenes limpios de la letra real para que Gemini lea la letra antes de decidir.
  static Map<String, List<Map<String, dynamic>>> buildCandidatePool({
    required String query,
    required List<Hymn> catalog,
    required Set<String> allowedCollections,
    List<double>? queryVector,
    int perCollectionLimit = 22,
  }) {
    final analyzed = _analyzeQuery(query);
    final pool = <String, List<Map<String, dynamic>>>{};

    for (final col in collectionOrder) {
      if (!allowedCollections.contains(col)) continue;

      final colHymns = catalog.where((h) => h.collection == col).toList();
      final scored = colHymns
          .map((h) => _scoreHymn(h, analyzed, queryVector: queryVector))
          .toList();

      scored.sort((a, b) {
        final cmp = b.score.compareTo(a.score);
        if (cmp != 0) return cmp;
        if (a.isNewOrModified != b.isNewOrModified) {
          return a.isNewOrModified ? -1 : 1;
        }
        return a.hymn.id.compareTo(b.hymn.id);
      });

      final selected = <_HymnScore>[];
      final seenKeys = <String>{};

      for (final item in scored) {
        if (selected.length >= perCollectionLimit) break;
        selected.add(item);
        seenKeys.add('${item.hymn.collection}-${item.hymn.id}');
      }

      // Garantizar espacio a cantos recién agregados/locales (hasta 3 cupos adicionales)
      // para que cualquier canto nuevo subido a la BD pueda ser evaluado aunque use otras palabras.
      int extraNew = 0;
      for (final item in scored) {
        if (extraNew >= 3) break;
        final k = '${item.hymn.collection}-${item.hymn.id}';
        if (!seenKeys.contains(k) && item.isNewOrModified) {
          selected.add(item);
          seenKeys.add(k);
          extraNew++;
        }
      }

      pool[col] = selected.map((s) {
        return {
          'id': s.hymn.id,
          'collection': s.hymn.collection,
          'title': s.hymn.title,
          'digest': buildCompactDigest(s.hymn, maxChars: 440),
        };
      }).toList();
    }

    return pool;
  }

  /// Ejecuta búsqueda local/offline agrupada por colección (`iump`, `especiales`, `coros`),
  /// devolviendo hasta 10 resultados genuinos por colección sin rellenar con falsos positivos.
  static Map<String, dynamic> searchLocally({
    required String query,
    required List<Hymn> catalog,
    required Set<String> allowedCollections,
    required String searchMode,
    List<double>? queryVector,
    bool quotaFallback = false,
  }) {
    final analyzed = _analyzeQuery(query);
    final collectionsData = <String, Map<String, dynamic>>{};
    final flatMatches = <Map<String, dynamic>>[];

    // Umbral mínimo estricto para NO rellenar con cantos sin vínculo real
    final double minThreshold = analyzed.matchedConcepts.isNotEmpty ? 15.0 : 18.0;

    for (final col in collectionOrder) {
      if (!allowedCollections.contains(col)) continue;

      final colHymns = catalog.where((h) => h.collection == col).toList();
      final scored = colHymns
          .map((h) => _scoreHymn(h, analyzed, queryVector: queryVector))
          .where((s) => s.score >= minThreshold)
          .toList();

      scored.sort((a, b) => b.score.compareTo(a.score));

      final top = scored.take(maxResultsPerCollection).toList();
      final matches = <Map<String, dynamic>>[];

      for (final item in top) {
        final matchObj = _buildMatchMap(item, analyzed, searchMode);
        matches.add(matchObj);
        flatMatches.add(matchObj);
      }

      final noMoreReason = buildDefaultNoMoreReason(
        collection: col,
        foundCount: matches.length,
        maxLimit: maxResultsPerCollection,
      );

      collectionsData[col] = {
        'matches': matches,
        'noMoreReason': noMoreReason,
      };
    }

    final detectedThemes = analyzed.matchedConcepts.map((c) => c.label).toList();
    final keywords = <String>{
      ...analyzed.primaryTerms.take(4),
      ...analyzed.expansionTerms.take(4),
    }.take(6).toList();

    final String summaryText = quotaFallback
        ? 'Se alcanzó temporalmente la cuota gratuita de Gemini IA; mostramos los cantos más acertados analizando todas las letras localmente.'
        : 'Búsqueda local profunda sobre todas las letras del catálogo (Modo sin conexión).';

    final String contextText = detectedThemes.isNotEmpty
        ? 'Temas espirituales detectados: ${detectedThemes.join(' · ')}. Resultados evaluados directamente sobre título, coro y estrofas de toda la base de datos.'
        : 'Resultados evaluados localmente sobre título, coro y estrofas completas de toda la base de datos.';

    return {
      'summary': summaryText,
      'biblicalPassage': null,
      'biblicalContext': contextText,
      'spiritualTone':
          detectedThemes.isNotEmpty ? detectedThemes.first : 'Alabanza y Fe',
      'keywords': keywords,
      'collections': collectionsData,
      'matches': flatMatches,
      'isLocalFallback': true,
      'quotaReached': quotaFallback,
    };
  }

  static String _buildLocalReason(_HymnScore item, _AnalyzedQuery analyzed) {
    final snippet = _findRelevantLineSnippet(item.hymn, analyzed);
    final terms = <String>[
      ...item.matchedPrimary,
      ...item.matchedExpanded,
    ].take(4).toList();

    if (snippet != null && snippet.isNotEmpty) {
      final prefix = item.matchedPrimary.isNotEmpty
          ? 'Coincidencia directa en la letra'
          : 'Afinidad temática en la letra';
      return '$prefix: «$snippet»';
    }
    if (item.titleHit && terms.isNotEmpty) {
      return 'Relación directa desde el título y mensaje (${terms.join(', ')}).';
    }
    if (terms.isNotEmpty) {
      return 'Aborda conceptos afines a esta búsqueda (${terms.join(', ')}).';
    }
    if (item.vectorSimilarity != null) {
      return 'Alta cercanía semántica con el mensaje espiritual consultado.';
    }
    return 'Coincidencia temática con la enseñanza consultada.';
  }

  static String? _findRelevantLineSnippet(Hymn hymn, _AnalyzedQuery analyzed) {
    final lines = cleanLyrics(hymn.lyrics)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length >= 12)
        .toList();

    final searchTerms = <String>[
      ...analyzed.primaryTerms,
      ...analyzed.expansionTerms,
    ];
    if (searchTerms.isEmpty || lines.isEmpty) return null;

    String? bestLine;
    int bestHits = 0;

    for (final line in lines) {
      final normLine = Hymn.normalizeString(line);
      int hits = 0;
      for (final term in analyzed.primaryTerms) {
        if (normLine.contains(term)) hits += 3;
      }
      for (final exp in analyzed.expansionTerms) {
        if (normLine.contains(exp)) hits += 1;
      }
      if (hits > bestHits) {
        bestHits = hits;
        bestLine = line;
      }
    }

    if (bestLine == null || bestHits == 0) return null;
    if (bestLine.length > 95) {
      return '${bestLine.substring(0, 92).trimRight()}…';
    }
    return bestLine;
  }

  /// Mensajes descriptivos de UX/UI para cuando una colección tiene 0 o menos de 10 resultados.
  static String buildDefaultNoMoreReason({
    required String collection,
    required int foundCount,
    int maxLimit = maxResultsPerCollection,
  }) {
    final name = collectionDisplayName(collection);
    if (foundCount <= 0) {
      switch (collection) {
        case 'iump':
          return 'Revisamos todo el Himnario IUMP y no encontramos himnos que aborden directamente este pasaje o concepto. Revisa las otras colecciones o intenta describir el tema central con otras palabras.';
        case 'especiales':
          return 'Ninguna alabanza especial de toda la base de datos desarrolla específicamente esta enseñanza o metáfora. Puedes explorar las otras secciones o ampliar la búsqueda con una palabra clave.';
        case 'coros':
          return 'No hallamos coros en Coros de Avivamiento que se vinculen con claridad a esta búsqueda. Te sugerimos probar con un concepto espiritual más amplio (por ejemplo: «fe», «consuelo» o «victoria»).';
        default:
          return 'No se encontraron cantos relacionados en $name.';
      }
    }

    if (foundCount < maxLimit) {
      switch (collection) {
        case 'iump':
          return foundCount == 1
              ? 'Este es el único himno en todo el Himnario IUMP con vínculo genuino para esta búsqueda. No incluimos más para evitar sugerencias forzadas.'
              : 'Estos son los $foundCount himnos más acertados en todo el Himnario IUMP. No se encontraron más himnos con relación real para esta enseñanza o tema.';
        case 'especiales':
          return foundCount == 1
              ? 'Esta es la única alabanza especial con vínculo espiritual directo encontrada en la base de datos. No hallamos más especiales relacionados.'
              : 'Mostrando las $foundCount alabanzas especiales más pertinentes de toda la base de datos. No se encontraron más especiales con vínculo directo para esta búsqueda.';
        case 'coros':
          return foundCount == 1
              ? 'Este es el único coro en Coros de Avivamiento directamente relacionado con el enfoque consultado.'
              : 'Estos son los $foundCount coros más relacionados encontrados en Coros de Avivamiento. No hay más coros en esta colección que desarrollen directamente este tema.';
        default:
          return 'No se encontraron más cantos relacionados en $name.';
      }
    }

    return 'Mostrando los $maxLimit cantos más acertados de $name.';
  }

  static Map<String, dynamic> _buildMatchMap(
    _HymnScore item,
    _AnalyzedQuery analyzed,
    String searchMode, {
    bool isExtraLocal = false,
  }) {
    final reason = _buildLocalReason(item, analyzed);
    final moment = analyzed.matchedConcepts.isNotEmpty
        ? analyzed.matchedConcepts.first.worshipMoment
        : (searchMode == 'biblical'
            ? 'Sellar la Predicación'
            : 'Alabanza Congregacional');
    final affinity = item.score >= 40.0 ||
            item.matchedPrimary.length >= 2 ||
            (item.vectorSimilarity ?? 0) >= 0.72
        ? 'alta'
        : 'media';

    return {
      'hymn': item.hymn,
      'relevanceReason': reason,
      'worshipMoment': moment,
      'relevanceLevel': affinity,
      if (isExtraLocal) 'isExtraLocal': true,
    };
  }

  /// Busca coincidencias locales adicionales (#11+) por colección excluyendo
  /// los cantos ya mostrados inicialmente, aplicando un filtro más estricto
  /// contra el desvío temático y un tope máximo de 3 bloques de 10 (30 extras).
  static Map<String, AdditionalMatchesPool> findAdditionalMatchesByCollection({
    required String query,
    required List<Hymn> catalog,
    required Map<String, Set<int>> excludedIdsByCollection,
    required Set<String> allowedCollections,
    required String searchMode,
    List<double>? queryVector,
  }) {
    final analyzed = _analyzeQuery(query);
    final double extraMinFloor =
        analyzed.matchedConcepts.isNotEmpty ? 20.0 : 24.0;
    final pools = <String, AdditionalMatchesPool>{};

    for (final col in collectionOrder) {
      if (!allowedCollections.contains(col)) continue;

      final excludedIds = excludedIdsByCollection[col] ?? const <int>{};
      final colHymns = catalog.where((h) => h.collection == col).toList();
      final scoredAll = colHymns
          .map((h) => _scoreHymn(h, analyzed, queryVector: queryVector))
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      final double anchorScore =
          scoredAll.isNotEmpty ? scoredAll.first.score : 0.0;
      final double driftFloor = math.max(
        extraMinFloor,
        math.min(anchorScore, 75.0) * 0.34,
      );

      final passing = <Map<String, dynamic>>[];
      bool hasMarginalDriftCandidates = false;

      for (final item in scoredAll) {
        if (excludedIds.contains(item.hymn.id)) continue;

        final bool hasSolidSignal = item.titleHit ||
            item.matchedPrimary.length >= 2 ||
            (item.matchedPrimary.isNotEmpty &&
                item.matchedExpanded.isNotEmpty) ||
            item.matchedExpanded.length >= 3 ||
            (item.vectorSimilarity ?? 0) >= 0.58 ||
            item.score >= 30.0;

        if (item.score >= driftFloor && hasSolidSignal) {
          passing.add(
            _buildMatchMap(
              item,
              analyzed,
              searchMode,
              isExtraLocal: true,
            ),
          );
        } else if (item.score >= 12.0) {
          hasMarginalDriftCandidates = true;
        }
      }

      final bool hitBatchCap =
          passing.length > maxAdditionalResultsPerCollection;
      final cappedCandidates = hitBatchCap
          ? passing.take(maxAdditionalResultsPerCollection).toList()
          : passing;

      final colName = collectionDisplayName(col);
      final String exhaustReason;
      if (hitBatchCap) {
        exhaustReason =
            'Se alcanzó el máximo recomendado de $maxAdditionalResultsPerCollection sugerencias adicionales en $colName (hasta $maxAdditionalBatchesPerCollection bloques de $additionalBatchSize) para mantener la lista enfocada en la predicación.';
      } else if (hasMarginalDriftCandidates) {
        exhaustReason = cappedCandidates.isEmpty
            ? 'No hay más sugerencias locales en $colName con afinidad sólida; los demás cantos del catálogo se alejan del tema central o solo coinciden en palabras aisladas.'
            : 'La expansión en $colName se detuvo aquí porque los siguientes cantos del catálogo se alejan del enfoque central o solo comparten palabras sueltas.';
      } else {
        exhaustReason =
            'Ya exploramos todo $colName y no quedan más cantos con relación directa a esta enseñanza.';
      }

      pools[col] = AdditionalMatchesPool(
        candidates: cappedCandidates,
        stoppedForDrift: hasMarginalDriftCandidates,
        hitBatchCap: hitBatchCap,
        exhaustReason: exhaustReason,
      );
    }

    return pools;
  }

  static String collectionDisplayName(String collection) {
    switch (collection) {
      case 'iump':
        return 'Himnario IUMP';
      case 'especiales':
        return 'Alabanzas Especiales';
      case 'coros':
        return 'Coros de Avivamiento';
      default:
        return collection.toUpperCase();
    }
  }
}

/// Resultado de expansión local adicional (#11+) con control de desvío temático.
class AdditionalMatchesPool {
  final List<Map<String, dynamic>> candidates;
  final bool stoppedForDrift;
  final bool hitBatchCap;
  final String exhaustReason;

  const AdditionalMatchesPool({
    required this.candidates,
    required this.stoppedForDrift,
    required this.hitBatchCap,
    required this.exhaustReason,
  });
}

class _BiblicalConcept {
  final String id;
  final String label;
  final List<String> triggers;
  final List<String> expansions;
  final String worshipMoment;

  const _BiblicalConcept({
    required this.id,
    required this.label,
    required this.triggers,
    required this.expansions,
    required this.worshipMoment,
  });
}

class _AnalyzedQuery {
  final String normalizedQuery;
  final List<String> primaryTerms;
  final List<String> primaryStems;
  final List<String> expansionTerms;
  final List<String> expansionStems;
  final List<_BiblicalConcept> matchedConcepts;
  final List<String> bigrams;

  const _AnalyzedQuery({
    required this.normalizedQuery,
    required this.primaryTerms,
    required this.primaryStems,
    required this.expansionTerms,
    required this.expansionStems,
    required this.matchedConcepts,
    required this.bigrams,
  });
}

class _HymnScore {
  final Hymn hymn;
  final double score;
  final double? vectorSimilarity;
  final bool titleHit;
  final List<String> matchedPrimary;
  final List<String> matchedExpanded;
  final List<_BiblicalConcept> matchedConcepts;
  final bool isNewOrModified;

  const _HymnScore({
    required this.hymn,
    required this.score,
    required this.vectorSimilarity,
    required this.titleHit,
    required this.matchedPrimary,
    required this.matchedExpanded,
    required this.matchedConcepts,
    required this.isNewOrModified,
  });
}
