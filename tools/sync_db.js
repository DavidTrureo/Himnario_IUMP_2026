const https = require('https');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'himnario-vito-2026';
const COLLECTIONS = ['iump', 'especiales', 'coros'];
const ASSETS_DIR = path.join(__dirname, '..', 'assets', 'json');

// Mapa de colecciones a sus archivos correspondientes
const FILE_MAP = {
  'iump': 'hymns.json',
  'especiales': 'special_hymns.json',
  'coros': 'coros.json'
};

async function fetchCollection(collectionId) {
  let allDocuments = [];
  let pageToken = '';
  
  while (true) {
    let url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collectionId}?pageSize=300`;
    if (pageToken) {
      url += `&pageToken=${encodeURIComponent(pageToken)}`;
    }
    
    console.log(`Descargando datos de /${collectionId}...`);
    
    const response = await new Promise((resolve, reject) => {
      https.get(url, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch(e) {
            reject(e);
          }
        });
      }).on('error', reject);
    });

    if (response.error) {
      throw new Error(response.error.message);
    }

    if (response.documents) {
      const parsedDocs = response.documents.map(doc => {
        const fields = doc.fields || {};
        const result = {};
        
        // Convertir formato de Firestore a JSON normal
        for (const [key, valueObj] of Object.entries(fields)) {
          if (valueObj.stringValue !== undefined) {
            result[key] = valueObj.stringValue;
          } else if (valueObj.integerValue !== undefined) {
            result[key] = parseInt(valueObj.integerValue, 10);
          } else if (valueObj.booleanValue !== undefined) {
            result[key] = valueObj.booleanValue;
          } else if (valueObj.arrayValue !== undefined) {
            const arr = valueObj.arrayValue.values || [];
            result[key] = arr.map(v => v.stringValue || '');
          }
        }
        
        // Asegurar que el ID sea numérico
        if (result.id && typeof result.id === 'string') {
          result.id = parseInt(result.id, 10);
        }
        
        return result;
      });
      allDocuments.push(...parsedDocs);
    }

    if (response.nextPageToken) {
      pageToken = response.nextPageToken;
    } else {
      break; // No hay más páginas
    }
  }
  
  // Ordenar la lista para mantener un orden consistente
  if (collectionId === 'iump') {
    allDocuments.sort((a, b) => (a.id || 0) - (b.id || 0));
  } else {
    allDocuments.sort((a, b) => (a.title || '').localeCompare(b.title || ''));
  }
  
  return allDocuments;
}

async function main() {
  console.log("==================================================");
  console.log("   INICIANDO SINCRONIZACIÓN DE BASE DE DATOS      ");
  console.log("==================================================\n");

  if (!fs.existsSync(ASSETS_DIR)) {
    fs.mkdirSync(ASSETS_DIR, { recursive: true });
  }

  for (const collection of COLLECTIONS) {
    try {
      const docs = await fetchCollection(collection);
      const filePath = path.join(ASSETS_DIR, FILE_MAP[collection]);
      
      fs.writeFileSync(filePath, JSON.stringify(docs, null, 2), 'utf-8');
      console.log(`✅ ¡Éxito! ${docs.length} registros guardados en ${filePath}\n`);
    } catch (error) {
      console.error(`❌ Error sincronizando '${collection}':`, error);
    }
  }
  
  console.log("==================================================");
  console.log("🎉 ¡COPIA DE SEGURIDAD LOCAL TERMINADA CON ÉXITO! ");
  console.log("==================================================");
}

main();
