#!/usr/bin/env python3
import json
import re
import unicodedata

note_map = {
    'DO': 'C', 'RE': 'D', 'MI': 'E', 'FA': 'F', 'SOL': 'G', 'LA': 'A', 'SI': 'B',
    'DOM': 'Cm', 'REM': 'Dm', 'MIM': 'Em', 'FAM': 'Fm', 'SOLM': 'Gm', 'LAM': 'Am', 'SIM': 'Bm',
    'DO#': 'C#', 'RE#': 'D#', 'FA#': 'F#', 'SOL#': 'G#', 'LA#': 'A#',
    'DO#M': 'C#m', 'RE#M': 'D#m', 'FA#M': 'F#m', 'SOL#M': 'G#m', 'LA#M': 'A#m',
    'DO7': 'C7', 'RE7': 'D7', 'MI7': 'E7', 'FA7': 'F7', 'SOL7': 'G7', 'LA7': 'A7', 'SI7': 'B7'
}

def clean_string(s):
    if not s:
        return ""
    # Normalize unicode (accents)
    s = unicodedata.normalize('NFKD', s).encode('ASCII', 'ignore').decode('ASCII')
    # Uppercase and keep only alphanumeric characters and spaces
    s = s.upper().strip()
    s = re.sub(r'[^A-Z0-9\s]', '', s)
    # Collapse multiple spaces
    s = re.sub(r'\s+', ' ', s)
    return s.strip()

def clean_and_parse_lyrics(lyrics):
    # Regex to find: Tiempo X / Nota: TONE
    pattern = re.compile(r'^.*?Tiempo\s*\d+\s*/\s*Nota:\s*(DO|RE|MI|FA|SOL|LA|SI)(m|#|7|#m)?([\s\S]*)$', re.IGNORECASE)
    match = pattern.match(lyrics)
    if match:
        tone_base = match.group(1).upper()
        tone_mod = match.group(2) if match.group(2) else ''
        rest = match.group(3).strip()
        
        tone_sp = tone_base + tone_mod
        tone_en = note_map.get(tone_sp.upper(), tone_sp)
        
        return tone_en, rest
    return '', lyrics

def process_scraped():
    # 1. Load scraped hymns
    try:
        with open('scripts/new_hymns_candidates.json', 'r', encoding='utf-8') as f:
            scraped = json.load(f)
    except Exception as e:
        print("❌ Error al cargar scripts/new_hymns_candidates.json")
        print(e)
        return

    print(f"📖 Se leyeron {len(scraped)} cantos de la web.")

    # 2. Load existing databases
    with open('assets/json/hymns.json', 'r', encoding='utf-8') as f:
        hymns_db = json.load(f)
    with open('assets/json/coros.json', 'r', encoding='utf-8') as f:
        coros_db = json.load(f)
    with open('assets/json/special_hymns.json', 'r', encoding='utf-8') as f:
        special_db = json.load(f)

    # 3. Build lookup sets of cleaned titles
    existing_hymns_titles = {clean_string(h['title']) for h in hymns_db}
    existing_coros_titles = {clean_string(c['title']) for c in coros_db}
    existing_special_titles = {clean_string(s['title']) for s in special_db}

    # Combined lookup for IUMP section (main hymns)
    print(f"IUMP Hymns in DB: {len(hymns_db)}")
    print(f"Coros in DB: {len(coros_db)}")
    print(f"Especiales in DB: {len(special_db)}")

    added_coros = []
    added_specials = []
    
    skipped_iump = []
    skipped_duplicate = []
    skipped_empty = []

    last_coro_id = max(c['id'] for c in coros_db) if coros_db else 0
    last_special_id = max(s['id'] for s in special_db) if special_db else 0

    next_coro_id = last_coro_id + 1
    next_special_id = last_special_id + 1

    for idx, item in enumerate(scraped):
        title = item['title'].strip()
        raw_lyrics = item['lyrics'].strip()
        collection = item.get('collection', 'especiales')

        if not title or not raw_lyrics or raw_lyrics.startswith("ERROR:") or len(raw_lyrics) < 15:
            skipped_empty.append(title if title else f"Index {idx}")
            continue

        cleaned_title = clean_string(title)

        # A: Check if title is in IUMP hymnal
        if cleaned_title in existing_hymns_titles:
            skipped_iump.append(title)
            continue

        # Parse lyrics and tone
        tone, lyrics = clean_and_parse_lyrics(raw_lyrics)

        # B: Check if title is already in its respective database
        if collection == 'coros':
            # Check in coros
            if cleaned_title in existing_coros_titles:
                skipped_duplicate.append(f"Coro: {title}")
                continue
            
            # Add to coros
            new_coro = {
                "id": next_coro_id,
                "title": title.upper(),
                "tone": tone,
                "lyrics": lyrics,
                "audioUrl": ""
            }
            coros_db.append(new_coro)
            added_coros.append(f"[{next_coro_id}] {title.upper()} ({tone})")
            existing_coros_titles.add(cleaned_title)
            next_coro_id += 1
        else:
            # Especiales
            if cleaned_title in existing_special_titles:
                skipped_duplicate.append(f"Especial: {title}")
                continue

            # Add to especiales
            new_special = {
                "id": next_special_id,
                "title": title.upper(),
                "tone": tone,
                "lyrics": lyrics,
                "audioUrl": ""
            }
            special_db.append(new_special)
            added_specials.append(f"[{next_special_id}] {title.upper()} ({tone})")
            existing_special_titles.add(cleaned_title)
            next_special_id += 1

    # Save updated databases
    with open('assets/json/coros.json', 'w', encoding='utf-8') as f:
        json.dump(coros_db, f, ensure_ascii=False, indent=2)
    
    with open('assets/json/special_hymns.json', 'w', encoding='utf-8') as f:
        json.dump(special_db, f, ensure_ascii=False, indent=2)

    print("\n--- RESUMEN DE PROCESAMIENTO ---")
    print(f"✅ Nuevos Coros agregados: {len(added_coros)}")
    for t in added_coros:
        print(f"   {t}")
    
    print(f"\n✅ Nuevas Alabanzas Especiales agregadas: {len(added_specials)}")
    # Print the first 50 added to avoid overwhelming the output
    for t in added_specials[:50]:
        print(f"   {t}")
    if len(added_specials) > 50:
        print(f"   ... y {len(added_specials) - 50} más.")

    print(f"\nResumen de descartes:")
    print(f" ⏭️ Omitidos (Ya existían en IUMP): {len(skipped_iump)}")
    print(f" ⏭️ Omitidos (Duplicados en Coros/Especiales): {len(skipped_duplicate)}")
    print(f" ⏭️ Omitidos (Vacíos o Errores): {len(skipped_empty)}")
    print(f"\nTotal coros ahora: {len(coros_db)} (Último ID: {next_coro_id - 1})")
    print(f"Total especiales ahora: {len(special_db)} (Último ID: {next_special_id - 1})")

if __name__ == '__main__':
    process_scraped()
