import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/article_model.dart';

class PdfGeneratorService {
  static const double margin = 12.0;
  static const double gutter = 6.0; 
  static const int totalColumns = 3;

  String _sanitizeText(String text) {
    // Las fuentes Base 14 (Times) no soportan guiones largos ni comillas curvas
    return text
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('…', '...');
  }

  Future<Uint8List> generateA5Newspaper(List<Article> articles) async {
    final pdf = pw.Document();

    final format = PdfPageFormat.a5.copyWith(
      marginLeft: margin * PdfPageFormat.mm,
      marginRight: margin * PdfPageFormat.mm,
      marginTop: margin * PdfPageFormat.mm,
      marginBottom: margin * PdfPageFormat.mm,
    );

    bool isFirstPage = true;

    for (var article in articles) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (context) {
            final double availWidth = format.availableWidth;
            final double singleColWidth = (availWidth - (totalColumns - 1) * gutter * PdfPageFormat.mm) / totalColumns;

            final pageContent = pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // MASTER HEADER SOLO PÁGINA 1
                if (isFirstPage) ...[
                  pw.Center(
                    child: pw.Text(
                      'THE TASMANIAN CHRONICLE', 
                      style: pw.TextStyle(font: pw.Font.timesBold(), fontSize: 32, letterSpacing: 1.5)
                    ),
                  ),
                  pw.Container(
                    width: double.infinity,
                    margin: const pw.EdgeInsets.only(top: 4, bottom: 12),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(width: 1), bottom: pw.BorderSide(width: 3))
                    ),
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Vol. 1 - Edición Especial', style: pw.TextStyle(font: pw.Font.timesItalic(), fontSize: 8)),
                        pw.Text('Periódico 100% Local', style: pw.TextStyle(font: pw.Font.times(), fontSize: 8)),
                      ]
                    )
                  ),
                ],

                // HEADER DEL ARTÍCULO
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: isFirstPage ? pw.BorderSide.none : const pw.BorderSide(width: 3, color: PdfColors.black),
                      bottom: const pw.BorderSide(width: 1, color: PdfColors.black),
                    ),
                  ),
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      _sanitizeText(article.heading), 
                      style: pw.TextStyle(
                        font: pw.Font.timesBold(),
                        fontSize: isFirstPage ? 34 : 26, 
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ),

                // == GRÁFICO PORTADA ABSOLUTO PARA PÁGINA 1 ==
                // Si es la página 1 y hay imagen, se fuerza a que cubra todo el ancho (Portada principal)
                if (isFirstPage && article.graphics.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: _buildGraphic(article.graphics.first, singleColWidth, isSpanning: true, trueSpan: totalColumns, maxHeight: 180),
                  ),

                // GRÁFICOS SUPERIORES (Páginas > 1)
                if (!isFirstPage)
                  ..._buildSpanningGraphics(
                    article.graphics.where((g) => g.columnSpan > 1 && g.verticalPosition == VerticalPosition.top),
                    format,
                    isBottom: false
                  ),

                // TEXTO BALANCEADO (Excluyendo imagen en Página 1 porque ya se usó como Portada)
                pw.Expanded(
                  child: _buildBalancedMulticolumnContent(article, format, renderGraphics: !isFirstPage),
                ),

                // GRÁFICOS INFERIORES (Páginas > 1)
                if (!isFirstPage)
                  ..._buildSpanningGraphics(
                    article.graphics.where((g) => g.columnSpan > 1 && g.verticalPosition == VerticalPosition.bottom),
                    format,
                    isBottom: true
                  ),
              ],
            );
            
            isFirstPage = false;
            return pageContent;
          },
        ),
      );
    }

    return pdf.save();
  }

  List<pw.Widget> _buildSpanningGraphics(Iterable<Graphic> graphics, PdfPageFormat format, {bool isBottom = false}) {
    List<pw.Widget> widgets = [];
    final double colWidth = (format.availableWidth - (totalColumns - 1) * gutter * PdfPageFormat.mm) / totalColumns;
    for (var g in graphics) {
      if (isBottom) widgets.add(pw.SizedBox(height: 10));
      widgets.add(_buildGraphic(g, colWidth, isSpanning: true));
      if (!isBottom) widgets.add(pw.SizedBox(height: 10));
    }
    return widgets;
  }

  pw.Widget _buildBalancedMulticolumnContent(Article article, PdfPageFormat format, {bool renderGraphics = true}) {
    final double availWidth = format.availableWidth;
    final double colWidth = (availWidth - (totalColumns - 1) * gutter * PdfPageFormat.mm) / totalColumns;

    final graphics = article.graphics;
    final paragraphs = article.body.split('\n\n').where((p) => p.trim().isNotEmpty).toList();

    List<List<pw.Widget>> columns = List.generate(totalColumns, (_) => []);
    List<double> columnHeights = List.filled(totalColumns, 0.0);

    List<dynamic> itemsFlow = [];
    List<Graphic> inlineGraphics = renderGraphics ? graphics.where((g) => g.columnSpan <= 1).toList() : [];
    
    int gIndex = 0;
    if (paragraphs.isNotEmpty) {
      itemsFlow.add("FIRST_PARAGRAPH:" + paragraphs[0]);
    }

    for (int i = 1; i < paragraphs.length; i++) {
        itemsFlow.add(paragraphs[i]);
        // Insertar imagen en el medio del flujo si corresponde
        if (gIndex < inlineGraphics.length && i == paragraphs.length ~/ 2) {
           itemsFlow.add(inlineGraphics[gIndex]);
           gIndex++;
        }
    }
    while (gIndex < inlineGraphics.length) {
        itemsFlow.add(inlineGraphics[gIndex]);
        gIndex++;
    }

    for (var item in itemsFlow) {
      int targetColIndex = 0;
      double minHeight = double.maxFinite;
      for (int i = 0; i < totalColumns; i++) {
        if (columnHeights[i] < minHeight) {
          minHeight = columnHeights[i];
          targetColIndex = i;
        }
      }

      const double charHeightRatio = 0.38; 
      if (item is String) {
        bool isFirst = item.startsWith("FIRST_PARAGRAPH:");
        String textToRender = _sanitizeText(isFirst ? item.replaceFirst("FIRST_PARAGRAPH:", "") : item);

        columns[targetColIndex].add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                style: pw.TextStyle(
                  font: pw.Font.times(), 
                  fontSize: 9,
                  lineSpacing: 1.2,
                ),
                children: [
                  if (isFirst) 
                    pw.TextSpan(
                      text: "POR LA REDACCIÓN - ", 
                      style: pw.TextStyle(font: pw.Font.timesBold())
                    ),
                  pw.TextSpan(text: textToRender.trim()),
                ]
              )
            ),
          )
        );
        columnHeights[targetColIndex] += textToRender.length * charHeightRatio;
      } else if (item is Graphic) {
        columns[targetColIndex].add(
           pw.Padding(
             padding: const pw.EdgeInsets.only(bottom: 6, top: 4),
             child: _buildGraphic(item, colWidth, isSpanning: false, maxHeight: 120)
           )
        );
        columnHeights[targetColIndex] += colWidth * 0.75 + 15; 
      }
    }

    final List<pw.Widget> rowChildren = [];
    for (int i = 0; i < totalColumns; i++) {
      rowChildren.add(
        pw.Expanded(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: columns[i],
          ),
        ),
      );
      
      if (i < totalColumns - 1) {
        rowChildren.add(pw.SizedBox(width: gutter * PdfPageFormat.mm));
      }
    }

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.5, color: PdfColors.black) 
        )
      ),
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start, 
        children: rowChildren,
      ),
    );
  }

  pw.Widget _buildGraphic(Graphic graphic, double singleColWidth, {bool isSpanning = false, int? trueSpan, double? maxHeight}) {
    final int spanToUse = trueSpan ?? graphic.columnSpan;
    final double graphicWidth = isSpanning 
        ? (singleColWidth * spanToUse + (spanToUse - 1) * gutter * PdfPageFormat.mm)
        : singleColWidth;

    pw.Widget imageWidget;
    try {
      // Remover chequeo manual de bits para soportar perfectamente JPEG y PNG
      if (graphic.imageBytes.length > 50) {
        imageWidget = pw.Image(
          pw.MemoryImage(graphic.imageBytes),
          width: graphicWidth,
          height: maxHeight, 
          fit: pw.BoxFit.contain, // Previene que imágenes verticales muy largas rompan la página
        );
      } else {
        imageWidget = pw.Container(width: graphicWidth, height: 60, color: PdfColors.grey200);
      }
    } catch (e) {
      imageWidget = pw.Container(
        width: graphicWidth, height: 60, color: PdfColors.grey300,
        child: pw.Center(child: pw.Text('NO IMAGE')),
      );
    }

    return pw.Container(
      width: graphicWidth,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
            child: imageWidget, 
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            _sanitizeText(graphic.caption.toUpperCase()), 
            textAlign: pw.TextAlign.left,
            style: pw.TextStyle(
              font: pw.Font.timesBold(), 
              fontSize: 6.5, 
              color: PdfColors.grey900
            ),
          ),
        ],
      ),
    );
  }
}
