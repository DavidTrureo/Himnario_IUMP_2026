import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart', 'r') as f:
    content = f.read()

target = """                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }"""

replacement = """                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }"""

# Actually, let's just use replace_file_content for task.md
