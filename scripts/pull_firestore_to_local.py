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

def pull_collection(project_id, token, collection_name, filename):
    print(f"📖 Obteniendo colección '{collection_name}' desde Firestore...")
    documents = []
    next_page_token = None

    base_url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/{collection_name}?pageSize=300"

    while True:
        url = base_url
        if next_page_token:
            url += f"&pageToken={next_page_token}"
        
        req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
        
        try:
            with urllib.request.urlopen(req) as response:
                res_data = json.loads(response.read().decode('utf-8'))
                
                for doc in res_data.get('documents', []):
                    fields = doc.get('fields', {})
                    
                    hymn_id = int(fields.get('id', {}).get('integerValue', 0))
                    title = fields.get('title', {}).get('stringValue', '')
                    tone = fields.get('tone', {}).get('stringValue', '')
                    lyrics = fields.get('lyrics', {}).get('stringValue', '')
                    
                    doc_obj = {
                        "id": hymn_id,
                        "title": title,
                        "lyrics": lyrics
                    }
                    if tone:
                        doc_obj["tone"] = tone
                        
                    documents.append(doc_obj)
                
                next_page_token = res_data.get('nextPageToken')
                if not next_page_token:
                    break
        except Exception as e:
            print(f"   ❌ Error al descargar:")
            if hasattr(e, 'read'):
                print(e.read().decode('utf-8'))
            else:
                print(e)
            return

    # Sort documents by ID
    documents.sort(key=lambda x: x["id"])

    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(documents, f, indent=4, ensure_ascii=False)
    
    print(f"   ✅ Se guardaron {len(documents)} himnos en {filename}.")

def main():
    project_id = 'himnario-vito-2026'
    print("🔐 Obteniendo credenciales de Google Cloud...")
    token = get_gcloud_token()
    
    pull_collection(project_id, token, 'iump', 'assets/json/hymns.json')
    pull_collection(project_id, token, 'coros', 'assets/json/coros.json')
    pull_collection(project_id, token, 'especiales', 'assets/json/special_hymns.json')

if __name__ == '__main__':
    main()
