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
    cleaned = lyrics

    # 1. Eliminar multiples saltos de linea innecesarios
    cleaned = re.sub(r'\n{3,}', '\n\n', cleaned)
    
    # 2. Corregir etiquetas de coro mal escritas
    cleaned = re.sub(r'(?im)^(coro\b[\s\-:]*)\n?', 'Coro:\n', cleaned)
    
    # 3. Identificar palabras pegadas: minuscula seguida de mayuscula sin espacio
    cleaned = re.sub(r'([a-záéíóúñ])([A-ZÁÉÍÓÚÑ])', r'\1\n\2', cleaned)

    # 4. Identificar punto seguido de mayuscula sin espacio
    cleaned = re.sub(r'\.([A-ZÁÉÍÓÚÑ])', r'.\n\1', cleaned)

    # 5. Identificar coma seguida de letra sin espacio
    cleaned = re.sub(r',([a-zA-ZÁÉÍÓÚÑáéíóúñ])', r',\n\1', cleaned)
    
    # 6. Eliminar espacios vacios al inicio de cada linea
    cleaned = re.sub(r'^[ \t]+', '', cleaned, flags=re.MULTILINE)
    
    return cleaned

def parse_firestore_doc(doc):
    name = doc.get('name', '')
    doc_id = name.split('/')[-1]
    
    fields = doc.get('fields', {})
    hymn_id = fields.get('id', {}).get('integerValue')
    title = fields.get('title', {}).get('stringValue', 'Sin Titulo')
    lyrics = fields.get('lyrics', {}).get('stringValue', '')
    return doc_id, hymn_id, title, lyrics

def update_lyrics(collection_name, doc_id, cleaned_lyrics, token):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/{collection_name}/{doc_id}?updateMask.fieldPaths=lyrics"
    
    data = {
        "fields": {
            "lyrics": { "stringValue": cleaned_lyrics }
        }
    }
    
    payload = json.dumps(data).encode('utf-8')
    req = urllib.request.Request(url, data=payload, headers={
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }, method='PATCH')
    
    try:
        with urllib.request.urlopen(req) as response:
            return True
    except urllib.error.URLError as e:
        print(f"❌ Error actualizando {doc_id}: {e}")
        return False

def main():
    print("🔐 Obteniendo credenciales de Google Cloud...")
    token = get_gcloud_token()
    
    collections_to_clean = ['iump', 'coros', 'especiales']
    
    changes = 0
    
    for col in collections_to_clean:
        print(f"📖 Analizando colección: {col}...")
        docs = fetch_collection(col, token)
        
        for doc in docs:
            doc_id, hymn_id, title, lyrics = parse_firestore_doc(doc)
            
            if not lyrics:
                continue
                
            cleaned = clean_lyrics(lyrics)
            
            if cleaned != lyrics:
                print(f"   🔄 Actualizando [{col.upper()}] {title} (ID: {hymn_id})...")
                success = update_lyrics(col, doc_id, cleaned, token)
                if success:
                    changes += 1

    print(f"✅ Proceso terminado. Se actualizaron {changes} cantos.")

if __name__ == "__main__":
    main()
