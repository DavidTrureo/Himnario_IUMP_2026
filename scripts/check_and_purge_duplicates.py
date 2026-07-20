#!/usr/bin/env python3
import json
import re
import unicodedata
import subprocess
import sys
import urllib.request

def clean_lyrics(text):
    if not text:
        return ""
    # Remove chords in brackets e.g. [C], [Am]
    text = re.sub(r'\[[^\]]*\]', '', text)
    # Normalize accents
    text = unicodedata.normalize('NFKD', text).encode('ASCII', 'ignore').decode('ASCII')
    # Keep only letters and numbers
    text = text.lower()
    text = re.sub(r'[^a-z0-9]', '', text)
    return text.strip()

def get_trigrams(text):
    clean = clean_lyrics(text)
    trigrams = set()
    for i in range(len(clean) - 2):
        trigrams.add(clean[i:i+3])
    return trigrams

def get_gcloud_token():
    try:
        return subprocess.check_output(['gcloud', 'auth', 'print-access-token']).decode('utf-8').strip()
    except Exception as e:
        print("❌ Error al obtener token de gcloud.")
        print(e)
        return None

def batch_delete_firestore(project_id, token, collection_name, doc_ids):
    if not doc_ids:
        return
    
    print(f"\n🗑️ Eliminando {len(doc_ids)} documentos duplicados de Firestore en la colección '{collection_name}'...")
    chunk_size = 300
    for idx in range(0, len(doc_ids), chunk_size):
        chunk = doc_ids[idx:idx + chunk_size]
        writes = []
        for doc_id in chunk:
            doc_path = f"projects/{project_id}/databases/(default)/documents/{collection_name}/{doc_id}"
            writes.append({"delete": doc_path})
            
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
                print(f"   ✅ [Lote {idx//chunk_size + 1}] Eliminados con éxito de '{collection_name}'.")
        except Exception as e:
            print(f"   ❌ Error al eliminar lote de '{collection_name}':")
            if hasattr(e, 'read'):
                print(e.read().decode('utf-8'))
            else:
                print(e)

def main():
    # 1. Load all databases
    with open('assets/json/hymns.json', 'r', encoding='utf-8') as f:
        hymns = json.load(f)
    with open('assets/json/coros.json', 'r', encoding='utf-8') as f:
        coros = json.load(f)
    with open('assets/json/special_hymns.json', 'r', encoding='utf-8') as f:
        special = json.load(f)

    print(f"Loaded: IUMP={len(hymns)}, Coros={len(coros)}, Especiales={len(special)}")

    # 2. Normalize and cache lyrics trigrams
    hymns_data = []
    for h in hymns:
        hymns_data.append({
            'hymn': h,
            'clean': clean_lyrics(h['lyrics']),
            'trigrams': get_trigrams(h['lyrics']),
            'source': 'hymns'
        })

    coros_data = []
    for c in coros:
        coros_data.append({
            'hymn': c,
            'clean': clean_lyrics(c['lyrics']),
            'trigrams': get_trigrams(c['lyrics']),
            'source': 'coros'
        })

    special_data = []
    for s in special:
        special_data.append({
            'hymn': s,
            'clean': clean_lyrics(s['lyrics']),
            'trigrams': get_trigrams(s['lyrics']),
            'source': 'special'
        })

    # 3. Detect duplicates
    # We will identify duplicates in coros and special_hymns.
    # Duplicates can be:
    # - A coro/special that has the exact same lyrics (or >90% trigram similarity) as an IUMP hymn.
    # - A coro/special that has the exact same lyrics (or >90% trigram similarity) as another coro/special.
    
    coros_to_remove = []
    special_to_remove = []
    
    # Track which clean lyrics we've already committed to keeping
    registered_lyrics = {} # clean_lyrics -> song_key (source-id)
    
    # First, register all IUMP hymns as master records
    for hd in hymns_data:
        if hd['clean']:
            registered_lyrics[hd['clean']] = f"hymns-{hd['hymn']['id']}"

    # Verify Coros
    print("\n🔍 Analizando Coros...")
    purged_coros = []
    for cd in coros_data:
        h = cd['hymn']
        clean = cd['clean']
        trigrams = cd['trigrams']
        
        if not clean or len(clean) < 15:
            continue
            
        is_dup = False
        reason = ""
        
        # Check exact lyrics match
        if clean in registered_lyrics:
            is_dup = True
            reason = f"Letra idéntica a {registered_lyrics[clean]}"
        else:
            # Check high trigram similarity (>= 88%) against registered records
            for reg_clean, reg_key in registered_lyrics.items():
                reg_trigrams = get_trigrams(reg_clean)
                if not trigrams or not reg_trigrams:
                    continue
                intersection = len(trigrams.intersection(reg_trigrams))
                union = len(trigrams.union(reg_trigrams))
                similarity = (2.0 * intersection) / (len(trigrams) + len(reg_trigrams))
                if similarity >= 0.88:
                    is_dup = True
                    reason = f"Similitud {similarity:.1%} con {reg_key}"
                    break
        
        if is_dup:
            print(f"   ⚠️ CORO DUPLICADO: [{h['id']}] '{h['title']}' -> {reason}")
            coros_to_remove.append(h['id'])
            purged_coros.append(h)
        else:
            registered_lyrics[clean] = f"coros-{h['id']}"

    # Verify Especiales
    print("\n🔍 Analizando Alabanzas Especiales...")
    purged_specials = []
    for sd in special_data:
        h = sd['hymn']
        clean = sd['clean']
        trigrams = sd['trigrams']
        
        if not clean or len(clean) < 15:
            continue
            
        is_dup = False
        reason = ""
        
        # Check exact lyrics match
        if clean in registered_lyrics:
            is_dup = True
            reason = f"Letra idéntica a {registered_lyrics[clean]}"
        else:
            # Check high trigram similarity (>= 88%) against registered records
            for reg_clean, reg_key in registered_lyrics.items():
                reg_trigrams = get_trigrams(reg_clean)
                if not trigrams or not reg_trigrams:
                    continue
                intersection = len(trigrams.intersection(reg_trigrams))
                union = len(trigrams.union(reg_trigrams))
                similarity = (2.0 * intersection) / (len(trigrams) + len(reg_trigrams))
                if similarity >= 0.88:
                    is_dup = True
                    reason = f"Similitud {similarity:.1%} con {reg_key}"
                    break
                    
        if is_dup:
            print(f"   ⚠️ ESPECIAL DUPLICADA: [{h['id']}] '{h['title']}' -> {reason}")
            special_to_remove.append(h['id'])
            purged_specials.append(h)
        else:
            registered_lyrics[clean] = f"especiales-{h['id']}"

    # 4. Perform actual removal from local JSON if duplicates found
    if coros_to_remove or special_to_remove:
        print(f"\n💾 Guardando archivos locales limpios de duplicados...")
        
        new_coros = [c for c in coros if c['id'] not in coros_to_remove]
        new_special = [s for s in special if s['id'] not in special_to_remove]
        
        with open('assets/json/coros.json', 'w', encoding='utf-8') as f:
            json.dump(new_coros, f, ensure_ascii=False, indent=2)
            
        with open('assets/json/special_hymns.json', 'w', encoding='utf-8') as f:
            json.dump(new_special, f, ensure_ascii=False, indent=2)
            
        print(f"   ✅ coros.json actualizado: {len(coros)} -> {len(new_coros)} (Eliminados {len(coros_to_remove)})")
        print(f"   ✅ special_hymns.json actualizado: {len(special)} -> {len(new_special)} (Eliminados {len(special_to_remove)})")
        
        # 5. Sync deletions to Firestore
        token = get_gcloud_token()
        if token:
            project_id = 'himnario-vito-2026'
            batch_delete_firestore(project_id, token, 'coros', coros_to_remove)
            batch_delete_firestore(project_id, token, 'especiales', special_to_remove)
        else:
            print("❌ No se pudo autenticar con gcloud. Por favor elimina los duplicados en Firestore de forma manual o inicia sesión en gcloud.")
    else:
        print("\n✨ ¡Felicidades! No se encontraron letras duplicadas entre las nuevas alabanzas y las existentes.")

if __name__ == '__main__':
    main()
