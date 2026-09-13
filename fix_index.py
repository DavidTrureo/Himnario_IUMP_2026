import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/web/index.html'
with open(file_path, 'r') as f:
    content = f.read()

target = """</head>"""
replacement = """  <script>
    // Capture the initial hash BEFORE Flutter routing (usePathUrlStrategy) clears it
    window._initialWebHash = window.location.hash;
  </script>
</head>"""

if target in content and "window._initialWebHash" not in content:
    content = content.replace(target, replacement)

with open(file_path, 'w') as f:
    f.write(content)
print("Updated index.html")
