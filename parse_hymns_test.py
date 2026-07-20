import sys
import os
import json
import re
from docx import Document

files = [
    "/Users/vitodatrah/Downloads/HIMNOS 1-100 revisado.docx",
    "/Users/vitodatrah/Downloads/HIMNOS 101-200 revisado.docx",
    "/Users/vitodatrah/Downloads/HIMNOS 201 300 R2.docx",
    "/Users/vitodatrah/Downloads/HIMNOS 301-420 revisado.docx",
    "/Users/vitodatrah/Downloads/HIMNOS ESPECIALES revisado.docx"
]

hymns = []
current_hymn = None

def is_title(text):
    text = text.strip()
    if not text:
        return False
    
    alpha_chars = [c for c in text if c.isalpha()]
    if not alpha_chars: return False
    upper_chars = [c for c in alpha_chars if c.isupper()]
    
    ratio = len(upper_chars) / len(alpha_chars)
    return ratio > 0.8 and len(text) > 3

hymn_id = 1

for file_path in files:
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        continue
    
    doc = Document(file_path)
    last_was_empty = False
    
    for para in doc.paragraphs:
        text = para.text.strip()
        
        if not text:
            if current_hymn and current_hymn["lyrics"] and not last_was_empty:
                current_hymn["lyrics"] += "\n\n"
                last_was_empty = True
            continue
            
        clean_text = text.lstrip("•.- \t")
        
        if is_title(clean_text):
            if current_hymn:
                current_hymn["lyrics"] = current_hymn["lyrics"].strip()
                hymns.append(current_hymn)
            
            current_hymn = {
                "id": hymn_id,
                "title": clean_text,
                "tone": "",
                "lyrics": ""
            }
            hymn_id += 1
            last_was_empty = False
        else:
            if current_hymn:
                if clean_text.upper().startswith("TONO:"):
                    current_hymn["tone"] = clean_text
                elif clean_text.upper().startswith("CORO"):
                    if current_hymn["lyrics"] and not current_hymn["lyrics"].endswith("\n\n"):
                        current_hymn["lyrics"] += "\n\n"
                    # DO NOT add an extra \n at the end here!
                    current_hymn["lyrics"] += clean_text
                    last_was_empty = False
                else:
                    is_new_stanza_marker = text.startswith("•") or (len(text)>0 and text[0].isdigit())
                    if is_new_stanza_marker and current_hymn["lyrics"] and not current_hymn["lyrics"].endswith("\n\n"):
                        current_hymn["lyrics"] += "\n\n"
                    
                    if current_hymn["lyrics"].endswith("\n\n"):
                        current_hymn["lyrics"] += clean_text
                    elif current_hymn["lyrics"]:
                        current_hymn["lyrics"] += "\n" + clean_text
                    else:
                        current_hymn["lyrics"] += clean_text
                    last_was_empty = False

if current_hymn:
    current_hymn["lyrics"] = current_hymn["lyrics"].strip()
    hymns.append(current_hymn)

# NOW apply the numbering logic directly inside this script
for hymn in hymns:
    lyrics = hymn['lyrics']
    blocks = lyrics.split('\n\n')
    
    new_blocks = []
    stanza_count = 1
    in_coro = False
    
    for block in blocks:
        block = block.strip()
        if not block:
            continue
            
        block = re.sub(r'^\d+[\.\-]?\s*', '', block)
        
        upper_block = block.upper()
        if upper_block.startswith('CORO'):
            in_coro = True
            new_blocks.append(block)
        else:
            # If we are in the coro, does this block end the coro?
            # A coro usually ends when the next stanza starts.
            # Since we split by \n\n, if it's a new block, is it a new stanza or part of the coro?
            # In the word doc, the coro is often just one paragraph block, but if it spans multiple blocks,
            # how do we know? The user said "cuando comienza el coro solo terminará antes que comience la siguiente estrofa numerada".
            # This implies if we are `in_coro`, we SHOULD NOT number it, unless we KNOW it's a new stanza.
            # But wait, ALL blocks after CORO would then be treated as part of CORO if there's no explicit marker!
            # If the user says "the coro ends before the next numbered stanza", it means the stanzas MUST have numbers originally?
            # But we saw they didn't have numbers in the docx.
            # So the only way to know is if we assume every block is a new stanza UNLESS we are inside a Coro block.
            # Wait, if `in_coro` is true, we should probably reset `in_coro` to false as soon as we encounter a block that doesn't start with "CORO"? No, the user explicitly said "estas confundiendo el coro solo con una linea y le estas asignando un numero de estrofa al resto del coro". This means the Coro is multiple blocks!
            pass

# WAIT, if I just fix the \n bug in parse_hymns, the Coro will be a SINGLE block!
# Because the Word doc had no empty paragraphs between "CORO: ..." and "Al cielo, nos llama,"!
# Let's verify this!
