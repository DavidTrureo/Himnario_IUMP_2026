import json
import re

def process_hymns():
    with open('assets/json/hymns.json', 'r', encoding='utf-8') as f:
        hymns = json.load(f)
        
    for hymn in hymns:
        lyrics = hymn['lyrics']
        blocks = lyrics.split('\n\n')
        
        new_blocks = []
        stanza_count = 1
        
        for block in blocks:
            block = block.strip()
            if not block:
                continue
                
            # Remove any existing manual numbering (e.g. "1. ", "2. ", "1.-") at the start of the block
            # This ensures we don't end up with "1. 1. "
            block = re.sub(r'^\d+[\.\-]?\s*', '', block)
            
            upper_block = block.upper()
            if upper_block.startswith('CORO'):
                new_blocks.append(block)
            else:
                # Add our own numbering
                new_blocks.append(f"{stanza_count}. {block}")
                stanza_count += 1
                
        hymn['lyrics'] = '\n\n'.join(new_blocks)
        
    with open('assets/json/hymns.json', 'w', encoding='utf-8') as f:
        json.dump(hymns, f, ensure_ascii=False, indent=2)

if __name__ == '__main__':
    process_hymns()
    print("Numbers added to stanzas.")
