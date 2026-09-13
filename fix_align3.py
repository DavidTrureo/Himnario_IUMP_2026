import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/live_worship/presentation/live_worship_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

old_number = """            child: Text(
              '$numStr.',
              style: GoogleFonts.outfit("""
new_number = """            child: Text(
              '$numStr.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit("""
content = content.replace(old_number, new_number)

with open(file_path, 'w') as f:
    f.write(content)
print("fixed numberWidget alignment")
