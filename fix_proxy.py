import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart', 'r') as f:
    content = f.read()

target = """                      sliver: SliverReorderableList(
                        itemCount: setlistHymns.length,
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            type: MaterialType.transparency,
                            child: child,
                          );
                        },"""

replacement = """                      sliver: SliverReorderableList(
                        itemCount: setlistHymns.length,
                        proxyDecorator: (Widget child, int index, Animation<double> animation) {
                          return Material(
                            elevation: 4,
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: child,
                          );
                        },"""

if target in content:
    content = content.replace(target, replacement)
    with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed proxyDecorator")
else:
    print("Could not find target")
