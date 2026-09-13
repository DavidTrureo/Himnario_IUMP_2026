import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/live_worship/presentation/live_worship_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

old_block = """                child: Text(
                  '${session.currentIndex + 1} / ${session.hymnIds.length}',
                  style: GoogleFonts.outfit("""
                  
new_block = """                child: Text(
                  '${session.currentIndex + 1} de ${session.hymnIds.length}',
                  style: GoogleFonts.outfit("""

content = content.replace(old_block, new_block)

with open(file_path, 'w') as f:
    f.write(content)
print("fraction fixed")
