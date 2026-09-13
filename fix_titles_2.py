import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/live_worship/presentation/live_worship_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

target = """                        return ListTile(
                          title: Text(h.title,
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600)),"""
replacement = """                        return ListTile(
                          title: Text(h.collection == 'iump' ? '#${h.id} - ${h.title}' : h.title,
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600)),"""

if target in content:
    content = content.replace(target, replacement)
    with open(file_path, 'w') as f:
        f.write(content)
    print("Updated live_worship_screen.dart (Add dialog)")
