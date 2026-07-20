import json
import re
import locale
import unicodedata

try:
    locale.setlocale(locale.LC_COLLATE, 'es_ES.UTF-8')
except:
    pass

def strip_accents(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

def parse_original(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    content = re.sub(r'\n[ \t]*•[ \t]*', '\n\n• ', content)
    content = re.sub(r'\n[ \t]*(CORO:)', r'\n\n\1', content, flags=re.IGNORECASE)
    blocks = re.split(r'\n\s*\n', content)
    
    hymns = []
    current_hymn = None
    
    for block in blocks:
        block = block.strip()
        if not block:
            continue
            
        lines = block.split('\n')
        first_line = lines[0].strip()
        
        is_title = False
        first_line_clean = re.sub(r'^[ \t]*•[ \t]*', '', first_line).strip()
        if first_line_clean.isupper() and len(first_line_clean) < 100:
            if not first_line_clean.startswith("CORO"):
                is_title = True
        
        if is_title:
            if current_hymn and current_hymn['title']:
                hymns.append(current_hymn)
                
            title = re.sub(r'\s+', ' ', first_line_clean).strip()
            current_hymn = {
                "title": title,
                "tone": "",
                "lyrics_blocks": [],
                "stanza_count": 0
            }
            
            if len(lines) > 1:
                lyrics_lines = []
                for line in lines[1:]:
                    lyrics_lines.append(re.sub(r'^[ \t]+|[ \t]+$', '', line))
                lyrics_text = "\n".join(lyrics_lines).strip()
                
                if bool(re.search(r'^[ \t]*•[ \t]*', lyrics_text)):
                    current_hymn["stanza_count"] += 1
                    lyrics_text = re.sub(r'^[ \t]*•[ \t]*', f'{current_hymn["stanza_count"]}. ', lyrics_text)
                else:
                    special_tags_orig = ["FINAL:", "SOLISTA:", "PUENTE:", "INTERLUDIO:"]
                    if not lyrics_text.upper().startswith("CORO") and not any(lyrics_text.upper().startswith(tag) for tag in special_tags_orig):
                        current_hymn["stanza_count"] += 1
                        lyrics_text = f'{current_hymn["stanza_count"]}. ' + lyrics_text
                current_hymn['lyrics_blocks'].append(lyrics_text)
                
        elif current_hymn:
            lyrics_lines = []
            for line in lines:
                lyrics_lines.append(re.sub(r'^[ \t]+|[ \t]+$', '', line))
            block_clean = "\n".join(lyrics_lines).strip()
            
            block_clean = re.sub(r'^[ \t]*•[ \t]*', '', block_clean).strip()
            
            special_tags_orig = ["FINAL:", "SOLISTA:", "PUENTE:", "INTERLUDIO:"]
            if block_clean.upper().startswith("CORO:"):
                block_clean = re.sub(r'^CORO:[ \t]*', 'CORO: ', block_clean, flags=re.IGNORECASE)
            elif any(block_clean.upper().startswith(tag) for tag in special_tags_orig):
                pass # Do not number these
            else:
                current_hymn["stanza_count"] += 1
                block_clean = f"{current_hymn['stanza_count']}. {block_clean}"
                
            current_hymn['lyrics_blocks'].append(block_clean)

    if current_hymn and current_hymn['title']:
        hymns.append(current_hymn)
        
    return hymns

def parse_easy_worship(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    content = content.replace('\u2028', '\n')
    blocks = re.split(r'\n\s*\n', content)
    
    hymns = []
    current_hymn = None
    uses_roman = False
    
    special_tags = ["FINAL", "INTERLUDIO", "PUENTE", "SOLISTA"]

    for block in blocks:
        block = block.strip()
        if not block:
            continue
            
        lines = block.split('\n')
        first_line = lines[0].strip()
        first_line_upper = first_line.upper()
        
        is_title = False
        if first_line.isupper() and not re.match(r'^(I|II|III|IV|V|VI|VII|VIII|IX|X)$', first_line) and not first_line_upper.startswith("CORO") and first_line_upper not in special_tags and not first_line_upper.startswith("FINAL:") and not first_line_upper.startswith("SOLISTA:"):
            is_title = True
            
        if is_title:
            if current_hymn and current_hymn['title']:
                hymns.append(current_hymn)
            
            title = re.sub(r'\s+', ' ', first_line).strip()
            current_hymn = {
                "title": title,
                "tone": "",
                "lyrics_blocks": [],
                "stanza_count": 0
            }
            uses_roman = False
            
            if len(lines) > 1:
                lyrics_lines = []
                for line in lines[1:]:
                    lyrics_lines.append(line.strip())
                lyrics_text = "\n".join(lyrics_lines).strip()
                if not lyrics_text.upper().startswith("CORO"):
                    current_hymn["stanza_count"] += 1
                    lyrics_text = f'{current_hymn["stanza_count"]}. ' + lyrics_text
                current_hymn['lyrics_blocks'].append(lyrics_text)
                
        elif current_hymn:
            if re.match(r'^(I|II|III|IV|V|VI|VII|VIII|IX|X)$', first_line):
                uses_roman = True
                lines = lines[1:]
                if not lines:
                    continue
                lyrics_text = "\n".join(line.strip() for line in lines).strip()
                current_hymn["stanza_count"] += 1
                lyrics_text = f'{current_hymn["stanza_count"]}. ' + lyrics_text
                current_hymn['lyrics_blocks'].append(lyrics_text)
            elif first_line_upper.startswith("CORO"):
                lyrics_text = "\n".join(line.strip() for line in lines).strip()
                lyrics_text = re.sub(r'^CORO:[ \t]*', 'CORO: ', lyrics_text, flags=re.IGNORECASE)
                current_hymn['lyrics_blocks'].append(lyrics_text)
            elif any(first_line_upper.startswith(tag) for tag in special_tags):
                # Just append as a non-numbered block (like a chorus)
                lyrics_text = "\n".join(line.strip() for line in lines).strip()
                current_hymn['lyrics_blocks'].append(lyrics_text)
            else:
                lyrics_text = "\n".join(line.strip() for line in lines).strip()
                
                # If the hymn uses Roman numerals, any block without one is a continuation of the LAST block.
                # If it doesn't use Roman numerals, it might be a new stanza.
                if uses_roman and current_hymn['lyrics_blocks']:
                    current_hymn['lyrics_blocks'][-1] += "\n\n" + lyrics_text
                else:
                    # New stanza
                    current_hymn["stanza_count"] += 1
                    lyrics_text = f'{current_hymn["stanza_count"]}. ' + lyrics_text
                    current_hymn['lyrics_blocks'].append(lyrics_text)

    if current_hymn and current_hymn['title']:
        hymns.append(current_hymn)
        
    return hymns

if __name__ == '__main__':
    hymns_orig = parse_original('especiales.txt')
    hymns_ew = parse_easy_worship('easy_worship.txt')
    
    # Merge and deduplicate by title (normalized)
    hymns_dict = {}
    for h in hymns_orig + hymns_ew:
        norm_title = strip_accents(h['title'].strip()).lower()
        # The later file (Easy Worship) overrides the earlier one
        hymns_dict[norm_title] = h

    hymns = list(hymns_dict.values())
        
    hymns.sort(key=lambda x: strip_accents(x['title']).lower())

    for idx, h in enumerate(hymns):
        h['id'] = idx + 1
        h['lyrics'] = "\n\n".join(h['lyrics_blocks'])
        h['lyrics'] = h['lyrics'].replace('\u2028', '\n')
        
        final_lines = []
        for line in h['lyrics'].split('\n'):
            line = re.sub(r'^[ \t\xa0]+|[ \t\xa0]+$', '', line)
            final_lines.append(line)
        h['lyrics'] = "\n".join(final_lines)
            
        h['lyrics'] = re.sub(r'\n{3,}', '\n\n', h['lyrics'])
        h['lyrics'] = h['lyrics'].strip()
        del h['lyrics_blocks']
        del h['stanza_count']

    with open('assets/json/special_hymns.json', 'w', encoding='utf-8') as f:
        json.dump(hymns, f, ensure_ascii=False, indent=2)
        
    print(f"Parsed, merged, deduplicated and sorted {len(hymns)} special hymns alphabetically.")
