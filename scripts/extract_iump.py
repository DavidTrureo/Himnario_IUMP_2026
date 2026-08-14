import re
with open("/Users/vitodatrah/.gemini/antigravity-ide/brain/521ca42d-3ec7-49bf-a465-ad65a9b16410/.system_generated/tasks/task-18039.log", "r") as f:
    lines = f.readlines()

iump_hymns = []
for line in lines:
    match = re.search(r'\[IUMP\] (.*) \(ID: (\d+)\)', line)
    if match:
        title = match.group(1)
        id = match.group(2)
        iump_hymns.append(f"- #{id} - {title}")

# Sort by ID
iump_hymns.sort(key=lambda x: int(re.search(r'#(\d+)', x).group(1)))

with open("/Users/vitodatrah/.gemini/antigravity-ide/brain/521ca42d-3ec7-49bf-a465-ad65a9b16410/himnos_iump_modificados.md", "w") as f:
    f.write("# Himnos IUMP Corregidos\n\n")
    f.write("Se detectaron y corrigieron problemas de espacios/saltos de línea en **{}** himnos de la colección oficial IUMP:\n\n".format(len(iump_hymns)))
    f.write("\n".join(iump_hymns))
    
