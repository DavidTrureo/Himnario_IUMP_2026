import sys

# 1. Update setlist_detail_screen.dart
file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/setlists/presentation/setlist_detail_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Fix Title 1
content = content.replace("? '${hymn.id}. ${hymn.title}' :", "? '${hymn.id} - ${hymn.title}' :")

# Fix Subtitle 1 (in the setlist)
sub1_old = """        subtitle: Text(
          hymn.collection == 'iump' 
            ? 'Himnario IUMP #${hymn.id}' 
            : (hymn.collection == 'especiales' ? 'Alabanza Especial' : 'Coro de Avivamiento'),"""
sub1_new = """        subtitle: Text(
          hymn.collection == 'iump' 
            ? 'Himnario IUMP' 
            : (hymn.collection == 'especiales' ? 'Alabanza Especial' : 'Coro de Avivamiento'),"""
content = content.replace(sub1_old, sub1_new)

# Fix Subtitle 2 (in the add sheet)
sub2_old = """                              subtitle: Text(
                                hymn.collection == 'iump' 
                                  ? 'Himno #${hymn.id}' 
                                  : (hymn.collection == 'especiales' ? 'Alabanza Especial' : 'Coro'),"""
sub2_new = """                              subtitle: Text(
                                hymn.collection == 'iump' 
                                  ? 'Himnario IUMP' 
                                  : (hymn.collection == 'especiales' ? 'Alabanza Especial' : 'Coro de Avivamiento'),"""
content = content.replace(sub2_old, sub2_new)

with open(file_path, 'w') as f:
    f.write(content)


# 2. Update live_worship_screen.dart
file_path = '/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/live_worship/presentation/live_worship_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Fix Titles
content = content.replace("? '${hymn.id}. ${hymn.title}' :", "? '${hymn.id} - ${hymn.title}' :")
content = content.replace("? '${h.id}. ${h.title}' :", "? '${h.id} - ${h.title}' :")

# Fix Subtitle in add sheet
sub3_old = """                          subtitle: Text(
                            h.collection == 'iump' 
                                ? 'Himno #${h.id}' 
                                : (h.collection == 'especiales' ? 'Alabanza Especial' : 'Coro'),"""
sub3_new = """                          subtitle: Text(
                            h.collection == 'iump' 
                                ? 'Himnario IUMP' 
                                : (h.collection == 'especiales' ? 'Alabanza Especial' : 'Coro de Avivamiento'),"""
content = content.replace(sub3_old, sub3_new)

# Add subtitle below title in _buildHymnView
title_block_old = """          // Título del himno
          Text(
            hymn.collection == 'iump' ? '${hymn.id} - ${hymn.title}' : hymn.title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),"""
          
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
          const SizedBox(height: 16),"""
          
content = content.replace(title_block_old, title_block_new)

with open(file_path, 'w') as f:
    f.write(content)

print("Updated formatting")
