import sys

# live_worship_screen.dart
file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/live_worship/presentation/live_worship_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

content = content.replace("? '#${hymn.id} - ${hymn.title}' :", "? '${hymn.id}. ${hymn.title}' :")
content = content.replace("? '#${h.id} - ${h.title}' :", "? '${h.id}. ${h.title}' :")

with open(file_path, 'w') as f:
    f.write(content)


# setlist_detail_screen.dart
file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

content = content.replace("? '#${hymn.id} - ${hymn.title}' :", "? '${hymn.id}. ${hymn.title}' :")

with open(file_path, 'w') as f:
    f.write(content)

print("Updated numbering formats")
