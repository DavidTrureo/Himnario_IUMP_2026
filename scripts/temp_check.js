async function runScrape() {
  const rows = Array.from(document.querySelectorAll('#table1 tr'));
  const results = [];
  
  async function fetchWithRetry(idrow, retries = 3) {
    try {
      const res = await fetch('alabanzas_tmp_control.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: `zs_codigo=${encodeURIComponent(idrow)}&zs_estado=ver_alabanza&pb_id=himnario`
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
      const idrow = row.id.replace('fila_', '');
      const titleFont = row.querySelector('font[color]');
      const title = titleFont ? titleFont.innerText.trim() : 'Sin Título';
      const img = row.querySelector('img.foto_perfil_small');
      const icon = img ? img.src.split('/').pop() : 'UNKNOWN';
      
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
}
runScrape();
