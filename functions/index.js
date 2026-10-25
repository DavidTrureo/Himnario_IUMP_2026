const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getStorage } = require("firebase-admin/storage");
const admin = require("firebase-admin");
const youtubedl = require("youtube-dl-exec");
const path = require("path");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");

admin.initializeApp();

// Clave API de Gemini del servidor (proyecto gen-lang-client-0755441710)
const SERVER_GEMINI_KEY = process.env.GEMINI_API_KEY || "AQ.Ab8RN6LMJy9J1QN_8lmyiI0Sq57kavrWWN8O2ST8b07Qbf1eKQ";

const GEMINI_MODELS = [
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-2.0-flash",
  "gemini-2.5-pro",
  "gemini-2.0-flash-lite",
];

/**
 * Función genérica para invocar Gemini con fallback en cascada de modelos
 */
async function callGeminiApi({ prompt, inlineData = null, jsonOutput = true, temperature = 0.2, apiKey = null }) {
  const effectiveKey = (apiKey && apiKey.trim().length > 0) ? apiKey.trim() : SERVER_GEMINI_KEY;

  const parts = [{ text: prompt }];
  if (inlineData && inlineData.data) {
    parts.push({
      inlineData: {
        mimeType: inlineData.mimeType || "image/jpeg",
        data: inlineData.data,
      },
    });
  }

  const requestBody = JSON.stringify({
    contents: [{ parts }],
    generationConfig: {
      ...(jsonOutput ? { response_mime_type: "application/json" } : {}),
      temperature,
    },
  });

  let lastError = null;
  for (const model of GEMINI_MODELS) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${effectiveKey}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: requestBody,
      });

      if (res.ok) {
        const jsonRes = await res.json();
        const candidates = jsonRes.candidates;
        if (candidates && candidates.length > 0) {
          const resParts = candidates[0].content && candidates[0].content.parts;
          if (resParts && resParts.length > 0) {
            let text = resParts[0].text || "";
            if (jsonOutput) {
              text = text.replace(/```json/g, "").replace(/```/g, "").trim();
              return { data: JSON.parse(text), modelUsed: model, success: true };
            }
            return { text, modelUsed: model, success: true };
          }
        }
      } else {
        const errText = await res.text();
        console.warn(`Model ${model} returned ${res.status}: ${errText}`);
        lastError = `Status ${res.status}: ${errText}`;
      }
    } catch (e) {
      console.warn(`Model ${model} exception: ${e.message}`);
      lastError = e.message;
    }
  }

  throw new Error(`Gemini API failure: ${lastError}`);
}

exports.extractAudio = onCall({
  timeoutSeconds: 300,
  memory: "512MiB",
}, async (request) => {
  const data = request.data;
  const youtubeUrl = data.url;

  if (!youtubeUrl) {
    throw new HttpsError("invalid-argument", "The function must be called with a 'url' argument.");
  }

  if (!youtubeUrl.includes("youtube.com") && !youtubeUrl.includes("youtu.be")) {
    throw new HttpsError("invalid-argument", "Please provide a valid YouTube URL.");
  }

  try {
    console.log(`Starting extraction for URL: ${youtubeUrl}`);
    const tempFilePath = path.join(os.tmpdir(), `yt_${Date.now()}`);

    await youtubedl(youtubeUrl, {
      extractAudio: true,
      audioFormat: 'mp3',
      format: '140/bestaudio[ext=m4a]/bestaudio',
      output: `${tempFilePath}.%(ext)s`,
      noCheckCertificates: true,
      noWarnings: true
    });

    const finalFilePath = `${tempFilePath}.mp3`;
    console.log(`Successfully downloaded to ${finalFilePath}`);

    const bucket = getStorage().bucket();
    const destinationPath = `hymns_audio/yt_extracted_${Date.now()}.mp3`;

    console.log(`Uploading to Firebase Storage at ${destinationPath}`);
    await bucket.upload(finalFilePath, {
      destination: destinationPath,
      metadata: {
        contentType: 'audio/mp3',
      },
    });

    const file = bucket.file(destinationPath);
    const uuid = crypto.randomUUID();
    await file.setMetadata({
      metadata: {
        firebaseStorageDownloadTokens: uuid,
      }
    });

    const bucketName = bucket.name;
    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(destinationPath)}?alt=media&token=${uuid}`;

    console.log(`Upload complete. URL: ${downloadUrl}`);

    if (fs.existsSync(finalFilePath)) {
      fs.unlinkSync(finalFilePath);
    }

    return { audioUrl: downloadUrl };
  } catch (error) {
    console.error("Error extracting audio:", error);
    try {
      const files = fs.readdirSync(os.tmpdir());
      files.forEach(f => {
        if (f.startsWith('yt_')) {
          fs.unlinkSync(path.join(os.tmpdir(), f));
        }
      });
    } catch (cleanupError) {}
    
    throw new HttpsError("internal", `Failed to extract audio: ${error.message}`);
  }
});

/**
 * Asistente Bíblico con IA y Búsqueda Semántica
 * Incluye sistema de caché en Firestore (ai_bible_cache) para responder en milisegundos sin consumir cuota
 */
exports.searchHymnsWithAi = onCall({
  timeoutSeconds: 60,
  memory: "512MiB",
}, async (request) => {
  const data = request.data || {};
  const query = (data.query || "").trim();
  const searchMode = data.searchMode || "biblical"; // 'biblical' o 'conceptual'
  const catalogIndex = (data.catalogIndex || "").trim();
  const userApiKey = (data.apiKey || "").trim();

  if (!query) {
    throw new HttpsError("invalid-argument", "query is required");
  }

  // Generar hash determinístico de la consulta para caché
  const normQuery = query.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9 ]/g, "").trim();
  const cacheKey = crypto.createHash("sha256").update(`${normQuery}_${searchMode}`).digest("hex").substring(0, 32);

  const db = admin.firestore();
  const cacheDocRef = db.collection("ai_bible_cache").doc(cacheKey);

  try {
    const cachedSnap = await cacheDocRef.get();
    if (cachedSnap.exists) {
      const cached = cachedSnap.data();
      if (cached && cached.response) {
        console.log(`[Cache HIT] Consulta respondida desde Firestore: "${query}"`);
        return {
          ...cached.response,
          fromCache: true,
          success: true,
        };
      }
    }
  } catch (cacheErr) {
    console.warn("Error leyendo ai_bible_cache:", cacheErr.message);
  }

  const modeGuidance = searchMode === "biblical"
    ? `MODO: ASISTENTE BÍBLICO Y HERMENÉUTICA DE PREDICACIÓN / SERMÓN
Misión: Actuar como un erudito teólogo bíblico, pastor e himnólogo cristiano con profundo conocimiento de las Sagradas Escrituras (Biblia Reina-Valera 1960) y de la himnología evangélica pentecostal (Himnario Oficial IUMP, Alabanzas Especiales y Coros Pentecostales).

REGLA DE ORO FUNDAMENTAL:
QUEDA ESTRICTAMENTE PROHIBIDO buscar por simple coincidencia superficial de palabras textuales aisladas.
Tu función como IA Bíblica Avanzada es comprender el fondo teológico y espiritual:

1. LOCALIZACIÓN E IDENTIFICACIÓN BÍBLICA:
   - Identifica con precisión qué pasaje sagrado es (Libro, Capítulo y Versículos) y regístralo en "biblicalPassage" (ej: "Isaías 43:1-3", "Salmo 23:1-6", "1 Reyes 19:4-8", "Efesios 6:10-18", "Lucas 15:11-32").

2. EXÉGESIS Y CONTEXTO ESPIRITUAL REAL:
   - En "biblicalContext", analiza en 2-3 oraciones el sentido espiritual profundo: el trasfondo histórico-doctrinal, qué necesidad del alma atiende y las promesas de Dios.
   - En "spiritualTone", define la atmósfera espiritual (ej: "Consagración", "Fe en la Prueba", "Guerra Espiritual", "Consuelo y Esperanza", "Gracia y Perdón", "Adoración y Alabanza").

3. HERMENÉUTICA CON EL CATÁLOGO DE CANTOS:
   - Selecciona entre 4 y 7 cantos del catálogo cuyo mensaje abrace esta palabra, AUNQUE EL CANTO NO CONTENGA LAS PALABRAS LITERALES.
   - "worshipMoment": Momento litúrgico idóneo ("Sellar la Predicación", "Llamado al Altar / Consagración", "Oración de Fe / Afligidos", "Alabanza Congregacional").
   - "relevanceReason": Explica con claridad pastoral por qué verdad teológica o estrofa se vincula con la enseñanza bíblica.`
    : `MODO: BÚSQUEDA CONCEPTUAL Y METAFÓRICA DE CANTOS
Misión: Ayudar a encontrar cantos a partir de un recuerdo difuso, metáfora, frase o historia:
1. Analiza el sentido poético y espiritual de la consulta.
2. Identifica los cantos del catálogo que abordan directa o metafóricamente estas ideas.
3. En "relevanceReason", detalla por qué coincide.
4. En "worshipMoment", sugiere el momento del culto adecuado.`;

  const promptText = `${modeGuidance}

CONSULTA DEL MINISTRO O CONGREGANTE:
"${query}"

CATÁLOGO OFICIAL DE CANTOS DISPONIBLES EN LA APP [ID|COLECCIÓN|TÍTULO]:
${catalogIndex}

RESPONDE EXCLUSIVAMENTE CON UN OBJETO JSON VÁLIDO (sin bloques de código markdown \`\`\`json, sin texto adicional):
{
  "summary": "Breve resumen del mensaje o concepto (1 frase)",
  "biblicalPassage": "Libro Capítulo:Versículos identificados (ej: Isaías 43:1-3, Salmo 23:1-6)",
  "biblicalContext": "Análisis exegético del pasaje bíblico o trasfondo doctrinal del sermón (2-3 oraciones claras)",
  "spiritualTone": "Consagración | Fe en la Prueba | Consuelo y Esperanza | Guerra Espiritual | Gracia y Perdón | Adoración",
  "results": [
    {
      "id": 123,
      "collection": "iump",
      "title": "TÍTULO DEL CANTO",
      "relevanceReason": "Conexión pastoral/doctrinal...",
      "worshipMoment": "Sellar la Predicación | Llamado al Altar | Oración de Fe | Congregacional"
    }
  ],
  "keywords": ["tema1", "tema2"]
}`;

  try {
    const aiResult = await callGeminiApi({
      prompt: promptText,
      jsonOutput: true,
      temperature: 0.2,
      apiKey: userApiKey,
    });

    const responsePayload = aiResult.data;

    // Guardar en Firestore ai_bible_cache asíncronamente
    cacheDocRef.set({
      originalQuery: query,
      normalizedQuery: normQuery,
      searchMode,
      response: responsePayload,
      modelUsed: aiResult.modelUsed,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }).catch(e => console.warn("Error guardando en caché:", e.message));

    return {
      ...responsePayload,
      fromCache: false,
      modelUsed: aiResult.modelUsed,
      success: true,
    };
  } catch (error) {
    console.error("Error en searchHymnsWithAi:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Escaneo OCR inteligente de fotografías de partituras/letras con IA
 */
exports.scanHymnWithAi = onCall({
  timeoutSeconds: 60,
  memory: "512MiB",
}, async (request) => {
  const data = request.data || {};
  const base64Image = data.base64Image;
  const mimeType = data.mimeType || "image/jpeg";
  const userApiKey = (data.apiKey || "").trim();

  if (!base64Image) {
    throw new HttpsError("invalid-argument", "base64Image is required");
  }

  const promptText = `Eres un experto transcriptor de cantos e himnos cristianos. Analiza la imagen adjunta, que contiene la letra de un canto (puede tener acordes escritos arriba o entremedio).
Extrae la información y devuélvela ESTRICTAMENTE en formato JSON:
1. "title": Título de la canción (o "Título Desconocido").
2. "key": Tonalidad si está indicada (ej: "Sol Mayor", "La menor", "D", "Desconocida").
3. "timeSignature": Métrica si está indicada (ej: "4/4", "3/4", "Desconocida").
4. "lyrics": Extrae ÚNICAMENTE LA LETRA LIMPIA del canto. IGNORA COMPLETAMENTE TODOS LOS ACORDES que aparezcan arriba o entre las palabras (por ejemplo C, D, Em, LAm, DO, RE, SOL, etc.). Devuelve un texto limpio, ordenado prolijamente en estrofas y coros cantables.

JSON esperado:
{
  "title": "...",
  "key": "...",
  "timeSignature": "...",
  "lyrics": "..."
}`;

  try {
    const aiResult = await callGeminiApi({
      prompt: promptText,
      inlineData: { data: base64Image, mimeType },
      jsonOutput: true,
      temperature: 0.2,
      apiKey: userApiKey,
    });

    return {
      title: aiResult.data.title || "",
      key: aiResult.data.key || "",
      timeSignature: aiResult.data.timeSignature || "",
      lyrics: aiResult.data.lyrics || "",
      modelUsed: aiResult.modelUsed,
      success: true,
    };
  } catch (error) {
    console.error("Error en scanHymnWithAi:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Búsqueda de letras de himnos en internet mediante IA
 */
exports.searchOnlineHymnWithAi = onCall({
  timeoutSeconds: 45,
  memory: "256MiB",
}, async (request) => {
  const data = request.data || {};
  const query = (data.query || "").trim();
  const userApiKey = (data.apiKey || "").trim();

  if (!query) {
    throw new HttpsError("invalid-argument", "query is required");
  }

  const promptText = `Eres un himnólogo experto cristiano evangélico y pentecostal. Busca y provee la letra completa, auténtica y correcta del himno o coro cristiano solicitado: "${query}".
Devuelve ÚNICAMENTE un JSON con:
{
  "title": "TÍTULO EN MAYÚSCULAS",
  "lyrics": "Letra completa con sus estrofas y coro debidamente ordenados",
  "author": "Nombre del autor o 'Tradicional' si se desconoce"
}`;

  try {
    const aiResult = await callGeminiApi({
      prompt: promptText,
      jsonOutput: true,
      temperature: 0.2,
      apiKey: userApiKey,
    });

    return {
      title: aiResult.data.title || query,
      lyrics: aiResult.data.lyrics || "",
      author: aiResult.data.author || "",
      modelUsed: aiResult.modelUsed,
      success: true,
    };
  } catch (error) {
    console.error("Error en searchOnlineHymnWithAi:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Corrector ortográfico y gramatical RAE con IA
 */
exports.correctGrammarWithAi = onCall({
  timeoutSeconds: 60,
  memory: "256MiB",
}, async (request) => {
  const data = request.data || {};
  const title = (data.title || "").trim();
  const lyrics = (data.lyrics || "").trim();
  const userApiKey = (data.apiKey || "").trim();

  if (!lyrics) {
    throw new HttpsError("invalid-argument", "lyrics is required");
  }

  const promptText = `Actúa como un corrector de estilo y editor lingüístico experto, aplicando estrictamente las normas ortográficas, gramaticales y de puntuación de la Real Academia Española (RAE). 

Tu tarea es revisar, corregir y formatear la letra de un canto cristiano respetando las siguientes reglas de manera obligatoria:

TÍTULO ORIGINAL:
${title}

LETRA ORIGINAL:
${lyrics}

REGLAS OBLIGATORIAS:
1. Mayúscula al inicio de cada línea:
   - Toda línea o verso DEBE iniciar siempre con letra mayúscula, sin importar el signo de puntuación de la línea anterior (estilo de versificación).
   - El resto de las palabras de la línea deben ir en minúsculas, salvo las excepciones indicadas en la regla 2.

2. Mayúsculas de respeto y nombres propios:
   - Nombres propios: Nombres de personas, ciudades, países, montes o regiones geográficas siempre inician con mayúscula (ej.: Jonás, Nínive, Jerusalén, Sinaí).
   - Nombres de la Deidad: Todas las personas de la Trinidad y sus nombres propios llevan mayúscula inicial (Dios, Jehová, Yahvé, Señor, Padre, Hijo, Jesús, Cristo, Redentor, Salvador, Espíritu Santo, Consolador).
   - Mayúscula reverencial y pronombres referidos a la Deidad: Escribe con mayúscula los pronombres o adjetivos cuando aludan directamente a Dios o a Cristo (Él, Tú, Tuyo, Santo, Creador, Omnipotente). Excepción estricta: Los pronombres posesivos de tercera persona (su, suyo, suya, sus, suyos) DEBEN ir siempre en minúscula (ej: "su amor", no "Su amor").

3. Acentuación y tildes según contexto (RAE):
   - Analiza el contexto de cada verso para colocar las tildes diacríticas obligatorias (ej.: distinguir «él/el», «tú/tu», «mí/mi», «sí/si», «más/mas», «sé/se», «dé/de»).
   - Elimina tildes innecesarias o desaconsejadas por la RAE (ej.: «solo» y los pronombres demostrativos «este, ese, aquel» van siempre sin tilde; «fe», «dio», «vio», «fue», «fui» no llevan tilde por ser monosílabos).
   - Corrige tiempos verbales conjugados en pasado o futuro (ej.: olvidó, quemó, perdonó, destruyó, costó, cantaré). ESTO ES VITAL.

4. Signos de puntuación (PUNTUACIÓN LIGERA, POÉTICA Y CONTEXTUAL):
   - PRIMERO, lee el canto completo, analiza su contexto y entiende la fluidez de las ideas. Con esa información, gestiona cuidadosamente las puntuaciones (comas, puntos y comas, dos puntos, puntos seguidos).
   - Añade signos de puntuación respetando estrictamente el estilo poético y el sentido de la letra.
   - NO pongas punto final al terminar cada verso a menos que la idea u oración gramatical realmente termine ahí. Es vital dejar el verso sin puntuación al final si la idea continúa en el siguiente verso (encabalgamiento).
   - Usa los puntos (seguidos o finales) PRINCIPALMENTE para separar ideas completas o al terminar una estrofa o coro.
   - Usa comas, puntos y comas, o dos puntos para pausas lógicas breves que den verdadero sentido y fluidez a la lectura.
   - Aplica los signos de interrogación o exclamación (¡!, ¿?) donde correspondan para dar expresividad.
   - Corrige preposiciones incorrectas (ej: "inspirándose a Jehová" -> "inspirándose en Jehová").

5. Estructura y Etiquetas (¡INTOCABLES!):
   - DEBES conservar EXACTAMENTE TODAS las etiquetas estructurales como "CORO:", "FINAL:", "PUENTE:", "1.", "2.", etc.
   - NO las elimines, no las traduzcas, no las modifiques, ni las fusiones con el texto. Mantenlas en su propia línea, con sus saltos de línea originales.

6. Formato de salida (¡MUY IMPORTANTE!):
   - NO incluyas viñetas ni explicaciones.
   - Devuelve ÚNICAMENTE y ESTRICTAMENTE un objeto JSON válido con dos campos: "title" y "lyrics". No agregues bloques markdown ni texto adicional.

JSON esperado:
{
  "title": "El título corregido (mantenlo en mayúsculas)",
  "lyrics": "La letra corregida aplicando todas las reglas anteriores. Conserva los saltos de línea (\\n)."
}`;

  try {
    const aiResult = await callGeminiApi({
      prompt: promptText,
      jsonOutput: true,
      temperature: 0.3,
      apiKey: userApiKey,
    });

    return {
      title: aiResult.data.title || title,
      lyrics: aiResult.data.lyrics || lyrics,
      modelUsed: aiResult.modelUsed,
      success: true,
    };
  } catch (error) {
    console.error("Error en correctGrammarWithAi:", error);
    throw new HttpsError("internal", error.message);
  }
});
