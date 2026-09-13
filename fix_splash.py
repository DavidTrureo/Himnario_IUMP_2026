import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/home/presentation/splash_screen.dart', 'r') as f:
    content = f.read()

# Add import if missing
import_str = "import 'web_helper.dart' if (dart.library.html) 'web_helper_web.dart';\n"
if import_str not in content:
    content = content.replace("import 'package:flutter/foundation.dart';", "import 'package:flutter/foundation.dart';\n" + import_str)

target = """      // Manejar compatibilidad con enlaces antiguos (con #)
      if (kIsWeb) {
        final String uriString = Uri.base.toString();
        if (uriString.contains('/#/')) {
          final path = uriString.split('/#/').last;
          if (path.isNotEmpty && path != '/') {
            context.go('/$path');
            return; // Detenemos la ejecución del splash y saltamos directo
          }
        }
      }"""

replacement = """      // Manejar compatibilidad con enlaces antiguos (con #)
      if (kIsWeb) {
        final String hash = getWebHash();
        if (hash.startsWith('#/')) {
          final path = hash.substring(1); // Quitamos el '#'
          if (path.isNotEmpty && path != '/') {
            context.go(path);
            return; // Detenemos la ejecución del splash y saltamos directo
          }
        }
      }"""

if target in content:
    content = content.replace(target, replacement)
else:
    print("Could not find first target")

target2 = """      if (mounted) {
        if (kIsWeb && Uri.base.toString().contains('/#/')) {
          return;
        }
        context.go('/home');
      }"""

replacement2 = """      if (mounted) {
        if (kIsWeb && getWebHash().startsWith('#/')) {
          return;
        }
        context.go('/home');
      }"""

if target2 in content:
    content = content.replace(target2, replacement2)
else:
    print("Could not find second target")

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/home/presentation/splash_screen.dart', 'w') as f:
    f.write(content)
print("Updated splash screen")
