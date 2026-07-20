#!/usr/bin/env python3
import json
import asyncio
from playwright.async_api import async_playwright

async def run():
    async with async_playwright() as p:
        print("🚀 Lanzando navegador...")
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        print("🌐 Navegando a https://www.himnario.cl/...")
        await page.goto("https://www.himnario.cl/", timeout=60000)
        
        print("🔍 Cambiando paginación a 1000 y cargando lista...")
        await page.evaluate("""
            zs_paginacion = 1000;
            Buscar();
        """)
        
        # Wait for table to load
        print("⏳ Esperando a que se carguen los cantos en la tabla...")
        await page.wait_for_function("document.querySelectorAll('#table1 tr').length > 500", timeout=30000)
        
        rows_count = await page.evaluate("document.querySelectorAll('#table1 tr').length")
        print(f"✅ Se cargaron {rows_count} cantos en la tabla.")
        
        print("📥 Iniciando descarga paralela de letras (esto tomará ~30-60 segundos)...")
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
                await new Promise(r => setTimeout(r, 500));
                return fetchWithRetry(idrow, retries - 1);
              }
              return 'ERROR: ' + e.message;
            }
          }

          const concurrency = 25;
          const queue = [...rows];
          const activePromises = [];
          let completed = 0;
          
          async function worker() {
            while (queue.length > 0) {
              const row = queue.shift();
              if (!row.id) continue;
              const idrow = row.id.replace('fila_?v=', '');
              const titleFont = row.querySelector('font[color]');
              const title = titleFont ? titleFont.innerText.trim() : 'Sin Título';
              
              // Determine category based on font color
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
              
              completed++;
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
        
        # Wait for scrapeStatus to be DONE
        print("⏳ Extrayendo letras...")
        await page.wait_for_function("window.scrapeStatus === 'DONE'", timeout=120000)
        
        results = await page.evaluate("window.scrapedData")
        print(f"🎉 ¡Éxito! Se obtuvieron {len(results)} cantos con sus letras.")
        
        # Save to JSON
        output_path = "/Users/vitodatrah/Desktop/Proyecto_Himnario/scripts/all_hymns_scraped.json"
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
            
        print(f"💾 Resultados guardados en {output_path}")
        await browser.close()

if __name__ == "__main__":
    asyncio.run(run())
