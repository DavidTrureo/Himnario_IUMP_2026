import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/live_worship/presentation/live_worship_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

old_chorus_text = """                  child: Text(
                    Hymn.formatLineCasing(line),
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      height: 1.6,
                      fontWeight: FontWeight.w600,"""
new_chorus_text = """                  child: Text(
                    Hymn.formatLineCasing(line),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      height: 1.6,
                      fontWeight: FontWeight.w600,"""
content = content.replace(old_chorus_text, new_chorus_text)

with open(file_path, 'w') as f:
    f.write(content)
print("fixed chorus text alignment")
