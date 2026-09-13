import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart', 'r') as f:
    content = f.read()

target1 = """                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final hymn = setlistHymns[index];
                            return _buildHymnItem(context, ref, setlist, hymn, index, isDark, theme)
                                .animate()
                                .fadeIn(delay: (index * 50).ms)
                                .slideY(begin: 0.05);
                          },
                          childCount: setlistHymns.length,
                        ),
                      ),
                    );"""

replacement1 = """                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverReorderableList(
                        itemCount: setlistHymns.length,
                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final newHymns = List<String>.from(setlist.hymnIds);
                          final item = newHymns.removeAt(oldIndex);
                          newHymns.insert(newIndex, item);
                          final updated = setlist.copyWith(hymnIds: newHymns);
                          ref.read(activeSetlistProvider.notifier).updateSetlist(updated);
                        },
                        itemBuilder: (context, index) {
                          final hymn = setlistHymns[index];
                          return _buildHymnItem(context, ref, setlist, hymn, index, isDark, theme);
                        },
                      ),
                    );"""

target2 = """            // Botones de reordenamiento
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
              onPressed: index > 0 
                ? () => _moveHymnInSetlist(ref, setlist, index, -1)
                : null,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              onPressed: index < setlist.hymnIds.length - 1 
                ? () => _moveHymnInSetlist(ref, setlist, index, 1)
                : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
              onPressed: () => _removeHymnFromSetlist(ref, setlist, index),
            ),
          ],
        ),
        onTap: () {"""

replacement2 = """            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
              onPressed: () => _removeHymnFromSetlist(ref, setlist, index),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        onTap: () {"""

# Also need to make sure _buildHymnItem returns a widget with a Key because SliverReorderableList requires it!
target3 = """  Widget _buildHymnItem(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
    Hymn hymn,
    int index,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),"""

replacement3 = """  Widget _buildHymnItem(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
    Hymn hymn,
    int index,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      key: ValueKey('${hymn.collection}-${hymn.id}'),
      margin: const EdgeInsets.only(bottom: 12),"""

if target1 in content and target2 in content and target3 in content:
    content = content.replace(target1, replacement1)
    content = content.replace(target2, replacement2)
    content = content.replace(target3, replacement3)
    with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart', 'w') as f:
        f.write(content)
    print("Success replacing all targets")
else:
    print("Failed finding targets")
    if target1 not in content: print("target1 failed")
    if target2 not in content: print("target2 failed")
    if target3 not in content: print("target3 failed")
