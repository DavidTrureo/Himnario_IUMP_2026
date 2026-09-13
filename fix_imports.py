import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/hymns/presentation/admin_suggestions_screen.dart', 'r') as f:
    content = f.read()

target = "import 'package:himnario_iump/core/services/local_hymn_storage_service.dart';"
replacement = "import 'package:himnario_iump/core/services/local_hymn_storage_service.dart';\nimport 'package:himnario_iump/core/services/gemini_ai_service.dart';"

if target in content:
    content = content.replace(target, replacement, 1)
    with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/hymns/presentation/admin_suggestions_screen.dart', 'w') as f:
        f.write(content)
    print("Success fixing imports")
else:
    print("Target not found")
