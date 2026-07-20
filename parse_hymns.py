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
    last_was_title = False
    
    for para in doc.paragraphs:
        text = para.text.strip()
        
        if not text:
            if current_hymn and current_hymn["lyrics"] and not last_was_empty:
                current_hymn["lyrics"] += "\n\n"
                last_was_empty = True
            continue
            
        clean_text = text.lstrip("•.- \t")
        
        if is_title(clean_text):
            if not last_was_title:
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
            else:
                # Append to existing title
                current_hymn["title"] += " " + clean_text
            
            last_was_empty = False
            last_was_title = True
        else:
            if current_hymn:
                if clean_text.upper().startswith("TONO:"):
                    current_hymn["tone"] = clean_text
                elif clean_text.upper().startswith("CORO"):
                    if current_hymn["lyrics"] and not current_hymn["lyrics"].endswith("\n\n"):
                        current_hymn["lyrics"] += "\n\n"
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
            last_was_title = False

if current_hymn:
    current_hymn["lyrics"] = current_hymn["lyrics"].strip()
    hymns.append(current_hymn)

print(f"Total parsed hymns: {len(hymns)}")
with open("hymns_parsed.json", "w", encoding="utf-8") as f:
    json.dump(hymns, f, ensure_ascii=False, indent=2)
