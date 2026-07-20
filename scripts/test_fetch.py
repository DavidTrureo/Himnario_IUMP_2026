import asyncio
from playwright.async_api import async_playwright

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        page.on("console", lambda msg: print(f"Console: {msg.text}"))
        
        await page.goto('https://www.himnario.cl/')
        
        await page.evaluate('''
            zs_paginacion = 10;
            Buscar();
        ''')
        
        await page.wait_for_timeout(3000)
        
        # Get the first idrow
        idrow = await page.evaluate("document.querySelector('#table1 tr').id.replace('fila_?v=', '')")
        print('Testing idrow:', idrow)
        
        result = await page.evaluate('''async (idrow) => {
            return new Promise((resolve) => {
                const xhr = new XMLHttpRequest();
                xhr.open('POST', 'alabanzas_tmp_control.php', true);
                xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                xhr.onreadystatechange = () => {
                    if (xhr.readyState === 4) {
                        resolve(xhr.responseText);
                    }
                };
                const prm = `zs_codigo=${encodeURIComponent(idrow)}&zs_estado=ver_alabanza`;
                xhr.send(prm);
            });
        }''', idrow)
        
        print('Response from page fetch:')
        print(result)
        await browser.close()

if __name__ == '__main__':
    asyncio.run(run())
