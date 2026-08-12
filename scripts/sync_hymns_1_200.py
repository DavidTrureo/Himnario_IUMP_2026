#!/usr/bin/env python3
import json
import urllib.request
import subprocess
import sys

def get_gcloud_token():
    try:
        return subprocess.check_output(['gcloud', 'auth', 'print-access-token']).decode('utf-8').strip()
    except Exception as e:
        print("❌ Error al obtener token de gcloud.")
        print(e)
        sys.exit(1)

def main():
    project_id = 'himnario-vito-2026'
    collection_name = 'iump'
    filename = 'assets/json/hymns.json'
    
    print("🔐 Obteniendo credenciales de Google Cloud...")
    token = get_gcloud_token()
    
    with open(filename, 'r', encoding='utf-8') as f:
        hymns = json.load(f)
    
    # Filter hymns 1 to 200
    hymns_to_sync = [h for h in hymns if 1 <= h['id'] <= 200]
    print(f"📖 Se sincronizarán {len(hymns_to_sync)} himnos (1 al 200) en la colección '{collection_name}' de Firebase Firestore.")
    
    chunk_size = 100
    for idx in range(0, len(hymns_to_sync), chunk_size):
        chunk = hymns_to_sync[idx:idx + chunk_size]
        writes = []
        for h in chunk:
            doc_name = f"projects/{project_id}/databases/(default)/documents/{collection_name}/{h['id']}"
            fields = {
                "id": {"integerValue": str(h['id'])},
                "title": {"stringValue": h['title']},
                "tone": {"stringValue": h.get('tone', '')},
                "lyrics": {"stringValue": h['lyrics']},
                "collection": {"stringValue": collection_name}
            }
            if 'author' in h and h['author']:
                fields["author"] = {"stringValue": h['author']}
            if 'audioUrl' in h and h['audioUrl']:
                fields["audioUrl"] = {"stringValue": h['audioUrl']}

            write = {
                "update": {
                    "name": doc_name,
                    "fields": fields
                }
            }
            writes.append(write)

        payload = {"writes": writes}
        url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents:commit"
        
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode('utf-8'),
            headers={
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            },
            method='POST'
        )

        try:
            with urllib.request.urlopen(req) as response:
                res_data = json.loads(response.read().decode('utf-8'))
                write_results = res_data.get('writeResults', [])
                print(f"   ✅ [Lote {idx//chunk_size + 1}] {len(write_results)} documentos sincronizados en Firestore.")
        except Exception as e:
            print(f"   ❌ Error al subir lote:")
            if hasattr(e, 'read'):
                print(e.read().decode('utf-8'))
            else:
                print(e)

if __name__ == '__main__':
    main()
