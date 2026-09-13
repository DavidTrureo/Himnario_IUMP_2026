import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/main.dart'
with open(file_path, 'r') as f:
    content = f.read()

import_str = "import 'features/home/presentation/web_helper.dart' if (dart.library.html) 'features/home/presentation/web_helper_web.dart';\n"
if import_str not in content:
    content = content.replace("import 'package:flutter/foundation.dart';", "import 'package:flutter/foundation.dart';\n" + import_str)

target = """void main() async {"""

replacement = """void main() async {
  captureWebHash(); // Capturamos el hash ANTES de que Flutter lo limpie con usePathUrlStrategy"""

if target in content:
    content = content.replace(target, replacement, 1)

with open(file_path, 'w') as f:
    f.write(content)
print("Updated main.dart")
