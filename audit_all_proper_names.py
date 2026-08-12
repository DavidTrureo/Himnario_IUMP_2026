import json
import re

NAMES_AND_PLACES = [
    # Biblical People
    "Abraham", "Sara", "Sarah", "Isaac", "Jacob", "José", "Moisés", "Aarón", "Josué", "Caleb", 
    "Rut", "Ruth", "Samuel", "Saúl", "David", "Salomón", "Elías", "Eliseo", "Isaías", "Jeremías", 
    "Ezequiel", "Daniel", "Oseas", "Joel", "Amós", "Abdías", "Jonás", "Miqueas", "Nahúm", 
    "Habacuc", "Sofonías", "Hageo", "Zacarías", "Malaquías", "Mateo", "Marcos", "Lucas", "Juan", 
    "Pedro", "Pablo", "Silas", "Esteban", "Felipe", "Tomás", "Simón", "Andrés", "Santiago", 
    "Bartolomé", "Judas", "Lázaro", "Marta", "María", "Magdalena", "Nicodemo", "Zaqueo", "Bernabé", 
    "Timoteo", "Tito", "Filemón", "Sansón", "Goliat", "Job", "Noé", "Adán", "Eva", "Abel", 
    "Enoc", "Matusalén", "Lot", "Agar", "Ismael", "Rebeca", "Lea", "Raquel", "Miriam", "Jetro", 
    "Débora", "Barac", "Gedeón", "Jefté", "Dalila", "Elí", "Ana", "Jonatán", "Betsabé", 
    "Absalón", "Jeroboam", "Roboam", "Acab", "Jezabel", "Manasés", "Josías", "Nabucodonosor", 
    "Belsasar", "Ciro", "Darío", "Ester", "Mardoqueo", "Nehemías", "Esdras", "Gabriel", "Miguel", 
    "Herodes", "Pilato", "Caifás", "Ananías", "Safira", "Cornelio", "Lidia", "Apolo", "Aquila", 
    "Priscila", "Dorcas", "Eutico", "Onesíforo", "Diótrefes", "Satán", "Satanás", "Luzbel",
    # Places
    "Belén", "Nazaret", "Nazareth", "Jerusalén", "Beulah", "Edén", "Sión", "Sion", "Galilea", 
    "Judea", "Palestina", "Genesaret", "Chile", "Getsemaní", "Canaán", "Jordán", "Betlehem", 
    "Sarón", "Calvario", "Horeb", "Sinaí", "Carmelo", "Olivos", "Gólgota", "Egipto", "Asiria", 
    "Babilonia", "Roma", "Grecia", "Samaria", "Damasco", "Antioquía", "Tarso", "Éfeso", 
    "Filipos", "Colosas", "Tesalónica", "Corinto", "Atenas", "Patmos", "Jericó", "Betania", 
    "Betel", "Peniel", "Nínive", "Ur", "Sodoma", "Gomorra", "Tiberias", "Efrata", "Sicar", 
    "Siloé", "Siquem", "Cedrón", "Silo", "Galaad", "Basán", "Moab", "Edom", "Amón", "Fenicia", 
    "Tiro", "Sidón", "Nilo", "Éufrates", "Samaritano", "Pentecostés"
]

with open("assets/json/hymns.json", "r", encoding="utf-8") as f:
    hymns = json.load(f)

print(f"Auditing {len(hymns)} hymns for lowercase proper names & places...\n")

findings = []

for h in hymns:
    h_id = h["id"]
    title = h["title"]
    lyrics = h["lyrics"]
    
    text_to_check = f"TITLE: {title}\nLYRICS:\n{lyrics}"
    
    for name in NAMES_AND_PLACES:
        # Search for exact word matching name in lowercase / wrong case
        # e.g. \babraham\b, \bjesús\b, \bmoisés\b
        pattern = re.compile(r'\b' + re.escape(name) + r'\b', re.IGNORECASE)
        for match in pattern.finditer(text_to_check):
            matched_str = match.group(0)
            if matched_str != name and matched_str != name.upper():
                findings.append({
                    "id": h_id,
                    "title": title,
                    "target_name": name,
                    "found_str": matched_str,
                    "context": text_to_check[max(0, match.start()-30):min(len(text_to_check), match.end()+30)].replace("\n", " ")
                })

print(f"Total findings: {len(findings)}\n")
for f in findings:
    print(f"Himno {f['id']} ({f['title']}): Found '{f['found_str']}' for expected '{f['target_name']}' -> Context: ...{f['context']}...")
