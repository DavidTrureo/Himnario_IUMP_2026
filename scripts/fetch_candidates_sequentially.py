import json
import asyncio
import re
import os
import time
import random
import urllib.request
import urllib.parse
import html
import unicodedata
from playwright.async_api import async_playwright

def normalize_text(text):
    if not text:
        return ""
    text = text.lower()
    text = "".join(c for c in unicodedata.normalize('NFD', text) if unicodedata.category(c) != 'Mn')
    text = re.sub(r'[^a-z0-9]', '', text)
    return text

def extract_clean_lyrics(raw_html):
    # Encontrar el string de himno_texto.innerHTML = '...'
    match = re.search(r"himno_texto\.innerHTML\s*=\s*'([\s\S]*?)';", raw_html)
    if not match:
        return ""
    content = match.group(1)
    content = content.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n').replace('\\t', '\t')
    # Reemplazar br por saltos de línea antes de remover tags
    content = re.sub(r'<br\s*/?>', '\n', content, flags=re.IGNORECASE)
    content = re.sub(r'<[^>]+>', '', content)
    content = html.unescape(content)
    # Limpiar espacios en blanco al inicio/final de cada línea
    lines = [l.strip() for l in content.split('\n')]
    # Remover líneas vacías consecutivas
    cleaned_lines = []
    for line in lines:
        if line or (cleaned_lines and cleaned_lines[-1]):
            cleaned_lines.append(line)
    return '\n'.join(cleaned_lines).strip()

async def generate_songs_list():
    raw_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/scripts/all_songs_list.json'
    if os.path.exists(raw_path):
        print(f"📄 Se encontró la lista de canciones en {raw_path}, saltando generación.")
        with open(raw_path, 'r', encoding='utf-8') as f:
            return json.load(f)
            
    print("🚀 Lanzando Playwright para obtener la lista completa de canciones...")
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto('https://www.himnario.cl/', timeout=60000)
        await page.evaluate('zs_paginacion = 10000; Buscar();')
        print("⏳ Esperando que se carguen las filas en la tabla...")
        await page.wait_for_function("document.querySelectorAll('#table1 tr[id]').length > 5000", timeout=45000)
        
        rows = await page.evaluate('''() => {
            const list = Array.from(document.querySelectorAll('#table1 tr[id]'));
            return list.map(row => {
                const titleFont = row.querySelector('font[color]');
                const title = titleFont ? titleFont.innerText.trim() : 'Sin Título';
                const color = titleFont ? titleFont.getAttribute('color') : '';
                let icon = 'UNKNOWN';
                if (color === '#009933') {
                    icon = 'coro.png';
                } else if (color === '#2D82D7') {
                    icon = 'carpeta.png';
                } else if (color === '#EE5B83') {
                    icon = 'acordes.png';
                }
                return { idrow: row.id.replace('fila_?v=', ''), title, icon };
            });
        }''')
        await browser.close()
        
        with open(raw_path, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
        print(f"💾 Guardada lista de {len(rows)} canciones en {raw_path}")
        return rows

def main():
    # 1. Obtener la lista completa de canciones (usando Playwright de forma asíncrona si no existe)
    songs = asyncio.run(generate_songs_list())
    
    # 2. Cargar base de datos actual para evitar duplicados
    base_dir = '/Users/vitodatrah/Desktop/Proyecto_Himnario/assets/json'
    existing_titles = set()
    existing_lyrics = set()
    
    for filename in ['hymns.json', 'special_hymns.json', 'coros.json']:
        filepath = f'{base_dir}/{filename}'
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                try:
                    for item in json.load(f):
                        existing_titles.add(normalize_text(item.get('title', '')))
                        existing_lyrics.add(normalize_text(item.get('lyrics', '')))
                except Exception as e:
                    print(f"⚠️ Error cargando {filename}: {e}")
                    
    print(f"📚 Cargados {len(existing_titles)} títulos y {len(existing_lyrics)} letras de la BD actual.")
    
    # 3. Cargar progreso previo de candidatos si existe
    output_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/scripts/new_hymns_candidates.json'
    candidates = []
    seen_candidate_titles = set()
    seen_candidate_lyrics = set()
    
    if os.path.exists(output_path):
        with open(output_path, 'r', encoding='utf-8') as f:
            try:
                candidates = json.load(f)
                for c in candidates:
                    seen_candidate_titles.add(normalize_text(c['title']))
                    seen_candidate_lyrics.add(normalize_text(c['lyrics']))
                print(f"🔄 Resumiendo progreso: {len(candidates)} candidatos ya recuperados.")
            except Exception as e:
                print(f"⚠️ Error cargando progreso anterior: {e}")

    # 4. Filtrar la lista de canciones del sitio web para obtener las candidatas a descargar
    to_download = []
    for s in songs:
        title = s['title'].strip()
        icon = s['icon']
        idrow = s['idrow']
        
        # Descartar si el icono es acordes
        if icon == 'acordes.png':
            continue
            
        title_norm = normalize_text(title)
        
        # Descartar si ya existe en la BD actual
        if title_norm in existing_titles:
            continue
            
        # Descartar si ya fue descargada en candidatos
        if title_norm in seen_candidate_titles:
            continue
            
        to_download.append(s)
        
    print(f"🎯 Total candidatos a procesar: {len(to_download)}")
    
    if not to_download:
        print("🎉 ¡No hay nuevas canciones que descargar!")
        return

    # 5. Descargar secuencialmente con urllib
    url = 'https://www.himnario.cl/alabanzas_tmp_control.php'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/536.36',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Referer': 'https://www.himnario.cl/',
        'X-Requested-With': 'XMLHttpRequest'
    }
    
    success_count = 0
    skipped_count = 0
    
    for idx, song in enumerate(to_download):
        idrow = song['idrow']
        title = song['title']
        icon = song['icon']
        
        print(f"[{idx+1}/{len(to_download)}] Descargando: '{title}'...")
        
        attempts = 0
        lyrics = ""
        while attempts < 3:
            # Demora de 1600ms para evitar rate-limiting
            time.sleep(1.6)
            
            try:
                nocache = random.random()
                data = {
                    'zs_codigo': idrow,
                    'zs_estado': 'ver_alabanza',
                    'nocache': str(nocache)
                }
                encoded_data = urllib.parse.urlencode(data).encode('utf-8')
                req = urllib.request.Request(url, data=encoded_data, headers=headers)
                
                with urllib.request.urlopen(req, timeout=12) as response:
                    raw_html = response.read().decode('utf-8')
                    if "403 Forbidden" in raw_html or "Forbidden" in raw_html:
                        print(f"⚠️ 403 Forbidden detectado. Esperando 15 segundos antes de reintentar...")
                        time.sleep(15)
                        attempts += 1
                        continue
                    
                    lyrics = extract_clean_lyrics(raw_html)
                    break
            except Exception as e:
                print(f"⚠️ Error de red ({e}). Reintentando en 10 segundos...")
                time.sleep(10)
                attempts += 1
                
        if not lyrics:
            print(f"❌ Falló la descarga de '{title}' tras 3 intentos. Saltando...")
            skipped_count += 1
            continue
            
        lyrics_norm = normalize_text(lyrics)
        title_norm = normalize_text(title)
        
        # Filtrar si contiene acordes en la letra
        if '[' in lyrics or ']' in lyrics:
            print(f"⏭️ Saltado: '{title}' tiene acordes en la letra.")
            skipped_count += 1
            continue
            
        # Filtrar si ya existe la misma letra en la BD actual
        if lyrics_norm in existing_lyrics:
            print(f"⏭️ Saltado: '{title}' es duplicado de letra existente en la BD.")
            skipped_count += 1
            continue
            
        # Filtrar si ya existe en los candidatos actuales
        if lyrics_norm in seen_candidate_lyrics:
            print(f"⏭️ Saltado: '{title}' es duplicado de otro candidato recién descargado.")
            skipped_count += 1
            continue
            
        # Determinar colección basada en icono
        collection = 'especiales'
        if icon == 'coro.png':
            collection = 'coros'
            
        # Agregar a candidatos
        candidates.append({
            'title': title.upper(),
            'lyrics': lyrics,
            'collection': collection
        })
        seen_candidate_titles.add(title_norm)
        seen_candidate_lyrics.add(lyrics_norm)
        success_count += 1
        
        # Guardar progreso incremental cada 10 canciones exitosas
        if success_count % 10 == 0:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(candidates, f, ensure_ascii=False, indent=2)
            print(f"💾 Progreso guardado. Total candidatos: {len(candidates)}")
            
    # Guardado final
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(candidates, f, ensure_ascii=False, indent=2)
    print(f"🏁 COMPLETADO. Exitosos: {success_count}, Saltados/Fallados: {skipped_count}, Total final en archivo: {len(candidates)}")

if __name__ == '__main__':
    main()
