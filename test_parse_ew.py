import re
import json

def parse_easy_worship(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    content = content.replace('\u2028', '\n')
    blocks = re.split(r'\n\s*\n', content)
    
    hymns = []
    current_hymn = None
    
    for block in blocks:
        block = block.strip()
        if not block:
            continue
            
        lines = block.split('\n')
        first_line = lines[0].strip()
        
        # Check if title (all uppercase, no lower case letters, and not roman numerals like 'I', 'II', 'V', 'X', 'CORO')
        is_title = False
        if first_line.isupper() and not re.match(r'^(I|II|III|IV|V|VI|VII|VIII|IX|X)$', first_line) and not first_line.startswith("CORO"):
            is_title = True
            
        if is_title:
            if current_hymn and current_hymn['title']:
                hymns.append(current_hymn)
            
            title = first_line
            current_hymn = {
                "title": title,
                "tone": "",
                "lyrics_blocks": [],
                "stanza_count": 0
            }
            
            if len(lines) > 1:
                # If there are lyrics immediately under the title
                lyrics_lines = []
                for line in lines[1:]:
                    lyrics_lines.append(line.strip())
                lyrics_text = "\n".join(lyrics_lines).strip()
                if not lyrics_text.upper().startswith("CORO"):
                    current_hymn["stanza_count"] += 1
                    lyrics_text = f'{current_hymn["stanza_count"]}. ' + lyrics_text
                current_hymn['lyrics_blocks'].append(lyrics_text)
                
        elif current_hymn:
            # Check if it starts with roman numerals
            if re.match(r'^(I|II|III|IV|V|VI|VII|VIII|IX|X)$', first_line):
                # Remove the roman numeral line
                lines = lines[1:]
                if not lines:
                    continue
                lyrics_text = "\n".join(line.strip() for line in lines).strip()
                current_hymn["stanza_count"] += 1
                lyrics_text = f'{current_hymn["stanza_count"]}. ' + lyrics_text
                current_hymn['lyrics_blocks'].append(lyrics_text)
            elif first_line.upper().startswith("CORO"):
                lyrics_text = "\n".join(line.strip() for line in lines).strip()
                lyrics_text = re.sub(r'^CORO:[ \t]*', 'CORO: ', lyrics_text, flags=re.IGNORECASE)
                current_hymn['lyrics_blocks'].append(lyrics_text)
            else:
                # Normal stanza without numeral
                lyrics_text = "\n".join(line.strip() for line in lines).strip()
                current_hymn["stanza_count"] += 1
                lyrics_text = f'{current_hymn["stanza_count"]}. ' + lyrics_text
                current_hymn['lyrics_blocks'].append(lyrics_text)

    if current_hymn and current_hymn['title']:
        hymns.append(current_hymn)
        
    return hymns

if __name__ == '__main__':
    hymns = parse_easy_worship('easy_worship.txt')
    print(f"Parsed {len(hymns)} hymns from Easy Worship.")
    for h in hymns[:3]:
        print(h['title'])
        print(h['lyrics_blocks'])
