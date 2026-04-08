import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/article_model.dart';

class PdfGeneratorService {
  static const double gutter = 5.0; // 5mm
  static const int totalColumns = 3;

  Future<Uint8List> generateA5Newspaper(Article article) async {
    final pdf = pw.Document();

    // Use A5 format
    final format = PdfPageFormat.a5.copyWith(
      marginLeft: 10 * PdfPageFormat.mm,
      marginRight: 10 * PdfPageFormat.mm,
      marginTop: 10 * PdfPageFormat.mm,
      marginBottom: 10 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (context) {
          return [
            // 1. Heading (Spans all columns)
            _buildHeading(article.heading),
            pw.SizedBox(height: 10),

            // 2. Content with Multi-Column flow and spanning graphics
            ..._buildContent(article, format),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeading(String text) {
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.black)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 24,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  List<pw.Widget> _buildContent(Article article, PdfPageFormat format) {
    final List<Graphic> topGraphics = article.graphics.where((g) => g.verticalPosition == VerticalPosition.top).toList();
    final List<Graphic> middleGraphics = article.graphics.where((g) => g.verticalPosition == VerticalPosition.middle).toList();
    final List<Graphic> bottomGraphics = article.graphics.where((g) => g.verticalPosition == VerticalPosition.bottom).toList();

    final List<pw.Widget> content = [];

    // 1. Top Graphics
    for (var graphic in topGraphics) {
      content.add(_buildGraphic(graphic, format, isSpanning: true));
      content.add(pw.SizedBox(height: 10));
    }

    // 2. Multi-column Body
    final paragraphs = article.body.split('\n\n');
    final List<pw.Widget> bodyWidgets = [];
    for (var p in paragraphs) {
      if (p.trim().isEmpty) continue;
      bodyWidgets.add(
        pw.Paragraph(
          text: p.trim(),
          textAlign: pw.TextAlign.justify,
          style: const pw.TextStyle(fontSize: 9),
        ),
      );
    }

    // Mix in middle graphics
    if (middleGraphics.isNotEmpty) {
      int insertAt = (bodyWidgets.length / 2).floor();
      bodyWidgets.insert(insertAt, _buildGraphic(middleGraphics.first, format, isSpanning: true));
    }

    // Distribute widgets into 3 columns manually
    final int itemsPerCol = (bodyWidgets.length / totalColumns).ceil();
    final List<List<pw.Widget>> columns = List.generate(totalColumns, (_) => []);
    
    for (int i = 0; i < bodyWidgets.length; i++) {
      int colIndex = (i / itemsPerCol).floor().clamp(0, totalColumns - 1);
      columns[colIndex].add(bodyWidgets[i]);
    }

    content.add(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: List.generate(totalColumns, (index) {
          return pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                ...columns[index],
              ],
            ),
          );
        }).expand((widget) => [widget, pw.SizedBox(width: gutter * PdfPageFormat.mm)]).toList()
          ..removeLast(), // Remove last spacer
      ),
    );

    // 3. Bottom Graphics
    for (var graphic in bottomGraphics) {
      content.add(pw.SizedBox(height: 10));
      content.add(_buildGraphic(graphic, format, isSpanning: true));
    }

    return content;
  }

  pw.Widget _buildGraphic(Graphic graphic, PdfPageFormat format, {bool isSpanning = false}) {
    final double availWidth = format.availableWidth;
    final double colWidth = (availWidth - (totalColumns - 1) * gutter * PdfPageFormat.mm) / totalColumns;
    
    final double graphicWidth = isSpanning 
        ? (colWidth * graphic.columnSpan + (graphic.columnSpan - 1) * gutter * PdfPageFormat.mm).clamp(0, availWidth)
        : colWidth;

    pw.Widget imageWidget;
    // Basic validation: Check if bytes seem like a valid PNG header or are too small
    bool isValidImage = graphic.imageBytes.length > 30 && 
                        graphic.imageBytes[0] == 0x89 && 
                        graphic.imageBytes[1] == 0x50;

    if (!isValidImage) {
      imageWidget = pw.Container(
        width: graphicWidth,
        height: 60,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey200,
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Center(
          child: pw.Text('Imagen Ilustrativa', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ),
      );
    } else {
      try {
        imageWidget = pw.Image(
          pw.MemoryImage(graphic.imageBytes),
          width: graphicWidth,
          fit: pw.BoxFit.cover,
        );
      } catch (e) {
        imageWidget = pw.Container(
          width: graphicWidth,
          height: 60,
          color: PdfColors.grey300,
          child: pw.Center(child: pw.Text('Error de carga')),
        );
      }
    }

    return pw.Container(
      width: graphicWidth,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          imageWidget,
          pw.SizedBox(height: 2),
          pw.Text(
            graphic.caption,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 7,
            ),
          ),
        ],
      ),
    );
  }
}
