import json
import re

def separate_joined_text(text):
    if not text:
        return text
    
    # 1. Separar minúscula/signo seguido inmediatamente de Mayúscula (ej: "gloriaA Dios" -> "gloria\nA Dios", "gloria.A Dios" -> "gloria.\nA Dios")
    # Ignorar nombres con prefijos o acordes en corchetes [DO]
    pattern1 = re.compile(r'([a-záéíóúñ,.!?:;/])([A-ZÁÉÍÓÚ][a-záéíóúñ])')
    
    # 2. Separar minúscula seguida de MAYÚSCULA SOSTENIDA (ej: "encendidoEN EL ALTAR" -> "encendido\nEN EL ALTAR")
    pattern2 = re.compile(r'([a-záéíóúñ])([A-ZÁÉÍÓÚ]{2,})')

    lines = text.split('\n')
    new_lines = []

    for line in lines:
        curr = line.strip()
        if not curr:
            new_lines.append('')
            continue

        # Aplicar corrección de líneas pegadas repetidamente hasta que no haya más uniones
        prev = None
        while prev != curr:
            prev = curr
            
            # Caso 1: minúscula o puntuación pegada a Mayúscula con minúscula (ej: gloriaA Dios)
            curr = re.sub(
                r'([a-záéíóúñ,.!?:;/])([A-ZÁÉÍÓÚ][a-záéíóúñ])',
                r'\1\n\2',
                curr
            )

            # Caso 2: minúscula pegada a frase EN MAYÚSCULAS (ej: encendidoEN EL ALTAR)
            curr = re.sub(
                r'([a-záéíóúñ])([A-ZÁÉÍÓÚ]{2,})',
                r'\1\n\2',
                curr
            )

            # Caso 3: MAYÚSCULA pegada a palabra en MAYÚSCULAS tras punto (ej: DIOS.EL FUEGO -> DIOS.\nEL FUEGO)
            curr = re.sub(
                r'([A-ZÁÉÍÓÚÁÉÍÓÚ]{2,}\.)([A-ZÁÉÍÓÚ]{2,})',
                r'\1\n\2',
                curr
            )

        new_lines.append(curr)

    return '\n'.join(new_lines)

def process_file(file_path):
    print(f"Procesando {file_path}...")
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    fixed_count = 0
    total_split_lines = 0

    for item in data:
        lyrics = item.get('lyrics', '')
        if not lyrics:
            continue

        new_lyrics = separate_joined_text(lyrics)
        if new_lyrics != lyrics:
            fixed_count += 1
            added_lines = new_lyrics.count('\n') - lyrics.count('\n')
            total_split_lines += added_lines
            item['lyrics'] = new_lyrics

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"-> {fixed_count} cantos corregidos con {total_split_lines} saltos de línea insertados.")

if __name__ == '__main__':
    process_file('assets/json/special_hymns.json')
    process_file('assets/json/coros.json')
    process_file('assets/json/hymns.json')
