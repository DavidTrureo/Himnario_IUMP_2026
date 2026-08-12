import json
import re

def fix_tone_field(raw_tone):
    if not raw_tone:
        return raw_tone

    clean = raw_tone.replace('TONO:', '').strip()
    
    # 1. Extraer métrica entre paréntesis o numérica
    time_sig = ''
    paren_match = re.search(r'\(([^)]+)\)', clean)
    if paren_match:
        time_sig = paren_match.group(1).replace('|', '/').replace(' ', '').strip()
        clean = clean.replace(paren_match.group(0), '').strip()
    else:
        ts_match = re.search(r'(\d+\s*[/|]\s*\d+)', clean)
        if ts_match:
            time_sig = ts_match.group(1).replace('|', '/').replace(' ', '').strip()
            clean = clean.replace(ts_match.group(0), '').strip()

    # 2. Extraer tiempos
    beats = ''
    times_match = re.search(r'(\d+)\s*(?:TIEMPOS|TIEMPO|T)?', clean, re.IGNORECASE)
    if times_match:
        beats = times_match.group(1)
        if re.search(r'TIEMPOS?|T\b', clean, re.IGNORECASE):
            clean = re.sub(r'(\d+)\s*(?:TIEMPOS|TIEMPO|T)?', '', clean, flags=re.IGNORECASE).strip()

    # 3. Limpiar nota
    tone_note = clean.replace('|', '').replace('/', '').replace('TIEMPOS', '').replace('TIEMPO', '').strip()
    tone_note = re.sub(r'\s+', ' ', tone_note)

    if not tone_note and not beats and not time_sig:
        return raw_tone

    parts = []
    if tone_note:
        parts.append(tone_note)

    if beats:
        if parts:
            parts.append(f"/ {beats} TIEMPOS")
        else:
            parts.append(f"{beats} TIEMPOS")

    if time_sig:
        if parts:
            if beats:
                parts[-1] += f" ({time_sig})"
            else:
                parts.append(f"/ {time_sig}")
        else:
            parts.append(time_sig)

    res = " ".join(parts)
    # Asegurar espaciado amplio alrededor de la barra /
    res = re.sub(r'\s*/\s*', '  /  ', res)
    return res

def process_file(file_path):
    print(f"Procesando {file_path}...")
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    count = 0
    for item in data:
        t = item.get('tone', '')
        if t:
            fixed = fix_tone_field(t)
            if fixed != t:
                item['tone'] = fixed
                count += 1

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"-> {count} tonos actualizados en {file_path}")

if __name__ == '__main__':
    process_file('assets/json/hymns.json')
    process_file('assets/json/special_hymns.json')
    process_file('assets/json/coros.json')
