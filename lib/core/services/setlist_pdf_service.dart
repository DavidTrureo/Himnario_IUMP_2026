import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/hymns/domain/hymn.dart';
import '../../features/setlists/domain/setlist.dart';
import 'hymn_pdf_service.dart';
import 'chord_transposer_service.dart';

enum ExportMode {
  summaryOnly,
  fullHymns1PerPage,
  fullHymns2PerPage,
}

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
  static Future<Uint8List> generateSetlistPdf(Setlist setlist, List<Hymn> hymns, {ExportMode mode = ExportMode.summaryOnly}) async {
    final doc = pw.Document();

    final logoBytes = await rootBundle.load('assets/images/church_logo_clean.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    
    pw.MemoryImage? missionLogo;
    try {
      final missionBytes = await rootBundle.load('assets/images/mission_logo_v3.png');
      missionLogo = pw.MemoryImage(missionBytes.buffer.asUint8List());
    } catch (_) {}

    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.outfitBold();

    // 1. PÁGINA DE RESUMEN (Siempre se incluye como portada)
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
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
                    'PROGRAMA DE CULTO - IUMP',
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

            pw.SizedBox(height: 24),

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

    // Si solo es resumen, retornamos aquí.
    if (mode == ExportMode.summaryOnly) {
      return doc.save();
    }

    // 2. PÁGINAS DE CANTOS
    
    // Función auxiliar para generar el widget de un canto
    pw.Widget _buildSingleHymnWidget(Hymn hymn, {bool compact = false}) {
      String lyricsToRender = Hymn.ensureHeadersOnOwnLine(hymn.lyrics);
      
      String currentTone = hymn.toneNote.trim();
      if (currentTone.isEmpty && hymn.tone.isNotEmpty) {
        final match = RegExp(r'^(DO#|DO|RE#|REb|RE|MIB|MI|FA#|FA|SOL#|SOLB|SOL|LAB|LA#|LAb|LA|SIB|SI|C#|Db|C|D#|Eb|D|E|F#|F|G#|Ab|G|A#|Bb|A|B)', caseSensitive: false).firstMatch(hymn.tone.trim());
        if (match != null) {
          currentTone = match.group(1)!;
        }
      }
      final validNoteRegex = RegExp(r'^(DO|RE|MI|FA|SOL|LA|SI|[A-G])', caseSensitive: false);
      if (!validNoteRegex.hasMatch(currentTone) || currentTone.toLowerCase().contains('tiempo')) {
        currentTone = '';
      }

      String collectionLabel = 'HIMNARIO IUMP';
      if (hymn.collection == 'especiales') collectionLabel = 'ALABANZA ESPECIAL';
      else if (hymn.collection == 'coros') collectionLabel = 'CORO DE AVIVAMIENTO';

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      collectionLabel,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: compact ? 9 : 11,
                        color: PdfColor.fromHex('#4F46E5'),
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      hymn.title,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: compact ? 20 : 24,
                        color: PdfColor.fromHex('#0F172A'),
                      ),
                    ),
                  ],
                ),
              ),
              if (currentTone.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EEF2FF'),
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColor.fromHex('#C7D2FE'), width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'TONO',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: compact ? 7 : 8,
                          color: PdfColor.fromHex('#6366F1'),
                        ),
                      ),
                      pw.Text(
                        currentTone,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: compact ? 12 : 14,
                          color: PdfColor.fromHex('#312E81'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: compact ? 12 : 16),
          // Usamos el buildHymnContent de HymnPdfService!
          // Pasamos transposeOffset = 0, y notation = 'spanish' (por defecto)
          HymnPdfService.buildLyricsPdfWidget(lyricsToRender, fontRegular, fontBold, 0, 'spanish', forceSingleColumn: compact),
        ],
      );
    }

    if (mode == ExportMode.fullHymns1PerPage) {
      for (var hymn in hymns) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.letter,
            margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            build: (pw.Context context) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.topLeft,
                      child: pw.Container(
                        width: PdfPageFormat.letter.width - 72,
                        child: _buildSingleHymnWidget(hymn, compact: false),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Himnario IUMP · Primera en San Bernardo', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#94A3B8'))),
                      pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#64748B'))),
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
            pageFormat: PdfPageFormat.letter,
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
                mainAxisAlignment: pw.MainAxisAlignment.start,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    height: 35,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(setlist.title, style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColor.fromHex('#0F172A'))),
                      pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
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
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.8),
                  pw.SizedBox(height: 12),
                  pw.Expanded(
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.topLeft,
                      child: pw.Container(
                        width: PdfPageFormat.letter.width - 72,
                        child: contentWidget,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Himnario IUMP · Primera en San Bernardo', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#94A3B8'))),
                      pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                    ],
                  )
                ],
              );
            }
          )
        );
      }
    }

    return doc.save();
  }

  /// Abrir la vista de impresión / exportar PDF
  static Future<void> printOrSharePdf(Setlist setlist, List<Hymn> hymns, {ExportMode mode = ExportMode.summaryOnly}) async {
    final pdfBytes = await generateSetlistPdf(setlist, hymns, mode: mode);
    String filenameMode = '';
    if (mode == ExportMode.fullHymns1PerPage) filenameMode = '_1xPagina';
    if (mode == ExportMode.fullHymns2PerPage) filenameMode = '_2xPagina';
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Programa_Culto_${setlist.title.replaceAll(' ', '_')}$filenameMode.pdf',
    );
  }
}