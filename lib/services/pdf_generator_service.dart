import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/article_model.dart';

class _Fonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;

  const _Fonts({
    required this.regular,
    required this.bold,
    required this.italic,
  });
}

class PdfGeneratorService {
  static const double margin      = 12.0;
  static const double gutterPt    = 15.0; // PDF points between columns
  static const int    totalColumns = 4;

  // ── Body font geometry (LibreBaskerville 10pt) ─────────────────────────────
  static const double _bodyFontSize      = 10.0;
  static const double _avgCharWidthRatio = 0.52; // char width / font-size
  static const double _lineHeightRatio   = 1.6;  // line height / font-size

  // ── Inline image geometry ─────────────────────────────────────────────────
  static const double _inlineImageMaxHeight = 120.0;
  static const double _captionFontSize      = 6.5;
  static const double _captionLineHeight    = _captionFontSize * 1.5; // ~10pt
  static const double _graphicPaddingTotal  = 6 + 4 + 3;             // top + bottom + gap

  // ── Masthead ──────────────────────────────────────────────────────────────
  static const String _publicationTitle   = 'THE TASMANIAN CHRONICLE';
  static const String _publicationTagline = 'Periódico Independiente de Hobart';

  static String _formattedDate() {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    const days = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]} de ${now.year}';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════

  Future<Uint8List> generateA5Newspaper(List<Article> articles) async {
    final fonts = _Fonts(
      regular: await PdfGoogleFonts.libreBaskervilleRegular(),
      bold:    await PdfGoogleFonts.libreBaskervilleBold(),
      italic:  await PdfGoogleFonts.libreBaskervilleItalic(),
    );

    final pdf = pw.Document();

    final format = PdfPageFormat.a5.copyWith(
      marginLeft:   margin * PdfPageFormat.mm,
      marginRight:  margin * PdfPageFormat.mm,
      marginTop:    margin * PdfPageFormat.mm,
      marginBottom: margin * PdfPageFormat.mm,
    );

    final int totalPages = articles.length;
    int pageNum = 0;

    for (final article in articles) {
      pageNum++;
      final int thisPage    = pageNum;
      final bool isFirstPage = thisPage == 1;

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (context) {
            final double availWidth = format.availableWidth;
            final double singleColWidth =
                (availWidth - (totalColumns - 1) * gutterPt) /
                totalColumns;

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── MASTHEAD (página 1) ─────────────────────────────────────
                if (isFirstPage)
                  _buildMasthead(fonts),

                // ── TÍTULO DEL ARTÍCULO ─────────────────────────────────────
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: isFirstPage
                          ? pw.BorderSide.none
                          : const pw.BorderSide(width: 3, color: PdfColors.black),
                      bottom: const pw.BorderSide(width: 1, color: PdfColors.black),
                    ),
                  ),
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      article.heading,
                      style: pw.TextStyle(
                        font:     fonts.bold,
                        fontSize: isFirstPage ? 28 : 24,
                        color:    PdfColors.black,
                      ),
                    ),
                  ),
                ),

                // ── IMAGEN PORTADA full-width (sólo página 1) ───────────────
                if (isFirstPage && article.graphics.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: _buildGraphic(
                      article.graphics.first,
                      singleColWidth,
                      fonts:      fonts,
                      isSpanning: true,
                      trueSpan:   totalColumns,
                      maxHeight:  180,
                    ),
                  ),

                // ── GRÁFICOS SUPERIORES (páginas > 1) ──────────────────────
                if (!isFirstPage)
                  ..._buildSpanningGraphics(
                    article.graphics.where(
                      (g) => g.columnSpan > 1 &&
                             g.verticalPosition == VerticalPosition.top,
                    ),
                    format,
                    fonts:    fonts,
                    isBottom: false,
                  ),

                // ── CONTENIDO MULTI-COLUMNA BALANCEADO ──────────────────────
                pw.Expanded(
                  child: _buildBalancedMulticolumnContent(
                    article,
                    format,
                    fonts:          fonts,
                    renderGraphics: !isFirstPage,
                  ),
                ),

                // ── GRÁFICOS INFERIORES (páginas > 1) ──────────────────────
                if (!isFirstPage)
                  ..._buildSpanningGraphics(
                    article.graphics.where(
                      (g) => g.columnSpan > 1 &&
                             g.verticalPosition == VerticalPosition.bottom,
                    ),
                    format,
                    fonts:    fonts,
                    isBottom: true,
                  ),

                // ── FOOTER: número de página ────────────────────────────────
                _buildFooter(thisPage, totalPages, fonts),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MASTHEAD
  // ══════════════════════════════════════════════════════════════════════════

  pw.Widget _buildMasthead(_Fonts fonts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Línea gruesa superior
        pw.Container(
          width: double.infinity,
          height: 3,
          color: PdfColors.black,
        ),
        pw.SizedBox(height: 5),

        // Título principal
        pw.Text(
          _publicationTitle,
          style: pw.TextStyle(
            font:          fonts.bold,
            fontSize:      30,
            letterSpacing: 2.0,
          ),
          textAlign: pw.TextAlign.center,
        ),

        pw.SizedBox(height: 5),
        // Línea gruesa inferior del título
        pw.Container(
          width: double.infinity,
          height: 3,
          color: PdfColors.black,
        ),

        // Barra de fecha y edición
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _formattedDate(),
                style: pw.TextStyle(font: fonts.italic, fontSize: 7.5),
              ),
              pw.Text(
                _publicationTagline,
                style: pw.TextStyle(font: fonts.italic, fontSize: 7.5),
              ),
              pw.Text(
                'Vol. 1 — Nº 1',
                style: pw.TextStyle(font: fonts.italic, fontSize: 7.5),
              ),
            ],
          ),
        ),

        // Línea fina separadora
        pw.Container(
          width: double.infinity,
          height: 0.5,
          color: PdfColors.black,
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FOOTER
  // ══════════════════════════════════════════════════════════════════════════

  pw.Widget _buildFooter(int pageNum, int totalPages, _Fonts fonts) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
        ),
      ),
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _publicationTitle,
            style: pw.TextStyle(
              font:     fonts.italic,
              fontSize: 6.5,
              color:    PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Página $pageNum de $totalPages',
            style: pw.TextStyle(
              font:     fonts.italic,
              fontSize: 6.5,
              color:    PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPANNING GRAPHICS
  // ══════════════════════════════════════════════════════════════════════════

  List<pw.Widget> _buildSpanningGraphics(
    Iterable<Graphic> graphics,
    PdfPageFormat format, {
    required _Fonts fonts,
    bool isBottom = false,
  }) {
    final List<pw.Widget> widgets = [];
    final double colWidth =
        (format.availableWidth - (totalColumns - 1) * gutterPt) /
        totalColumns;
    for (final g in graphics) {
      if (isBottom)  widgets.add(pw.SizedBox(height: 10));
      widgets.add(_buildGraphic(g, colWidth, fonts: fonts, isSpanning: true));
      if (!isBottom) widgets.add(pw.SizedBox(height: 10));
    }
    return widgets;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BALANCED MULTI-COLUMN CONTENT
  // ══════════════════════════════════════════════════════════════════════════

  pw.Widget _buildBalancedMulticolumnContent(
    Article article,
    PdfPageFormat format, {
    required _Fonts fonts,
    bool renderGraphics = true,
  }) {
    final double availWidth = format.availableWidth;
    final double colWidth =
        (availWidth - (totalColumns - 1) * gutterPt) /
        totalColumns;

    // Geometric height estimator:
    //   lines  = ⌈(chars × avgCharWidth) / colWidth⌉
    //   height = lines × lineHeight + bottomPadding
    final double charsPerLine = colWidth / (_bodyFontSize * _avgCharWidthRatio);
    final double lineHeightPt = _bodyFontSize * _lineHeightRatio;

    double estimateTextHeight(String text) {
      final double lines = (text.trim().length / charsPerLine).ceilToDouble();
      return lines * lineHeightPt + 6.0;
    }

    // Precise image height: actual maxHeight cap + caption + padding
    // Replaces the old opaque `colWidth * 0.75 + 15` heuristic.
    double estimateImageHeight(double imageMaxHeight) =>
        imageMaxHeight + _captionLineHeight + _graphicPaddingTotal;

    final paragraphs =
        article.body.split('\n\n').where((p) => p.trim().isNotEmpty).toList();

    final List<List<pw.Widget>> columns = List.generate(totalColumns, (_) => []);
    final List<double>          columnHeights = List.filled(totalColumns, 0.0);

    final List<Graphic> inlineGraphics = renderGraphics
        ? article.graphics.where((g) => g.columnSpan <= 1).toList()
        : [];

    // Build the item flow: paragraphs + inline images at the midpoint
    final List<dynamic> itemsFlow = [];
    if (paragraphs.isNotEmpty) {
      itemsFlow.add('FIRST_PARAGRAPH:${paragraphs[0]}');
    }
    int gIndex = 0;
    for (int i = 1; i < paragraphs.length; i++) {
      itemsFlow.add(paragraphs[i]);
      if (gIndex < inlineGraphics.length && i == paragraphs.length ~/ 2) {
        itemsFlow.add(inlineGraphics[gIndex++]);
      }
    }
    while (gIndex < inlineGraphics.length) {
      itemsFlow.add(inlineGraphics[gIndex++]);
    }

    for (final item in itemsFlow) {
      // Greedy: place in the shortest column
      int    targetCol = 0;
      double minH      = double.maxFinite;
      for (int i = 0; i < totalColumns; i++) {
        if (columnHeights[i] < minH) {
          minH      = columnHeights[i];
          targetCol = i;
        }
      }

      if (item is String) {
        final bool   isFirst = item.startsWith('FIRST_PARAGRAPH:');
        final String text    =
            isFirst ? item.replaceFirst('FIRST_PARAGRAPH:', '') : item;

        columns[targetCol].add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.RichText(
              textAlign: pw.TextAlign.justify,
              text: pw.TextSpan(
                style: pw.TextStyle(
                  font:        fonts.regular,
                  fontSize:    _bodyFontSize,
                  lineSpacing: 1.2,
                ),
                children: [
                  if (isFirst)
                    pw.TextSpan(
                      text: article.authorName.isNotEmpty
                          ? 'POR ${article.authorName.toUpperCase()} — '
                          : 'POR LA REDACCIÓN — ',
                      style: pw.TextStyle(font: fonts.bold),
                    ),
                  pw.TextSpan(text: text.trim()),
                ],
              ),
            ),
          ),
        );
        columnHeights[targetCol] += estimateTextHeight(text);

      } else if (item is Graphic) {
        const double imageMaxH = _inlineImageMaxHeight;
        columns[targetCol].add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6, top: 4),
            child: _buildGraphic(
              item,
              colWidth,
              fonts:     fonts,
              maxHeight: imageMaxH,
            ),
          ),
        );
        // Subtract the REAL geometric footprint of the image from column budget
        columnHeights[targetCol] += estimateImageHeight(imageMaxH);
      }
    }

    // Assemble the 4-column row with thin column rules
    final List<pw.Widget> rowChildren = [];
    for (int i = 0; i < totalColumns; i++) {
      rowChildren.add(
        pw.Expanded(
          child: pw.Column(
            mainAxisAlignment:  pw.MainAxisAlignment.start,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: columns[i],
          ),
        ),
      );
      if (i < totalColumns - 1) {
        // Half-gutter + 0.3pt rule + half-gutter
        final double half = (gutterPt - 0.3) / 2;
        rowChildren.add(pw.SizedBox(width: half));
        rowChildren.add(
          pw.Container(
            width: 0.3,
            color: PdfColors.grey400,
          ),
        );
        rowChildren.add(pw.SizedBox(width: half));
      }
    }

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.5, color: PdfColors.black),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rowChildren,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GRAPHIC RENDERER
  // ══════════════════════════════════════════════════════════════════════════

  pw.Widget _buildGraphic(
    Graphic graphic,
    double singleColWidth, {
    required _Fonts fonts,
    bool    isSpanning = false,
    int?    trueSpan,
    double? maxHeight,
  }) {
    final int    spanToUse    = trueSpan ?? graphic.columnSpan;
    final double graphicWidth = isSpanning
        ? singleColWidth * spanToUse + (spanToUse - 1) * gutterPt
        : singleColWidth;

    pw.Widget imageWidget;
    try {
      imageWidget = graphic.imageBytes.length > 50
          ? pw.Image(
              pw.MemoryImage(graphic.imageBytes),
              width:    graphicWidth,
              height:   maxHeight,
              fit:      pw.BoxFit.contain,
            )
          : pw.Container(
              width:  graphicWidth,
              height: 60,
              color:  PdfColors.grey200,
            );
    } catch (_) {
      imageWidget = pw.Container(
        width:  graphicWidth,
        height: 60,
        color:  PdfColors.grey300,
        child:  pw.Center(child: pw.Text('NO IMAGE')),
      );
    }

    return pw.Container(
      width: graphicWidth,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: imageWidget,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            graphic.caption.toUpperCase(),
            textAlign: pw.TextAlign.left,
            style: pw.TextStyle(
              font:     fonts.bold,
              fontSize: _captionFontSize,
              color:    PdfColors.grey900,
            ),
          ),
        ],
      ),
    );
  }
}
