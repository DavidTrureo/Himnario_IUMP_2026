import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/main.dart'
with open(file_path, 'r') as f:
    content = f.read()

target = """    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );"""
replacement = """    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: !kIsWeb, // Desactivado en web para evitar latencia de IndexedDB
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );"""

if target in content:
    content = content.replace(target, replacement)
    with open(file_path, 'w') as f:
        f.write(content)
    print("Updated settings")
else:
    print("Not found")
