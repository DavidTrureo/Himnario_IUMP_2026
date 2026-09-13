import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/home/presentation/splash_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

content = content.replace("final String hash = getWebHash();", "final String hash = initialWebHash;")

with open(file_path, 'w') as f:
    f.write(content)
print("Updated splash screen to use initialWebHash")
