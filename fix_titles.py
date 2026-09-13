import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

target1 = """        title: Text(
          hymn.title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),"""
replacement1 = """        title: Text(
          hymn.collection == 'iump' ? '#${hymn.id} - ${hymn.title}' : hymn.title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),"""

if target1 in content:
    content = content.replace(target1, replacement1)

target2 = """                              title: Text(hymn.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),"""
replacement2 = """                              title: Text(hymn.collection == 'iump' ? '#${hymn.id} - ${hymn.title}' : hymn.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),"""

if target2 in content:
    content = content.replace(target2, replacement2)

with open(file_path, 'w') as f:
    f.write(content)
print("Updated setlist_detail_screen.dart")

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/live_worship/presentation/live_worship_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

target3 = """          // Título del himno
          Text(
            hymn.title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),"""
replacement3 = """          // Título del himno
          Text(
            hymn.collection == 'iump' ? '#${hymn.id} - ${hymn.title}' : hymn.title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),"""

if target3 in content:
    content = content.replace(target3, replacement3)

with open(file_path, 'w') as f:
    f.write(content)
print("Updated live_worship_screen.dart")
