import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final doc = pw.Document();
  
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return [
          pw.Text("Summary Page"),
        ];
      },
    )
  );

  for (int i=0; i<3; i++) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Text("Hymn ${i+1}"),
          ];
        }
      )
    );
  }

  final bytes = await doc.save();
  File('test_out.pdf').writeAsBytesSync(bytes);
  print("Success. Size: ${bytes.length}");
}
