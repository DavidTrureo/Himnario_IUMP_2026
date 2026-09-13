import sys

file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/live_worship/presentation/live_worship_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

# 1. _buildHymnView Column crossAxisAlignment
old_hymn_view_col = """      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,"""
new_hymn_view_col = """      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,"""
content = content.replace(old_hymn_view_col, new_hymn_view_col)

# 2. _buildHymnView Row for badges mainAxisAlignment
old_hymn_view_row = """          // Número e información básica
          Row(
            children: [
              Container("""
new_hymn_view_row = """          // Número e información básica
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container("""
content = content.replace(old_hymn_view_row, new_hymn_view_row)

# 3. _buildFormattedLyricsDisplay main Column crossAxisAlignment
old_formatted_col = """    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,"""
new_formatted_col = """    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,"""
content = content.replace(old_formatted_col, new_formatted_col)

# 4. _buildFormattedLyricsDisplay isChorus Column crossAxisAlignment
old_chorus_col = """            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,"""
new_chorus_col = """            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,"""
content = content.replace(old_chorus_col, new_chorus_col)

# 5. _buildFormattedLyricsDisplay non-chorus Column crossAxisAlignment
old_nonchorus_col = """          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,"""
new_nonchorus_col = """          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,"""
content = content.replace(old_nonchorus_col, new_nonchorus_col)

# 6. _buildFormattedLyricsDisplay text alignment for chorus
old_chorus_text = """                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      height: 1.6,
                      color: isDark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF334155),
                    ),
                  ),
                );"""
new_chorus_text = """                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      height: 1.6,
                      color: isDark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF334155),
                    ),
                  ),
                );"""
content = content.replace(old_chorus_text, new_chorus_text)

with open(file_path, 'w') as f:
    f.write(content)
print("fixed alignment")
