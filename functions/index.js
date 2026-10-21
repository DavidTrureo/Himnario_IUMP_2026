const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getStorage } = require("firebase-admin/storage");
const admin = require("firebase-admin");
const youtubedl = require("youtube-dl-exec");
const path = require("path");
const fs = require("fs");
const os = require("os");

admin.initializeApp();

exports.extractAudio = onCall({
  timeoutSeconds: 300,
  memory: "512MiB",
}, async (request) => {
  const data = request.data;
  const youtubeUrl = data.url;

  if (!youtubeUrl) {
    throw new HttpsError("invalid-argument", "The function must be called with a 'url' argument.");
  }

  // Basic youtube url validation
  if (!youtubeUrl.includes("youtube.com") && !youtubeUrl.includes("youtu.be")) {
    throw new HttpsError("invalid-argument", "Please provide a valid YouTube URL.");
  }

  try {
    console.log(`Starting extraction for URL: ${youtubeUrl}`);
    const tempFilePath = path.join(os.tmpdir(), `yt_${Date.now()}`);

    // Download and convert to mp3
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

    // Upload to Firebase Storage
    const bucket = getStorage().bucket();
    const destinationPath = `hymns_audio/yt_extracted_${Date.now()}.mp3`;

    console.log(`Uploading to Firebase Storage at ${destinationPath}`);
    await bucket.upload(finalFilePath, {
      destination: destinationPath,
      metadata: {
        contentType: 'audio/mp3',
      },
    });

    // Make the file public and get the download URL
    const file = bucket.file(destinationPath);
    
    // Create an access token for Firebase Storage URL format
    const uuid = require('crypto').randomUUID();
    await file.setMetadata({
      metadata: {
        firebaseStorageDownloadTokens: uuid,
      }
    });

    const bucketName = bucket.name;
    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(destinationPath)}?alt=media&token=${uuid}`;

    console.log(`Upload complete. URL: ${downloadUrl}`);

    // Clean up temp file
    if (fs.existsSync(finalFilePath)) {
      fs.unlinkSync(finalFilePath);
    }

    return { audioUrl: downloadUrl };
  } catch (error) {
    console.error("Error extracting audio:", error);
    
    // Attempt to cleanup if it failed midway
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

  const models = [
    "gemini-2.5-flash",
    "gemini-2.5-flash-lite",
    "gemini-2.0-flash",
    "gemini-2.5-pro",
    "gemini-2.0-flash-lite",
  ];

  const requestBody = JSON.stringify({
    contents: [
      {
        parts: [{ text: promptText }]
      }
    ],
    generationConfig: {
      response_mime_type: "application/json",
      temperature: 0.3
    }
  });

  let lastError = null;
  for (const model of models) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${userApiKey}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: requestBody,
      });

      if (res.ok) {
        const jsonRes = await res.json();
        const candidates = jsonRes.candidates;
        if (candidates && candidates.length > 0) {
          const parts = candidates[0].content && candidates[0].content.parts;
          if (parts && parts.length > 0) {
            let rawText = parts[0].text || "";
            rawText = rawText.replace(/```json/g, "").replace(/```/g, "").trim();
            const parsed = JSON.parse(rawText);
            return {
              title: parsed.title || title,
              lyrics: parsed.lyrics || lyrics,
              modelUsed: model,
              success: true
            };
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

  throw new HttpsError("internal", `No se pudo conectar con los modelos de Gemini (${lastError})`);
});

