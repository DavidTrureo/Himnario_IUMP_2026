const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getStorage } = require("firebase-admin/storage");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const admin = require("firebase-admin");
const youtubedl = require("youtube-dl-exec");
const path = require("path");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");

admin.initializeApp();

// Clave API de Gemini exclusiva para Himnario (configurada vía functions/.env o Secret Manager, separada de SIS-Control)
const SERVER_GEMINI_KEY = (process.env.GEMINI_API_KEY || "").trim();
const RETIRED_SHARED_KEY_SHA256 = "313169b173414d3361ce77463c2084bb66fc0c245e30a5349ab761442dfd45b7";

const GEMINI_MODELS = [
  "gemini-3.6-flash",
  "gemini-3.5-flash-lite",
  "gemini-3.8-flash",
  "gemini-3.1-flash-lite",
  "gemini-flash-lite-latest",
  "gemini-flash-latest",
];

const SEARCH_GEMINI_MODELS = [
  "gemini-3.5-flash-lite",
  "gemini-3.1-flash-lite",
  "gemini-flash-lite-latest",
  "gemini-3.6-flash",
  "gemini-3.8-flash",
  "gemini-flash-latest",
];

const COLLECTION_ORDER = ["iump", "especiales", "coros"];
const MAX_RESULTS_PER_COLLECTION = 10;

let cachedDigestsMap = null;
let cachedEmbeddingsLoaded = false;
let cachedEmbeddingsMeta = null;
let cachedEmbeddingsBuffer = null;

function isRetiredSharedKey(key) {
  if (!key) return false;
  const hash = crypto.createHash("sha256").update(key.trim()).digest("hex");
  return hash === RETIRED_SHARED_KEY_SHA256;
}

function getDigestsMap() {
  if (cachedDigestsMap !== null) return cachedDigestsMap;
  try {
    const filePath = path.join(__dirname, "data", "hymn_digests.json");
    if (fs.existsSync(filePath)) {
      cachedDigestsMap = JSON.parse(fs.readFileSync(filePath, "utf-8"));
    } else {
      cachedDigestsMap = {};
    }
  } catch (e) {
    console.warn("No se pudo cargar hymn_digests.json:", e.message);
    cachedDigestsMap = {};
  }
  return cachedDigestsMap;
}

function getServerEmbeddings() {
  if (cachedEmbeddingsLoaded) {
    return cachedEmbeddingsMeta && cachedEmbeddingsBuffer
      ? { meta: cachedEmbeddingsMeta, buffer: cachedEmbeddingsBuffer }
      : null;
  }
  cachedEmbeddingsLoaded = true;
  try {
    const metaPath = path.join(__dirname, "data", "hymn_embeddings_meta.json");
    const binPath = path.join(__dirname, "data", "hymn_embeddings.bin");
    if (fs.existsSync(metaPath) && fs.existsSync(binPath)) {
      cachedEmbeddingsMeta = JSON.parse(fs.readFileSync(metaPath, "utf-8"));
      cachedEmbeddingsBuffer = fs.readFileSync(binPath);
      return { meta: cachedEmbeddingsMeta, buffer: cachedEmbeddingsBuffer };
    }
  } catch (e) {
    console.warn("No se pudieron cargar embeddings en servidor:", e.message);
  }
  return null;
}

function resolveKeysToTry(userApiKey) {
  const keys = [];
  if (SERVER_GEMINI_KEY) {
    keys.push(SERVER_GEMINI_KEY);
  }
  const cleanUserKey = (userApiKey || "").trim();
  if (
    cleanUserKey.length > 0 &&
    cleanUserKey !== SERVER_GEMINI_KEY &&
    !isRetiredSharedKey(cleanUserKey)
  ) {
    keys.push(cleanUserKey);
  }
  return keys;
}

/**
 * Obtiene el vector de consulta mediante gemini-embedding-001 (cuota separada ~1,000 RPD gratis)
 */
async function embedQueryText(query, keysToTry, dims = 256) {
  for (const currentKey of keysToTry) {
    try {
      const url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent";
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": currentKey,
        },
        body: JSON.stringify({
          model: "models/gemini-embedding-001",
          content: { parts: [{ text: query }] },
          taskType: "RETRIEVAL_QUERY",
          outputDimensionality: dims,
        }),
      });
      if (res.ok) {
        const jsonRes = await res.json();
        const values = jsonRes && jsonRes.embedding && jsonRes.embedding.values;
        if (Array.isArray(values) && values.length === dims) {
          return values;
        }
      }
    } catch (e) {
      console.warn("embedQueryText falló:", e.message);
    }
  }
  return null;
}

function rankVectorCandidatesByCollection(queryVector, allowedCollections, topPerCollection = 18) {
  const emb = getServerEmbeddings();
  const digests = getDigestsMap();
  if (!emb || !queryVector) return {};

  const dims = emb.meta.dims || 256;
  const items = emb.meta.items || [];
  const buf = emb.buffer;
  if (queryVector.length !== dims || buf.length < items.length * dims) return {};

  let qNorm = 0;
  for (let d = 0; d < dims; d++) qNorm += queryVector[d] * queryVector[d];
  qNorm = Math.sqrt(qNorm) || 1;

  const buckets = {};
  for (const col of allowedCollections) buckets[col] = [];

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const col = item.c;
    if (!buckets[col]) continue;
    const offset = i * dims;
    let dot = 0;
    let vNorm = 0;
    for (let d = 0; d < dims; d++) {
      const signed = buf.readInt8(offset + d) / 127.0;
      dot += signed * queryVector[d];
      vNorm += signed * signed;
    }
    const denom = Math.sqrt(vNorm) * qNorm;
    const sim = denom > 0 ? dot / denom : 0;
    buckets[col].push({ col, id: item.i, sim });
  }

  const out = {};
  for (const col of allowedCollections) {
    const list = buckets[col] || [];
    list.sort((a, b) => b.sim - a.sim);
    out[col] = list.slice(0, topPerCollection).map((entry) => {
      const d = digests[`${entry.col}-${entry.id}`];
      if (!d) return null;
      return {
        id: d.id,
        collection: d.collection,
        title: d.title,
        digest: d.digest,
      };
    }).filter(Boolean);
  }
  return out;
}

/**
 * Función genérica para invocar Gemini con fallback en cascada de modelos y claves
 */
async function callGeminiApi({
  prompt,
  inlineData = null,
  jsonOutput = true,
  temperature = 0.2,
  maxOutputTokens = 8192,
  models = GEMINI_MODELS,
  apiKey = null,
}) {
  const keysToTry = resolveKeysToTry(apiKey);
  if (keysToTry.length === 0) {
    const err = new Error("NO_API_KEY_CONFIGURED");
    err.code = "failed-precondition";
    throw err;
  }

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
      maxOutputTokens,
    },
  });

  let lastError = null;
  let lastStatus = 0;
  for (const currentKey of keysToTry) {
    for (const model of models) {
      try {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
        const res = await fetch(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": currentKey,
          },
          body: requestBody,
          signal: AbortSignal.timeout(22000),
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
          if (lastStatus !== 429) {
            lastStatus = res.status;
          }
          const errText = await res.text();
          console.warn(`Model ${model} with key ${currentKey.substring(0, 8)}... returned ${res.status}: ${errText}`);
          lastError = `Status ${res.status}: ${errText}`;
          if (res.status === 400 || res.status === 403) {
            break; // Clave inválida o sin permisos: pasar a siguiente clave si existe
          }
        }
      } catch (e) {
        console.warn(`Model ${model} exception: ${e.message}`);
        lastError = e.message;
      }
    }
  }

  const failure = new Error(`Gemini API failure: ${lastError}`);
  failure.httpStatus = lastStatus;
  throw failure;
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

function formatCollectionSectionTitle(col) {
  switch (col) {
    case "iump":
      return "Himnario Oficial IUMP";
    case "especiales":
      return "Alabanzas Especiales";
    case "coros":
      return "Coros de Avivamiento";
    default:
      return col.toUpperCase();
  }
}

function buildDefaultNoMoreReason(col, count) {
  const label = formatCollectionSectionTitle(col);
  if (count <= 0) {
    if (col === "iump") {
      return "Revisamos todo el Himnario IUMP y no encontramos himnos que aborden directamente este pasaje o concepto. Revisa las otras colecciones o intenta describir el tema con otras palabras.";
    }
    if (col === "especiales") {
      return "Ninguna alabanza especial de toda la base de datos desarrolla específicamente esta enseñanza o metáfora. Puedes explorar las otras secciones o ampliar la búsqueda con una palabra clave.";
    }
    if (col === "coros") {
      return "No hallamos coros en Coros de Avivamiento que se vinculen con claridad a esta búsqueda. Te sugerimos probar con un concepto espiritual más amplio (por ejemplo: «fe», «consuelo» o «victoria»).";
    }
    return `No se encontraron cantos relacionados en ${label}.`;
  }
  if (count < MAX_RESULTS_PER_COLLECTION) {
    if (col === "iump") {
      return `Estos son los ${count} himnos más acertados encontrados en todo el Himnario IUMP. No se encontraron más himnos con relación real para esta búsqueda.`;
    }
    if (col === "especiales") {
      return `Mostrando las ${count} alabanzas especiales más pertinentes de toda la base de datos. No se encontraron más especiales con vínculo espiritual directo para esta búsqueda.`;
    }
    if (col === "coros") {
      return `Estos son los ${count} coros más relacionados encontrados en Coros de Avivamiento. No hay más coros en esta colección que desarrollen directamente este tema.`;
    }
    return `No se encontraron más cantos relacionados en ${label}.`;
  }
  return `Mostrando los ${MAX_RESULTS_PER_COLLECTION} cantos más acertados de ${label}.`;
}

/**
 * Asistente Bíblico con IA y Búsqueda Semántica (v2 por colección 10+10+10 + compatibilidad v1)
 * Incluye caché en Firestore para responder en milisegundos sin consumir cuota.
 */
exports.searchHymnsWithAi = onCall({
  timeoutSeconds: 60,
  memory: "512MiB",
}, async (request) => {
  const data = request.data || {};
  const query = (data.query || "").trim();
  const searchMode = data.searchMode || "biblical"; // 'biblical' o 'conceptual'
  const schemaVersion = Number(data.schemaVersion || 1);
  const userApiKey = (data.apiKey || "").trim();

  if (!query) {
    throw new HttpsError("invalid-argument", "query is required");
  }

  const normQuery = query
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9 ]/g, "")
    .trim();

  // ---------------- MODO V2: Hasta 10 cantos más acertados por colección ----------------
  if (schemaVersion >= 2) {
    const requestedColsRaw = Array.isArray(data.allowedCollections)
      ? data.allowedCollections.map((c) => String(c).toLowerCase().trim())
      : COLLECTION_ORDER;
    const allowedCollections = COLLECTION_ORDER.filter((c) =>
      requestedColsRaw.includes(c)
    );
    if (allowedCollections.length === 0) {
      throw new HttpsError("invalid-argument", "allowedCollections must not be empty");
    }

    const catalogSignature = String(data.catalogSignature || "base").trim();
    const cacheKey = crypto
      .createHash("sha256")
      .update(`${normQuery}_${searchMode}_${allowedCollections.join(",")}_${catalogSignature}_v2`)
      .digest("hex")
      .substring(0, 32);

    try {
      const db = getFirestore();
      const cachedSnap = await db.collection("ai_bible_cache_v2").doc(cacheKey).get();
      if (cachedSnap.exists) {
        const cached = cachedSnap.data();
        if (cached && cached.response) {
          console.log(`[Cache HIT v2] "${query}" (${allowedCollections.join(",")})`);
          return {
            ...cached.response,
            fromCache: true,
            schemaVersion: 2,
            success: true,
          };
        }
      }
    } catch (cacheErr) {
      console.warn("Error leyendo ai_bible_cache_v2:", cacheErr.message);
    }

    const keysToTry = resolveKeysToTry(userApiKey);
    if (keysToTry.length === 0) {
      throw new HttpsError("failed-precondition", "NO_API_KEY_CONFIGURED");
    }

    // 1. Mezclar candidatos vectoriales del servidor (si hay embeddings) + candidatos léxicos del cliente (incluye cantos nuevos Firestore/locales)
    const lexicalCandidates = data.lexicalCandidates || {};
    let vectorCandidates = {};
    if (getServerEmbeddings()) {
      const qVec = await embedQueryText(query, keysToTry, 256);
      if (qVec) {
        vectorCandidates = rankVectorCandidatesByCollection(
          qVec,
          allowedCollections,
          allowedCollections.length === 1 ? 26 : 18
        );
      }
    }

    const perColCap = allowedCollections.length === 1 ? 35 : 24;
    const candidateBlocks = [];
    const digestsMap = getDigestsMap();

    for (const col of allowedCollections) {
      const seen = new Set();
      const merged = [];

      const vecList = Array.isArray(vectorCandidates[col]) ? vectorCandidates[col] : [];
      const lexList = Array.isArray(lexicalCandidates[col]) ? lexicalCandidates[col] : [];

      for (const item of [...vecList, ...lexList]) {
        const idNum = Number(item && item.id);
        if (!idNum || seen.has(idNum)) continue;
        seen.add(idNum);
        const fallbackDigest = digestsMap[`${col}-${idNum}`]?.digest || "";
        const digest = String((item && item.digest) || fallbackDigest || "")
          .replace(/\s+/g, " ")
          .substring(0, 420);
        const title = String((item && item.title) || digestsMap[`${col}-${idNum}`]?.title || "").trim();
        if (!title) continue;
        merged.push(`${idNum}|${title}|${digest}`);
        if (merged.length >= perColCap) break;
      }

      candidateBlocks.push(
        `=== COLECCIÓN "${col}" (${formatCollectionSectionTitle(col)}) [ID|TÍTULO|LETRA_COMPACTA] ===\n${
          merged.length > 0 ? merged.join("\n") : "(Sin candidatos disponibles)"
        }`
      );
    }

    const modeGuidanceV2 = searchMode === "biblical"
      ? `MODO: ASISTENTE BÍBLICO Y HERMENÉUTICA DE PREDICACIÓN / SERMÓN
Misión: Actuar como teólogo bíblico, pastor e himnólogo evangélico pentecostal con profundo conocimiento de las Escrituras (RV1960) y del repertorio congregacional.

REGLAS ESTRICTAS DE ANÁLISIS Y PRECISIÓN:
1. LOCALIZACIÓN BÍBLICA: Identifica con precisión el pasaje o verdad doctrinal en "biblicalPassage" (ej: "Isaías 43:1-3", "Salmo 23:1-6", "1 Reyes 19:4-8"). Si es un tema general, anota 1 o 2 citas base representativas.
2. EXÉGESIS BREVE: En "biblicalContext" redacta 2 oraciones claras sobre el trasfondo espiritual y necesidad del alma. Define "spiritualTone" en 2-4 palabras.
3. EVALUACIÓN SEPARADA POR COLECCIÓN (HASTA 10 POR CADA UNA):
   - Debes evaluar POR SEPARADO cada colección solicitada (${allowedCollections.join(", ")}) leyendo su TÍTULO y su LETRA_COMPACTA real.
   - NO busques solo coincidencia literal de palabras: evalúa el mensaje teológico de estrofas y coros.
   - Para CADA colección solicitada, elige hasta los **10 cantos más acertados** (ordenados del #1 más certero al #10).
   - REGLA ANTI-RELLENO (OBLIGATORIA): NUNCA agregues cantos forzados, genéricos o de relleno solo para completar 10. Si en una colección solo hay 0, 3, 6 u 8 cantos con vínculo real con la predicación, devuelve ÚNICAMENTE esos y explica con amabilidad pastoral en "noMoreReason" (1-2 frases) que no se encontraron más coincidencias reales en esa colección.`
      : `MODO: BÚSQUEDA CONCEPTUAL, TEMÁTICA Y METAFÓRICA
Misión: Encontrar los cantos más acertados a partir de un tema, metáfora, historia bíblica o recuerdo de letra.

REGLAS ESTRICTAS DE PRECISIÓN:
1. Analiza la metáfora, enseñanza o recuerdo poético en "biblicalContext" (1-2 oraciones) y cita un pasaje afín opcional en "biblicalPassage" si aplica.
2. Evalúa POR SEPARADO cada colección solicitada (${allowedCollections.join(", ")}) leyendo su TÍTULO y su LETRA_COMPACTA real.
3. Para CADA colección solicitada, selecciona hasta los **10 cantos más acertados** (ordenados del #1 más certero al #10).
4. REGLA ANTI-RELLENO (OBLIGATORIA): Solo incluye cantos cuya letra o tema aborden genuinamente el concepto consultado. Si hay menos de 10 (o 0), devuelve solo los genuinos y explica brevemente en "noMoreReason" (1-2 frases amables) que no se encontraron más coincidencias reales en esa colección.`;

    const collectionsJsonShape = allowedCollections
      .map(
        (col) => `    "${col}": {
      "matches": [
        {
          "id": 123,
          "collection": "${col}",
          "title": "TÍTULO EXACTO DEL CANTO",
          "relevanceLevel": "alta",
          "relevanceReason": "1-2 frases concretas citando la idea, coro o estrofa que conecta con la búsqueda",
          "worshipMoment": "Sellar la Predicación | Llamado al Altar | Oración de Fe | Alabanza Congregacional"
        }
      ],
      "noMoreReason": "Explicación pastoral breve si se hallaron menos de 10 o 0 cantos en esta colección"
    }`
      )
      .join(",\n");

    const promptTextV2 = `${modeGuidanceV2}

CONSULTA DEL MINISTRO O CONGREGANTE:
"${query}"

CANDIDATOS PRESELECCIONADOS DE TODA LA BASE DE DATOS:
${candidateBlocks.join("\n\n")}

RESPONDE EXCLUSIVAMENTE CON UN OBJETO JSON VÁLIDO (sin \`\`\`json ni texto fuera del JSON):
{
  "summary": "Resumen en 1 frase del enfoque espiritual o tema hallado",
  "biblicalPassage": "Cita bíblica principal (ej: Isaías 43:1-3)",
  "biblicalContext": "Análisis exegético/espiritual breve y claro (2 oraciones)",
  "spiritualTone": "Consagración | Fe en la Prueba | Consuelo y Esperanza | Guerra Espiritual | Gracia y Perdón | Adoración",
  "keywords": ["tema1", "tema2", "tema3", "tema4"],
  "collections": {
${collectionsJsonShape}
  }
}`;

    try {
      const aiResult = await callGeminiApi({
        prompt: promptTextV2,
        jsonOutput: true,
        temperature: 0.15,
        maxOutputTokens: 8192,
        models: SEARCH_GEMINI_MODELS,
        apiKey: userApiKey,
      });

      const raw = aiResult.data || {};
      const rawCollections = (raw.collections && typeof raw.collections === "object")
        ? raw.collections
        : {};
      const normalizedCollections = {};
      const flatCompatResults = [];

      for (const col of allowedCollections) {
        const entry = rawCollections[col] || {};
        const rawList = Array.isArray(entry.matches) ? entry.matches : [];
        const cleanList = [];
        const seenIds = new Set();

        for (const m of rawList) {
          if (!m) continue;
          const idNum = Number(m.id);
          if (!idNum || seenIds.has(idNum)) continue;
          seenIds.add(idNum);
          const item = {
            id: idNum,
            collection: col,
            title: String(m.title || "").trim(),
            relevanceLevel: String(m.relevanceLevel || "alta").toLowerCase(),
            relevanceReason: String(m.relevanceReason || "Coincidencia conceptual con la búsqueda.").trim(),
            worshipMoment: String(m.worshipMoment || "Sellar la Predicación").trim(),
          };
          cleanList.push(item);
          flatCompatResults.push(item);
          if (cleanList.length >= MAX_RESULTS_PER_COLLECTION) break;
        }

        const aiReason = String(entry.noMoreReason || "").trim();
        const noMoreReason = cleanList.length >= MAX_RESULTS_PER_COLLECTION
          ? buildDefaultNoMoreReason(col, cleanList.length)
          : (aiReason.length >= 12 ? aiReason : buildDefaultNoMoreReason(col, cleanList.length));

        normalizedCollections[col] = {
          matches: cleanList,
          noMoreReason,
        };
      }

      const responsePayload = {
        schemaVersion: 2,
        summary: String(raw.summary || "Resultados identificados por el Asistente Bíblico").trim(),
        biblicalPassage: raw.biblicalPassage ? String(raw.biblicalPassage).trim() : null,
        biblicalContext: raw.biblicalContext ? String(raw.biblicalContext).trim() : null,
        spiritualTone: raw.spiritualTone ? String(raw.spiritualTone).trim() : null,
        keywords: Array.isArray(raw.keywords) ? raw.keywords.map((k) => String(k)) : [],
        collections: normalizedCollections,
        results: flatCompatResults,
      };

      try {
        const db = getFirestore();
        db.collection("ai_bible_cache_v2").doc(cacheKey).set({
          originalQuery: query,
          normalizedQuery: normQuery,
          searchMode,
          allowedCollections,
          catalogSignature,
          response: responsePayload,
          modelUsed: aiResult.modelUsed,
          updatedAt: FieldValue.serverTimestamp(),
        }).catch((e) => console.warn("Error guardando en ai_bible_cache_v2:", e.message));
      } catch (e) {
        console.warn("Error accediendo a Firestore para caché v2:", e.message);
      }

      return {
        ...responsePayload,
        fromCache: false,
        modelUsed: aiResult.modelUsed,
        success: true,
      };
    } catch (error) {
      console.error("Error en searchHymnsWithAi v2:", error);
      if (error.code === "failed-precondition") {
        throw new HttpsError("failed-precondition", error.message);
      }
      if (error.httpStatus === 429) {
        throw new HttpsError("resource-exhausted", error.message);
      }
      throw new HttpsError("internal", error.message);
    }
  }

  // ---------------- MODO V1 (Compatibilidad con versiones publicadas 1.0.32) ----------------
  const catalogIndex = (data.catalogIndex || "").trim();
  const cacheKeyV1 = crypto.createHash("sha256").update(`${normQuery}_${searchMode}`).digest("hex").substring(0, 32);

  try {
    const db = getFirestore();
    const cachedSnap = await db.collection("ai_bible_cache").doc(cacheKeyV1).get();
    if (cachedSnap.exists) {
      const cached = cachedSnap.data();
      if (cached && cached.response) {
        console.log(`[Cache HIT v1] Consulta respondida desde Firestore: "${query}"`);
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
      models: SEARCH_GEMINI_MODELS,
      apiKey: userApiKey,
    });

    const responsePayload = aiResult.data;

    try {
      const db = getFirestore();
      db.collection("ai_bible_cache").doc(cacheKeyV1).set({
        originalQuery: query,
        normalizedQuery: normQuery,
        searchMode,
        response: responsePayload,
        modelUsed: aiResult.modelUsed,
        updatedAt: FieldValue.serverTimestamp(),
      }).catch((e) => console.warn("Error guardando en caché:", e.message));
    } catch (e) {
      console.warn("Error accediendo a Firestore para guardar:", e.message);
    }

    return {
      ...responsePayload,
      fromCache: false,
      modelUsed: aiResult.modelUsed,
      success: true,
    };
  } catch (error) {
    console.error("Error en searchHymnsWithAi:", error);
    if (error.httpStatus === 429) {
      throw new HttpsError("resource-exhausted", error.message);
    }
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
