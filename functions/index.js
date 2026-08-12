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
