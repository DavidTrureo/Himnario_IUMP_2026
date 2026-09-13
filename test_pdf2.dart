import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final doc = pw.Document(compress: false);
  
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return [
          pw.Text("Summary Page 123"),
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
  final str = String.fromCharCodes(bytes);
  if (str.contains("Hymn 2")) {
    print("YES, Hymn 2 is in the PDF bytes");
  } else {
    print("NO, Hymn 2 is missing from the PDF bytes!");
  }
}
