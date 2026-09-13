import 'dart:io';

void main() {
  final file = File('lib/core/services/setlist_pdf_service.dart');
  String content = file.readAsStringSync();
  
  final target = '''
      for (int i = 0; i < hymns.length; i += 2) {
        final hymn1 = hymns[i];
        final hymn2 = (i + 1 < hymns.length) ? hymns[i + 1] : null;

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            build: (pw.Context context) {
              final contentWidget = pw.Row(''';

  final replacement = '''
      for (int i = 0; i < hymns.length; i += 2) {
        final hymn1 = hymns[i];
        final hymn2 = (i + 1 < hymns.length) ? hymns[i + 1] : null;

        try {
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
              build: (pw.Context context) {
                final contentWidget = pw.Row(''';

  content = content.replaceAll(target, replacement);

  final target2 = '''
                  // FOOTER
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Himnario IUMP · Primera en San Bernardo', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#94A3B8'))),
                      pw.Text('Página \${context.pageNumber} de \${context.pagesCount}', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                    ],
                  )
                ],
              );
            }
          )
        );
      }''';

  final replacement2 = '''
                  // FOOTER
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Himnario IUMP · Primera en San Bernardo', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#94A3B8'))),
                      pw.Text('Página \${context.pageNumber} de \${context.pagesCount}', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                    ],
                  )
                ],
              );
            }
          )
        );
        } catch (e) {
          print("Error en hymn 2 per page: \$e");
        }
      }''';

  content = content.replaceAll(target2, replacement2);
  file.writeAsStringSync(content);
  print("File 2 updated.");
}
