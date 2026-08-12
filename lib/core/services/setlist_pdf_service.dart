import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/hymns/domain/hymn.dart';
import '../../features/setlists/domain/setlist.dart';

class SetlistExportService {
  /// Genera el texto formateado de un Setlist para WhatsApp o Telegram
  static String formatSetlistText(Setlist setlist, List<Hymn> hymns) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('📋 *PROGRAMA DE CULTO - IUMP*');
    buffer.writeln('🏛️ *Iglesia Primera en San Bernardo*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🎵 *Lista:* ${setlist.title}');
    buffer.writeln('📅 *Fecha:* ${setlist.date}');
    if (setlist.leader.isNotEmpty) buffer.writeln('👤 *Director:* ${setlist.leader}');
    if (setlist.pianist.isNotEmpty) buffer.writeln('🎹 *Pianista:* ${setlist.pianist}');
    if (setlist.rosterInfo.isNotEmpty) buffer.writeln('👥 *Nómina:* ${setlist.rosterInfo}');
    buffer.writeln('🎶 *Cantos seleccionados:* ${hymns.length}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    for (int i = 0; i < hymns.length; i++) {
      final item = hymns[i];
      final toneStr = item.tone.isNotEmpty ? '  (Tono: ${item.tone})' : '';
      buffer.writeln('${i + 1}. *[${item.collection.toUpperCase()}]* ${item.title}$toneStr');
    }

    buffer.writeln('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('✨ *Himnario Oficial IUMP*');
    buffer.writeln('Desarrollado por David Trureo Ahumada');

    return buffer.toString();
  }

  /// Compartir texto formateado por WhatsApp u otras apps
  static Future<void> shareSetlistText(Setlist setlist, List<Hymn> hymns) async {
    final text = formatSetlistText(setlist, hymns);
    await Share.share(
      text,
      subject: 'Programa de Culto: ${setlist.title}',
    );
  }

  /// Genera un documento PDF elegante listo para imprimir o guardar
  static Future<Uint8List> generateSetlistPdf(Setlist setlist, List<Hymn> hymns) async {
    final doc = pw.Document();

    final logoBytes = await rootBundle.load('assets/images/church_logo_clean.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.outfitBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header con Logotipos y Título
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 50,
                      height: 50,
                      child: pw.Image(logoImage),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'IGLESIA UNIDA METODISTA PENTECOSTAL',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 12,
                            color: PdfColors.indigo900,
                          ),
                        ),
                        pw.Text(
                          'Iglesia Primera en San Bernardo',
                          style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo50,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'PROGRAMA DE CULTO',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10,
                      color: PdfColors.indigo900,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.indigo200, thickness: 1),
            pw.SizedBox(height: 12),

            // Título de la Lista
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    setlist.title,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 18,
                      color: PdfColors.indigo900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Fecha: ${setlist.date}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 11,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Tabla de Cantos
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(32),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                // Encabezado Tabla
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '#',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Título del Canto',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Sección',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Tono',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Filas de Cantos
                for (int i = 0; i < hymns.length; i++) ...[
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${i + 1}',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          hymns[i].title,
                          style: pw.TextStyle(font: fontRegular, fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          hymns[i].collection.toUpperCase(),
                          style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          hymns[i].tone.isNotEmpty ? hymns[i].tone : '-',
                          style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.indigo800),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            pw.Spacer(),

            // Footer
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Himnario Oficial IUMP - Primera San Bernardo',
                  style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Desarrollado por David Trureo Ahumada',
                  style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Abrir la vista de impresión / exportar PDF
  static Future<void> printOrSharePdf(Setlist setlist, List<Hymn> hymns) async {
    final pdfBytes = await generateSetlistPdf(setlist, hymns);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Programa_Culto_${setlist.title.replaceAll(' ', '_')}.pdf',
    );
  }
}
