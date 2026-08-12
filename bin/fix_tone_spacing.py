import json
import re

def fix_tone_string(tone):
    if not tone:
        return tone
    # Reemplazar barras | o / sin espacio por ' | ' con espacio limpio
    # Ej: "Em| 3 TIEMPOS" -> "Em | 3 TIEMPOS", "Em|3 TIEMPOS" -> "Em | 3 TIEMPOS"
    clean = tone.strip()
    clean = re.sub(r'\s*\|\s*', ' | ', clean)
    clean = re.sub(r'\s+/\s+', ' | ', clean)
    clean = re.sub(r'\s+', ' ', clean)
    return clean

def process_file(file_path):
    print(f"Procesando tonos en {file_path}...")
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    fixed_count = 0
    for item in data:
        t = item.get('tone', '')
        if t:
            new_t = fix_tone_string(t)
            if new_t != t:
                item['tone'] = new_t
                fixed_count += 1

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"-> {fixed_count} tonos corregidos con espaciado amplio en {file_path}")

if __name__ == '__main__':
    process_file('assets/json/hymns.json')
    process_file('assets/json/special_hymns.json')
    process_file('assets/json/coros.json')
