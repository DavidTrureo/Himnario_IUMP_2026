import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/home/presentation/tools_screen.dart', 'r') as f:
    content = f.read()

target = """  Widget _buildLogoBox(String path, bool isDark) {
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(path, fit: BoxFit.contain),
      ),
    );
  }"""

replacement = """  Widget _buildLogoBox(String path, bool isDark) {
    return GestureDetector(
      onTap: () {
        showGeneralDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.9),
          barrierDismissible: true,
          barrierLabel: 'Cerrar',
          pageBuilder: (context, animation, secondaryAnimation) {
            return GestureDetector(
              onTap: () => Navigator.pop(context),
              child: SafeArea(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Image.asset(path, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      child: Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(path, fit: BoxFit.contain),
        ),
      ),
    );
  }"""

if target in content:
    content = content.replace(target, replacement)
    with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/home/presentation/tools_screen.dart', 'w') as f:
        f.write(content)
    print("Success")
else:
    print("Target not found")
