import re
import json

def parse_list():
    with open('/Users/vitodatrah/.gemini/antigravity-ide/brain/521ca42d-3ec7-49bf-a465-ad65a9b16410/scratch/large_list.txt', 'r', encoding='utf-8') as f:
        content = f.read()

    idrow_pattern = re.compile(r"idrow\s*=\s*'([^']+)';")
    title_pattern = re.compile(r"<font color=(?:#2D82D7|#009933|#EE5B83)\s*>([^<]+)</font>")
    icon_pattern = re.compile(r"themes/([a-zA-Z0-9_\.\-]+)")

    matches_idrow = list(idrow_pattern.finditer(content))

    results = []
    for i, match in enumerate(matches_idrow):
        idrow_val = match.group(1)
        start_pos = match.end()
        end_pos = matches_idrow[i+1].start() if i+1 < len(matches_idrow) else len(content)
        chunk = content[start_pos:end_pos]
        
        title_match = title_pattern.search(chunk)
        icon_match = icon_pattern.search(chunk)
        
        title = title_match.group(1).strip() if title_match else 'UNKNOWN'
        icon = icon_match.group(1).strip() if icon_match else 'UNKNOWN'
        
        # Clean title
        title = re.sub(r'<[^>]+>', '', title).strip()
        
        results.append({
            'title': title,
            'idrow': idrow_val,
            'icon': icon
        })

    print(f'Total extracted items: {len(results)}')
    
    # Group by icon
    icon_groups = {}
    for r in results:
        icon_groups[r['icon']] = icon_groups.get(r['icon'], 0) + 1
    
    print('Icon types counts:')
    for icon, count in icon_groups.items():
        print(f' - {icon}: {count}')

    # Save to json file
    with open('/Users/vitodatrah/.gemini/antigravity-ide/brain/521ca42d-3ec7-49bf-a465-ad65a9b16410/scratch/parsed_list.json', 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

if __name__ == '__main__':
    parse_list()
