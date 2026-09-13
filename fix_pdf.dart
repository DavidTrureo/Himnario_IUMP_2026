import 'dart:io';

void main() {
  final file = File('lib/core/services/setlist_pdf_service.dart');
  final lines = file.readAsLinesSync();
  
  final startIdx = lines.indexWhere((l) => l.trim() == 'if (mode == ExportMode.fullHymns1PerPage) {');
  if (startIdx == -1) {
    print("Could not find start marker.");
    return;
  }
  
  // Find the end of the `generateSetlistPdf` method by looking for `return doc.save();` and the closing brace before it?
  // Wait, `return doc.save();` is right after the `} else if (mode == ExportMode.fullHymns2PerPage) { ... }` block!
  final endIdx = lines.indexWhere((l) => l.trim() == 'return doc.save();', startIdx);
  if (endIdx == -1) {
    print("Could not find end marker.");
    return;
  }

  // The code we want to insert.
  final replacement = '''
    if (mode == ExportMode.fullHymns1PerPage) {
      for (var hymn in hymns) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  pw.Expanded(
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.topLeft,
                      child: pw.Container(
                        width: PdfPageFormat.a4.width - 72,
                        child: _buildSingleHymnWidget(hymn, compact: false),
                      ),
                    ),
                  ),
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
            },
          ),
        );
      }
    } else if (mode == ExportMode.fullHymns2PerPage) {
      for (int i = 0; i < hymns.length; i += 2) {
        final hymn1 = hymns[i];
        final hymn2 = (i + 1 < hymns.length) ? hymns[i + 1] : null;

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            build: (pw.Context context) {
              final contentWidget = pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildSingleHymnWidget(hymn1, compact: true),
                  ),
                  if (hymn2 != null) ...[
                    pw.SizedBox(width: 24),
                    pw.Container(
                      width: 1,
                      color: PdfColor.fromHex('#E2E8F0'),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      child: _buildSingleHymnWidget(hymn2, compact: true),
                    ),
                  ] else ...[
                    pw.Expanded(child: pw.SizedBox()),
                  ],
                ],
              );

              return pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(setlist.title, style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColor.fromHex('#0F172A'))),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('IGLESIA UNIDA METODISTA PENTECOSTAL', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColor.fromHex('#1E1B4B'))),
                          pw.SizedBox(height: 2),
                          pw.Text('Primera de San Bernardo', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColor.fromHex('#475569'))),
                        ],
                      ),
                      pw.SizedBox(width: 44),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.8),
                  pw.SizedBox(height: 12),
                  pw.Expanded(
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.topLeft,
                      child: pw.Container(
                        width: PdfPageFormat.a4.width - 72,
                        child: contentWidget,
                      ),
                    ),
                  ),
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
      }
    }
''';

  final newLines = [
    ...lines.sublist(0, startIdx),
    replacement,
    ...lines.sublist(endIdx),
  ];

  file.writeAsStringSync(newLines.join('\n'));
  print("File fixed properly.");
}
