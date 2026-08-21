
import 'package:himnario_iump/core/services/chord_transposer_service.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/hymns/domain/hymn.dart';
import 'chord_transposer_service.dart';

class HymnPdfService {
  /// Genera un documento PDF profesional y hermoso para un canto individual.
  static Future<Uint8List> generateHymnPdf(
    Hymn hymn, {
    int transposeOffset = 0,
    bool includeChords = true,
    String notation = 'spanish',
  }) async {
    final doc = pw.Document();

    // Cargar logotipos oficial e iglesia local
    pw.MemoryImage? missionLogo;
    pw.MemoryImage? churchLogo;
    try {
      final missionBytes = await rootBundle.load('assets/images/mission_logo_v3.png');
      missionLogo = pw.MemoryImage(missionBytes.buffer.asUint8List());
    } catch (_) {}

    try {
      final churchBytes = await rootBundle.load('assets/images/church_logo_clean.png');
      churchLogo = pw.MemoryImage(churchBytes.buffer.asUint8List());
    } catch (_) {}

    // Cargar fuentes estilizadas desde Google Fonts PDF
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.outfitBold();

    // Procesar letra y transposición (asegurando cabeceras en su propia línea)
    String lyricsToRender = Hymn.ensureHeadersOnOwnLine(hymn.lyrics);
    if (transposeOffset != 0 && includeChords) {
      lyricsToRender = ChordTransposerService.transposeLyrics(lyricsToRender, transposeOffset);
    }
    if (!includeChords) {
      lyricsToRender = lyricsToRender.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
    }

    // Extraer solo la nota de tonalidad limpia
    String currentTone = hymn.toneNote.trim();
    if (currentTone.isEmpty && hymn.tone.isNotEmpty) {
      final match = RegExp(r'^(DO#|DO|RE#|REb|RE|MIB|MI|FA#|FA|SOL#|SOLB|SOL|LAB|LA#|LAb|LA|SIB|SI|C#|Db|C|D#|Eb|D|E|F#|F|G#|Ab|G|A#|Bb|A|B)', caseSensitive: false).firstMatch(hymn.tone.trim());
      if (match != null) {
        currentTone = match.group(1)!;
      }
    }
    // Validar que realmente sea una nota musical y no frases como "3 TIEMPOS (3/4)"
    final validNoteRegex = RegExp(r'^(DO|RE|MI|FA|SOL|LA|SI|[A-G])', caseSensitive: false);
    if (!validNoteRegex.hasMatch(currentTone) || currentTone.toLowerCase().contains('tiempo')) {
      currentTone = '';
    }

    if (transposeOffset != 0 && currentTone.isNotEmpty) {
      currentTone = ChordTransposerService.transposeSingleChord(currentTone, transposeOffset);
    }

    // Nombre de la colección
    String collectionLabel = 'HIMNARIO IUMP';
    if (hymn.collection == 'especiales') {
      collectionLabel = 'ALABANZA ESPECIAL';
    } else if (hymn.collection == 'coros') {
      collectionLabel = 'CORO DE AVIVAMIENTO';
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Logo Misión (Izquierda)
                  if (missionLogo != null)
                    pw.Container(
                      width: 44,
                      height: 44,
                      child: pw.Image(missionLogo),
                    )
                  else
                    pw.SizedBox(width: 44),

                  // Títulos Centrales
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'IGLESIA UNIDA METODISTA PENTECOSTAL',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 12,
                          color: PdfColor.fromHex('#1E1B4B'),
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Primera de San Bernardo · Himnario Oficial 2026',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 9,
                          color: PdfColor.fromHex('#475569'),
                        ),
                      ),
                    ],
                  ),

                  // Logo Iglesia Local (Derecha)
                  if (churchLogo != null)
                    pw.Container(
                      width: 44,
                      height: 44,
                      child: pw.Image(churchLogo),
                    )
                  else
                    pw.SizedBox(width: 44),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.8),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.5),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Himnario IUMP · Primera en San Bernardo',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: PdfColor.fromHex('#94A3B8'),
                    ),
                  ),
                  pw.Text(
                    'Página ${context.pageNumber} de ${context.pagesCount}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: PdfColor.fromHex('#94A3B8'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Banner Encabezado del Himno
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Etiqueta Colección + Número
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#4F46E5'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      hymn.collection == 'iump'
                          ? '$collectionLabel  N° ${hymn.id}'
                          : collectionLabel,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // Título del Himno
                  pw.Text(
                    hymn.title.toUpperCase(),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 18,
                      color: PdfColor.fromHex('#0F172A'),
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  // Fila de Metadatos (Tonalidad, Métrica, Tiempos)
                  pw.Row(
                    children: [
                      if (currentTone.isNotEmpty) ...[
                        _buildMetaBadge('TONALIDAD', currentTone, fontBold, fontRegular, '#EEF2FF', '#312E81'),
                        pw.SizedBox(width: 8),
                      ],
                      if (hymn.beats.isNotEmpty) ...[
                        _buildMetaBadge('TIEMPO', hymn.beats, fontBold, fontRegular, '#FEF3C7', '#78350F'),
                        pw.SizedBox(width: 8),
                      ],
                      if (hymn.timeSignature.isNotEmpty) ...[
                        _buildMetaBadge('MÉTRICA', hymn.timeSignature, fontBold, fontRegular, '#F0FDF4', '#14532D'),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 18),

            // Cuerpo de la Letra
            buildLyricsPdfWidget(lyricsToRender, fontRegular, fontBold, transposeOffset, notation),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildMetaBadge(
    String label,
    String value,
    pw.Font fontBold,
    pw.Font fontRegular,
    String bgColorHex,
    String textColorHex,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(bgColorHex),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 8,
              color: PdfColor.fromHex(textColorHex),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 8,
              color: PdfColor.fromHex(textColorHex),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget buildLyricsPdfWidget(
    String lyrics,
    pw.Font fontRegular,
    pw.Font fontBold,
    int transposeOffset,
    String notation,
    {bool forceSingleColumn = false}
  ) {
    final blocks = lyrics.trim().split(RegExp(r'\n\s*\n')).where((b) => b.trim().isNotEmpty).toList();
    final totalLines = lyrics.split('\n').where((l) => l.trim().isNotEmpty).length;

    // Determinar si cada bloque es parte de un coro
    final List<bool> isChorusList = [];
    bool currentIsChorus = false;
    for (final b in blocks) {
      final lines = b.trim().split('\n');
      if (lines.isNotEmpty) {
        final firstLine = lines.first.trim().toLowerCase();
        final hasExplicitChorusHeader = firstLine.contains('coro') || 
                                        firstLine.contains('puente') || 
                                        firstLine.contains('interludio');
        final isVerseHeader = RegExp(r'^(estrofa|\d+\.|\d+\b)', caseSensitive: false).hasMatch(firstLine);

        if (hasExplicitChorusHeader) {
          currentIsChorus = true;
        } else if (isVerseHeader) {
          currentIsChorus = false;
        }
      }
      isChorusList.add(currentIsChorus);
    }

    // Si la letra es extensa (18 líneas o más de 3 bloques), organizamos en 2 columnas para caber en 1 sola hoja
    if (!forceSingleColumn && (totalLines >= 18 || blocks.length > 3)) {
      final int halfIndex = (blocks.length / 2).ceil();
      final leftBlocks = blocks.sublist(0, halfIndex);
      final rightBlocks = blocks.sublist(halfIndex);
      
      final leftChorusState = isChorusList.sublist(0, halfIndex);
      final rightChorusState = isChorusList.sublist(halfIndex);

      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: List.generate(leftBlocks.length, (i) => buildBlockWidget(leftBlocks[i], fontRegular, fontBold, leftChorusState[i], transposeOffset, notation)),
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Container(
            width: 0.5,
            height: 420,
            color: PdfColor.fromHex('#E2E8F0'),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: List.generate(rightBlocks.length, (i) => buildBlockWidget(rightBlocks[i], fontRegular, fontBold, rightChorusState[i], transposeOffset, notation)),
            ),
          ),
        ],
      );
    }

    // Si es corto, se muestra en 1 sola columna
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: List.generate(blocks.length, (i) => buildBlockWidget(blocks[i], fontRegular, fontBold, isChorusList[i], transposeOffset, notation)),
    );
  }

  static pw.Widget buildBlockWidget(
    String blockText,
    pw.Font fontRegular,
    pw.Font fontBold,
    bool isChorusBlock,
    int transposeOffset,
    String notation,
  ) {
    final lines = blockText.trim().split('\n');
    if (lines.isEmpty) return pw.SizedBox();

    final firstLine = lines.first.trim();
    final hasExplicitChorusHeader = firstLine.toLowerCase().contains('coro') ||
                                    firstLine.toLowerCase().contains('puente') ||
                                    firstLine.toLowerCase().contains('interludio');

    final isVerseHeader = RegExp(r'^(estrofa|\d+\.|\d+\b)', caseSensitive: false).hasMatch(firstLine);

    final List<pw.Widget> lineWidgets = [];

    int startIdx = 0;
    pw.Widget? headerWidget;

    if (hasExplicitChorusHeader) {
      headerWidget = pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#4F46E5'),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          firstLine.toUpperCase(),
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 8.5,
            color: PdfColors.white,
            letterSpacing: 0.8,
          ),
        ),
      );
      startIdx = 1;
    } else if (isVerseHeader && !isChorusBlock) {
      headerWidget = pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
        child: pw.Text(
          firstLine,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 11,
            color: PdfColor.fromHex('#1E1B4B'),
          ),
        ),
      );
      startIdx = 1;
    }

    for (int i = startIdx; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.contains('[') && trimmed.contains(']')) {
        lineWidgets.add(buildLineWithChords(Hymn.formatLineCasing(trimmed), fontRegular, fontBold, transposeOffset, notation));
      } else {
        lineWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Text(
              line,
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 11,
                color: PdfColor.fromHex('#1E293B'),
                height: 1.35,
              ),
            ),
          ),
        );
      }
    }

    if (isChorusBlock) {
      // Tarjeta destacada elegante para el Coro
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F5F3FF'),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border(
            left: pw.BorderSide(color: PdfColor.fromHex('#4F46E5'), width: 3),
            top: pw.BorderSide(color: PdfColor.fromHex('#DDD6FE'), width: 0.5),
            right: pw.BorderSide(color: PdfColor.fromHex('#DDD6FE'), width: 0.5),
            bottom: pw.BorderSide(color: PdfColor.fromHex('#DDD6FE'), width: 0.5),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (headerWidget != null) headerWidget,
            ...lineWidgets,
          ],
        ),
      );
    }

    // Bloque estándar para Estrofas
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (headerWidget != null) headerWidget,
          ...lineWidgets,
        ],
      ),
    );
  }

  /// Procesa una línea de letra con acordes embebidos tipo "Señor [DO] mi Dios [SOL] al contemplar"
  static pw.Widget buildLineWithChords(
    String line,
    pw.Font fontRegular,
    pw.Font fontBold,
    int transposeOffset,
    String notation,
  ) {
    final RegExp regExp = RegExp(r'\[([^\]]+)\]');
    final matchesList = regExp.allMatches(line).toList();

    if (matchesList.isEmpty) {
      return pw.Text(
        line,
        style: pw.TextStyle(font: fontRegular, fontSize: 12, color: PdfColor.fromHex('#1E293B')),
      );
    }

    final List<pw.Widget> inlineWidgets = [];
    int lastMatchEnd = 0;

    for (int i = 0; i < matchesList.length; i++) {
      final match = matchesList[i];

      // 1. Texto antes del acorde
      if (match.start > lastMatchEnd) {
        final textBefore = line.substring(lastMatchEnd, match.start);
        if (textBefore.isNotEmpty) {
          inlineWidgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 0.5), // Para alinear con el texto debajo del acorde
              child: pw.Text(
                textBefore,
                style: pw.TextStyle(font: fontRegular, fontSize: 12, color: PdfColor.fromHex('#1E293B')),
              ),
            ),
          );
        }
      }

      // 2. Acorde + texto bajo él
      final rawChord = match.group(1)!;
      final transposedChord = ChordTransposerService.transposeSingleChord(rawChord, transposeOffset);
      final displayedChord = Hymn.convertChordNotation(transposedChord, notation);

      final nextMatchStart = (i == matchesList.length - 1) ? line.length : matchesList[i + 1].start;
      final textUnder = line.substring(match.end, nextMatchStart);

      inlineWidgets.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              displayedChord,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 8.5,
                color: PdfColor.fromHex('#4F46E5'),
              ),
            ),
            if (textUnder.isNotEmpty)
              pw.Text(
                textUnder,
                style: pw.TextStyle(font: fontRegular, fontSize: 12, color: PdfColor.fromHex('#1E293B')),
              )
            else
              pw.SizedBox(height: 12), // Espaciador si no hay texto debajo para mantener alineación vertical
          ],
        ),
      );

      lastMatchEnd = nextMatchStart;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
      child: pw.Wrap(
        crossAxisAlignment: pw.WrapCrossAlignment.end,
        children: inlineWidgets,
      ),
    );
  }

  /// Abre la ventana nativa de compartir o imprimir el PDF
  static Future<void> shareHymnPdf(
    Hymn hymn, {
    int transposeOffset = 0,
    bool includeChords = true,
    String notation = 'spanish',
  }) async {
    final pdfBytes = await generateHymnPdf(
      hymn,
      transposeOffset: transposeOffset,
      includeChords: includeChords,
      notation: notation,
    );

    final String filename = '${hymn.collection}_${hymn.id}_${_cleanFilename(hymn.title)}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }

  static String _cleanFilename(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
  }
}
