import sys

# 1. Update live_worship_screen.dart
file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/live_worship/presentation/live_worship_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

title_block_old = """          // Título del himno
          Text(
            hymn.collection == 'iump' ? '${hymn.id} - ${hymn.title}' : hymn.title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),"""
          
title_block_new = """          // Título del himno
          Text(
            hymn.collection == 'iump' ? '${hymn.id} - ${hymn.title}' : hymn.title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            hymn.collection == 'iump' 
                ? 'Himnario IUMP' 
                : (hymn.collection == 'especiales' ? 'Alabanza Especial' : 'Coro de Avivamiento'),
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),"""

content = content.replace(title_block_old, title_block_new)

with open(file_path, 'w') as f:
    f.write(content)

# 2. Update splash_screen.dart
file_path2 = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/home/presentation/splash_screen.dart'
with open(file_path2, 'r') as f:
    content2 = f.read()

content2 = content2.replace("Timer(const Duration(milliseconds: 4800),", "Timer(const Duration(milliseconds: 2500),")
content2 = content2.replace("_playSplashSound();\n    });", "// _playSplashSound();\n    });")

with open(file_path2, 'w') as f:
    f.write(content2)

print("Updated UI and Splash")
