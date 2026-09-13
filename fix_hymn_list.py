import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/hymns/presentation/hymn_list_screen.dart', 'r') as f:
    content = f.read()

target = """                        return ReorderableListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 80.0),
                          itemCount: hymns.length,"""

replacement = """                        return ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 80.0),
                          itemCount: hymns.length,"""

if target in content:
    content = content.replace(target, replacement)
    with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/hymns/presentation/hymn_list_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed hymn_list_screen.dart")
else:
    print("Could not find target in hymn_list_screen.dart")

