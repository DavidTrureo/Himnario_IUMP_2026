import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/home/presentation/tools_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("Widget _buildLogoBox(String path, bool isDark)", "Widget _buildLogoBox(BuildContext context, String path, bool isDark)")
content = content.replace("_buildLogoBox('assets/images/church_logo_clean.png', isDark)", "_buildLogoBox(context, 'assets/images/church_logo_clean.png', isDark)")
content = content.replace("_buildLogoBox('assets/images/mission_logo_v3.png', isDark)", "_buildLogoBox(context, 'assets/images/mission_logo_v3.png', isDark)")

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/home/presentation/tools_screen.dart', 'w') as f:
    f.write(content)

print("Fixed context in _buildLogoBox")
