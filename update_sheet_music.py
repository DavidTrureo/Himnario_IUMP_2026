import sys

with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/hymns/presentation/widgets/sheet_music_viewer.dart', 'r') as f:
    content = f.read()

# 1. Add share_plus import if not exists
if "import 'package:share_plus/share_plus.dart';" not in content:
    content = content.replace("import 'package:url_launcher/url_launcher.dart';", "import 'package:url_launcher/url_launcher.dart';\nimport 'package:share_plus/share_plus.dart';")

# 2. Add _extractFileName method and _shareUrl method
methods_to_add = """
  String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final path = Uri.decodeComponent(uri.path);
      final fileNameWithTimestamp = path.split('/').last;
      final firstUnderscore = fileNameWithTimestamp.indexOf('_');
      if (firstUnderscore != -1 && firstUnderscore < fileNameWithTimestamp.length - 1) {
        return fileNameWithTimestamp.substring(firstUnderscore + 1);
      }
      return fileNameWithTimestamp;
    } catch (e) {
      return 'Partitura';
    }
  }

  void _shareUrl(String url) {
    Share.share(url, subject: 'Partitura de ${widget.hymn.title}');
  }

  @override
  Widget build(BuildContext context) {"""

content = content.replace("  @override\n  Widget build(BuildContext context) {", methods_to_add)

# 3. Replace the PDF UI
target_pdf_ui = """                                      children: [
                                        const Icon(Icons.picture_as_pdf, size: 80, color: Colors.redAccent),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () => launchUrl(Uri.parse(url)),
                                          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                                          label: Text('Abrir Partitura Oficial', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            elevation: 4,
                                          ),
                                        ),
                                      ],"""

replacement_pdf_ui = """                                      children: [
                                        const Icon(Icons.picture_as_pdf, size: 80, color: Colors.redAccent),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () => launchUrl(Uri.parse(url)),
                                          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                                          label: Text('Abrir ${_extractFileName(url)}', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            elevation: 4,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                          onPressed: () => _shareUrl(url),
                                          icon: const Icon(Icons.share_rounded, color: Colors.redAccent),
                                          label: Text('Compartir Enlace', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.redAccent),
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                        ),
                                      ],"""

if target_pdf_ui in content:
    content = content.replace(target_pdf_ui, replacement_pdf_ui)
    with open('/Users/vitodatrah/Desktop/Proyecto_Himnario/lib/features/hymns/presentation/widgets/sheet_music_viewer.dart', 'w') as f:
        f.write(content)
    print("Success updating sheet_music_viewer.dart")
else:
    print("Target PDF UI not found!")

