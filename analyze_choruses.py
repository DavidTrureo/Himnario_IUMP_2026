import re
from parse_special_hymns import parse_easy_worship

def check_choruses():
    with open('easy_worship.txt', 'r', encoding='utf-8') as f:
        content = f.read().replace('\u2028', '\n')
    
    blocks = re.split(r'\n\s*\n', content)
    
    current_title = ""
    uses_roman = False
    in_chorus = False
    
    for block in blocks:
        block = block.strip()
        if not block: continue
        lines = block.split('\n')
        first_line = lines[0].strip()
        
        if first_line.isupper() and not re.match(r'^(I|II|III|IV|V|VI|VII|VIII|IX|X)$', first_line) and not first_line.startswith("CORO"):
            current_title = first_line
            uses_roman = False
            in_chorus = False
            continue
            
        if re.match(r'^(I|II|III|IV|V|VI|VII|VIII|IX|X)$', first_line):
            uses_roman = True
            in_chorus = False
        elif first_line.upper().startswith("CORO"):
            in_chorus = True
        else:
            if in_chorus:
                print(f"Hymn: {current_title} | Uses Roman: {uses_roman} | Appended to Chorus: {first_line}")

check_choruses()
