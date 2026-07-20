import json

def move_hymns():
    # Load hymns
    with open('assets/json/hymns.json', 'r', encoding='utf-8') as f:
        hymns = json.load(f)

    # Find hymns 491-496
    hymns_to_move = [h for h in hymns if 491 <= h['id'] <= 496]
    
    # Remove from hymns.json
    hymns_remaining = [h for h in hymns if h['id'] < 491 or h['id'] > 496]

    # Save remaining back to hymns.json
    with open('assets/json/hymns.json', 'w', encoding='utf-8') as f:
        json.dump(hymns_remaining, f, ensure_ascii=False, indent=2)

    # Format hymns_to_move into especiales.txt format
    new_especiales = ""
    for h in hymns_to_move:
        title = h['title'].replace('\n', ' ').replace('\u2028', ' ')
        title = ' '.join(title.split())
        new_especiales += f"{title}\n"
        # The lyrics in hymns.json have numbered stanzas and CORO: 
        # We need to output them properly formatted for especiales.txt
        # In especiales.txt, it's just raw text, parse_original handles numbered stanzas.
        lyrics = h['lyrics']
        # Let's clean it up slightly if needed
        new_especiales += f"{lyrics}\n\n"

    # Append to especiales.txt
    with open('especiales.txt', 'a', encoding='utf-8') as f:
        f.write("\n" + new_especiales)

    print(f"Moved {len(hymns_to_move)} hymns from hymns.json to especiales.txt")

if __name__ == '__main__':
    move_hymns()
