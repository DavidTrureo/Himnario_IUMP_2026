import json
import asyncio
import re
import unicodedata
from playwright.async_api import async_playwright

def normalize_text(text):
    if not text:
        return ""
    # Quitar acordes entre corchetes
    text = re.sub(r'\[[^\]]+\]', '', text)
    # Convertir a minúsculas
    text = text.lower()
    # Quitar acentos
    text = "".join(c for c in unicodedata.normalize('NFD', text) if unicodedata.category(c) != 'Mn')
    # Dejar solo letras y números
    text = re.sub(r'[^a-z0-9]', '', text)
    return text

async def scrape():
    async with async_playwright() as p:
        print("🚀 Lanzando navegador Playwright...")
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        print("🌐 Navegando a https://www.himnario.cl/...")
        await page.goto("https://www.himnario.cl/", timeout=60000)
        
        print("🔍 Configurando paginación a 10000...")
        await page.evaluate("""
            zs_paginacion = 10000;
            Buscar();
        """)
        
        print("⏳ Esperando que cargue la lista de cantos...")
        await page.wait_for_function("document.querySelectorAll('#table1 tr').length > 10000", timeout=45000)
        
        rows_count = await page.evaluate("document.querySelectorAll('#table1 tr').length")
        print(f"✅ Se cargaron {rows_count} filas en la tabla.")
        
        print("📥 Iniciando descarga concurrente de letras...")
        scraper_js = r"""
        (async () => {
          const rows = Array.from(document.querySelectorAll('#table1 tr'));
          const results = [];
          
          async function fetchWithRetry(idrow, retries = 3) {
            try {
              const res = await fetch('alabanzas_tmp_control.php', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded'
                },
                body: `zs_codigo=${encodeURIComponent(idrow)}&zs_estado=ver_alabanza`
              });
              const text = await res.text();
              const match = text.match(/himno_texto\.innerHTML\s*=\s*'([\s\S]*?)';/);
              if (match) {
                let html = match[1];
                html = html.replace(/\\'/g, "'").replace(/\\"/g, '"');
                const div = document.createElement('div');
                div.innerHTML = html;
                return div.innerText.trim();
              }
              return '';
            } catch (e) {
              if (retries > 0) {
                await new Promise(r => setTimeout(r, 600));
                return fetchWithRetry(idrow, retries - 1);
              }
              return '';
            }
          }

          const concurrency = 40;
          const queue = [...rows];
          const activePromises = [];
          
          async function worker() {
            while (queue.length > 0) {
              const row = queue.shift();
              if (!row.id) continue;
              const idrow = row.id.replace('fila_?v=', '');
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
              
              const lyrics = await fetchWithRetry(idrow);
              results.push({ title, idrow, icon, lyrics });
            }
          }

          for (let i = 0; i < concurrency; i++) {
            activePromises.push(worker());
          }
          await Promise.all(activePromises);
          
          window.scrapedData = results;
          window.scrapeStatus = "DONE";
        })();
        """
        
        await page.evaluate(scraper_js)
        await page.wait_for_function("window.scrapeStatus === 'DONE'", timeout=240000)
        
        results = await page.evaluate("window.scrapedData")
        print(f"🎉 ¡Scraping terminado! Se obtuvieron {len(results)} cantos totales.")
        await browser.close()
        return results

def filter_and_save(scraped_hymns):
    print("🧹 Iniciando proceso de filtrado de duplicados...")
    
    # 1. Cargar base de datos existente
    base_dir = '/Users/vitodatrah/Desktop/Proyecto_Himnario/assets/json'
    files = {
        'iump': f'{base_dir}/hymns.json',
        'especiales': f'{base_dir}/special_hymns.json',
        'coros': f'{base_dir}/coros.json'
    }
    
    existing_titles = set()
    existing_lyrics = set()
    
    for category, filepath in files.items():
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
                for item in data:
                    title_norm = normalize_text(item.get('title', ''))
                    lyrics_norm = normalize_text(item.get('lyrics', ''))
                    if title_norm:
                        existing_titles.add(title_norm)
                    if lyrics_norm:
                        existing_lyrics.add(lyrics_norm)
        except Exception as e:
            print(f"⚠️ Error cargando {filepath}: {e}")
            
    print(f"📚 Base de datos actual cargada: {len(existing_titles)} títulos y {len(existing_lyrics)} letras únicas.")

    # 2. Filtrar cantos extraídos
    new_candidates = []
    seen_lyrics_in_candidates = set()
    seen_titles_in_candidates = set()
    
    rejected_by_chords = 0
    rejected_by_existing_title = 0
    rejected_by_existing_lyrics = 0
    rejected_by_duplicate_in_candidates = 0
    
    for h in scraped_hymns:
        title = h.get('title', '').strip()
        lyrics = h.get('lyrics', '').strip()
        icon = h.get('icon', '')
        
        if not title or not lyrics:
            continue
            
        # Filtrar si tiene acordes (icono de acordes o corchetes)
        if icon == 'acordes.png' or '[' in lyrics or ']' in lyrics:
            rejected_by_chords += 1
            continue
            
        title_norm = normalize_text(title)
        lyrics_norm = normalize_text(lyrics)
        
        # Filtrar si ya existe en la base de datos por título
        if title_norm in existing_titles:
            rejected_by_existing_title += 1
            continue
            
        # Filtrar si ya existe en la base de datos por letra
        if lyrics_norm in existing_lyrics:
            rejected_by_existing_lyrics += 1
            continue
            
        # Filtrar si está duplicado dentro de la misma lista de nuevos candidatos
        if lyrics_norm in seen_lyrics_in_candidates or title_norm in seen_titles_in_candidates:
            rejected_by_duplicate_in_candidates += 1
            continue
            
        seen_lyrics_in_candidates.add(lyrics_norm)
        seen_titles_in_candidates.add(title_norm)
        new_candidates.append({
            'title': title.upper(),
            'lyrics': lyrics,
            'collection': 'especiales', # Por defecto a especiales
        })
        
    print(f"📊 Estadísticas de filtrado:")
    print(f"- Rechazados por tener acordes: {rejected_by_chords}")
    print(f"- Rechazados por título existente: {rejected_by_existing_title}")
    print(f"- Rechazados por letra existente: {rejected_by_existing_lyrics}")
    print(f"- Rechazados por duplicación en candidatos: {rejected_by_duplicate_in_candidates}")
    print(f"✨ Candidatos limpios encontrados: {len(new_candidates)}")
    
    # Guardar candidatos
    output_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/scripts/new_hymns_candidates.json'
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(new_candidates, f, ensure_ascii=False, indent=2)
    print(f"💾 Candidatos guardados en {output_path}")

async def main():
    scraped_hymns = await scrape()
    # Guardar archivo completo crudo
    raw_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/scripts/all_hymns_scraped.json'
    with open(raw_path, 'w', encoding='utf-8') as f:
        json.dump(scraped_hymns, f, ensure_ascii=False, indent=2)
    print(f"💾 Guardado archivo crudo total en {raw_path}")
    
    filter_and_save(scraped_hymns)

if __name__ == '__main__':
    asyncio.run(main())
