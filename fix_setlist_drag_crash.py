import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart', 'r') as f:
    content = f.read()

target = """            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),"""

replacement = """            if (setlist.hymnIds.length > 1)
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              )
            else
              const SizedBox(width: 24),"""

if target in content:
    content = content.replace(target, replacement)
    with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed setlist_detail_screen.dart")
else:
    print("Could not find target in setlist_detail_screen.dart")

