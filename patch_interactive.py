import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/live_worship/presentation/live_worship_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

old_block = """    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column("""
      
new_block = """    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.5,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column("""

content = content.replace(old_block, new_block)

# And we need to close InteractiveViewer
old_end = """          _buildFormattedLyricsDisplay(rawLyrics, hymn.title, isDark, theme),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);"""
    
new_end = """          _buildFormattedLyricsDisplay(rawLyrics, hymn.title, isDark, theme),
        ],
      ),
      ),
    ).animate().fadeIn(duration: 300.ms);"""

content = content.replace(old_end, new_end)

with open(file_path, 'w') as f:
    f.write(content)
print("patched interactive viewer")
