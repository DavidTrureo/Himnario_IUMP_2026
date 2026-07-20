#!/usr/bin/env python3
import json
import urllib.request
import subprocess
import sys

def get_gcloud_token():
    try:
        return subprocess.check_output(['gcloud', 'auth', 'print-access-token']).decode('utf-8').strip()
    except Exception as e:
        print("❌ Error al obtener token de gcloud. Asegúrate de estar logueado con gcloud auth login.")
        print(e)
        sys.exit(1)

def sync_collection(project_id, token, filename, collection_name):
    # Read local JSON
    path = f'assets/json/{filename}'
    try:
        with open(path, 'r', encoding='utf-8') as f:
            hymns = json.load(f)
    except Exception as e:
        print(f"❌ Error al leer {path}")
        print(e)
        return

    print(f"\n📖 Se leyeron {len(hymns)} ítems locales de '{filename}'.")

    # Build Batch commit writes (Firestore allows up to 500 writes per commit)
    # We will chunk in batches of 300 to be extremely safe.
    chunk_size = 300
    for idx in range(0, len(hymns), chunk_size):
        chunk = hymns[idx:idx + chunk_size]
        writes = []
        for h in chunk:
            doc_name = f"projects/{project_id}/databases/(default)/documents/{collection_name}/{h['id']}"
            
            # Formulate fields
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
                print(f"   ✅ [Lote {idx//chunk_size + 1}] Subidos/actualizados {len(write_results)} documentos en la colección '{collection_name}'.")
        except Exception as e:
            print(f"   ❌ Error al subir lote para '{collection_name}':")
            if hasattr(e, 'read'):
                print(e.read().decode('utf-8'))
            else:
                print(e)

def main():
    project_id = 'himnario-vito-2026'
    print("🔐 Obteniendo credenciales de Google Cloud...")
    token = get_gcloud_token()
    
    # Sync especiales
    sync_collection(project_id, token, 'special_hymns.json', 'especiales')
    
    # Sync coros
    sync_collection(project_id, token, 'coros.json', 'coros')

if __name__ == '__main__':
    main()
