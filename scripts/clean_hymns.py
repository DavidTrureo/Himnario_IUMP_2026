#!/usr/bin/env python3
import json
import urllib.request
import urllib.error
import subprocess
import sys
import re

PROJECT_ID = 'himnario-vito-2026'

def get_gcloud_token():
    try:
        return subprocess.check_output(['gcloud', 'auth', 'print-access-token']).decode('utf-8').strip()
    except Exception as e:
        print("❌ Error al obtener token de gcloud.")
        print(e)
        sys.exit(1)

def fetch_collection(collection_name, token):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{collection_name}?pageSize=1000"
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode('utf-8'))
            return data.get('documents', [])
    except urllib.error.URLError as e:
        print(f"Error fetch {collection_name}: {e}")
        return []

def clean_lyrics(lyrics):
    original = lyrics

    # 1. Eliminar multiples saltos de linea innecesarios
    cleaned = re.sub(r'\n{3,}', '\n\n', lyrics)
    
    # 2. Corregir etiquetas de coro mal escritas (ignorando mayusculas/minusculas)
    cleaned = re.sub(r'(?im)^(coro[\s\-:]*)\n?', 'Coro:\n', cleaned)
    
    # 3. Identificar palabras pegadas: minuscula seguida de mayuscula sin espacio
    # (Ejemplo: "DiosSanto" -> "Dios\nSanto" - usualmente en cantos es un salto de linea omitido)
    cleaned = re.sub(r'([a-záéíóúñ])([A-ZÁÉÍÓÚÑ])', r'\1\n\2', cleaned)
    
    # 4. Eliminar espacios vacios al inicio de cada linea
    cleaned = re.sub(r'^[ \t]+', '', cleaned, flags=re.MULTILINE)
    
    return cleaned

def parse_firestore_doc(doc):
    fields = doc.get('fields', {})
    hymn_id = fields.get('id', {}).get('integerValue')
    title = fields.get('title', {}).get('stringValue', 'Sin Titulo')
    lyrics = fields.get('lyrics', {}).get('stringValue', '')
    return hymn_id, title, lyrics

def main():
    print("🔐 Obteniendo credenciales de Google Cloud...")
    token = get_gcloud_token()
    
    collections_to_clean = ['coros', 'especiales']
    
    changes = []

    for col in collections_to_clean:
        print(f"📖 Analizando colección: {col}...")
        docs = fetch_collection(col, token)
        
        for doc in docs:
            hymn_id, title, lyrics = parse_firestore_doc(doc)
            
            if not lyrics:
                continue
                
            cleaned = clean_lyrics(lyrics)
            
            if cleaned != lyrics:
                changes.append({
                    'collection': col,
                    'id': hymn_id,
                    'title': title,
                    'original': lyrics,
                    'cleaned': cleaned
                })

    output_file = 'revision_limpieza.txt'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("REVISIÓN DE LIMPIEZA DE CANTOS\n")
        f.write("==============================\n\n")
        f.write(f"Se encontraron {len(changes)} cantos que necesitan formato.\n\n")
        
        for change in changes:
            f.write(f"--- CANTO: [{change['collection'].upper()}] {change['title']} (ID: {change['id']}) ---\n")
            f.write("== ANTES ==\n")
            f.write(change['original'])
            f.write("\n\n== DESPUÉS ==\n")
            f.write(change['cleaned'])
            f.write("\n\n" + "="*50 + "\n\n")

    print(f"\n✅ Análisis completado. Se analizaron {len(changes)} cantos con errores de formato.")
    print(f"📄 Revisa el archivo '{output_file}' para ver exactamente cómo quedarán antes de aplicarlo.")

if __name__ == '__main__':
    main()
