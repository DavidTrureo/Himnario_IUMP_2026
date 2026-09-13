import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart', 'r') as f:
    content = f.read()

target1 = """                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final newHymns = List<String>.from(setlist.hymnIds);
                          final item = newHymns.removeAt(oldIndex);
                          newHymns.insert(newIndex, item);
                          final updated = setlist.copyWith(hymnIds: newHymns);
                          ref.read(activeSetlistProvider.notifier).updateSetlist(updated);
                        },"""

replacement1 = """                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final newHymns = List<String>.from(setlist.hymnIds);
                          final item = newHymns.removeAt(oldIndex);
                          newHymns.insert(newIndex, item);
                          final updated = setlist.copyWith(hymnIds: newHymns);
                          ref.read(setlistsProvider.notifier).updateSetlist(updated);
                          ref.read(activeSetlistProvider.notifier).setSetlist(updated);
                        },"""

if target1 in content:
    content = content.replace(target1, replacement1)
    print("Fixed onReorder block")
else:
    print("target1 not found")

# Remove unused _moveHymnInSetlist block
import re
pattern = re.compile(r'  void _moveHymnInSetlist\(.*?  \}\n', re.DOTALL)
content = pattern.sub('', content)

# Remove unused imports
content = content.replace("import 'package:flutter_animate/flutter_animate.dart';\n", "")

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart', 'w') as f:
    f.write(content)
