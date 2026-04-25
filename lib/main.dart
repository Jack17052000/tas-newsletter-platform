import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'services/pdf_generator_service.dart';
import 'models/article_model.dart';

const Color _oxfordBlue   = Color(0xFF002147);
const Color _slateGrey    = Color(0xFF708090);
const Color _surfaceLight = Color(0xFFF0F2F5);

void main() => runApp(const NewsletterApp());

class NewsletterApp extends StatelessWidget {
  const NewsletterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tasmanian Chronicle - Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _oxfordBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: _oxfordBlue,
          onPrimary: Colors.white,
          secondary: _slateGrey,
          surface: _surfaceLight,
        ),
      ),
      home: const EditorPage(),
    );
  }
}

// ── Per-article form state ────────────────────────────────────────────────────

class _ArticleEntry {
  final TextEditingController headline = TextEditingController();
  final TextEditingController author   = TextEditingController();
  final TextEditingController body     = TextEditingController();

  void addListeners(VoidCallback fn) {
    headline.addListener(fn);
    author.addListener(fn);
    body.addListener(fn);
  }

  void dispose() {
    headline.dispose();
    author.dispose();
    body.dispose();
  }
}

// ── Editor page ───────────────────────────────────────────────────────────────

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final List<_ArticleEntry> _entries = [];
  final List<Uint8List>     _images  = [];
  late ValueNotifier<List<Article>> _articlesNotifier;
  Timer? _debounce;
  bool  _isGenerating = false;

  // 1×1 transparent PNG placeholder for articles without a photo
  static final Uint8List _placeholder = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0B, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0x60, 0x00, 0x02, 0x00,
    0x00, 0x05, 0x00, 0x01, 0xE2, 0x26, 0x05, 0x9B, 0x00, 0x00, 0x00, 0x00,
    0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  void initState() {
    super.initState();
    _articlesNotifier = ValueNotifier(_buildArticles());
    _addEntry();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final e in _entries) { e.dispose(); }
    _articlesNotifier.dispose();
    super.dispose();
  }

  // ── State helpers ───────────────────────────────────────────────────────────

  void _schedulePreviewUpdate() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _articlesNotifier.value = _buildArticles(),
    );
  }

  void _addEntry() {
    final entry = _ArticleEntry()..addListeners(_schedulePreviewUpdate);
    setState(() => _entries.add(entry));
    _schedulePreviewUpdate();
  }

  void _removeEntry(int index) {
    _entries[index].dispose();
    setState(() => _entries.removeAt(index));
    _schedulePreviewUpdate();
  }

  List<Article> _buildArticles() {
    if (_entries.isEmpty) {
      return [
        Article(
          heading: 'Esperando artículos...',
          body: 'Pulsa "Añadir Artículo" para comenzar.',
          graphics: [],
        ),
      ];
    }
    return List.generate(_entries.length, (i) {
      final e       = _entries[i];
      final heading = e.headline.text.trim().isEmpty ? 'Artículo ${i + 1}' : e.headline.text.trim();
      final body    = e.body.text.trim().isEmpty ? 'Contenido pendiente.' : e.body.text.trim();
      final image   = i < _images.length ? _images[i] : _placeholder;
      return Article(
        heading:    heading,
        body:       body,
        authorName: e.author.text.trim(),
        graphics: [
          Graphic(
            imageBytes:      image,
            caption:         heading,
            columnSpan:      1,
            verticalPosition: VerticalPosition.top,
          ),
        ],
      );
    });
  }

  // ── Image gallery actions ───────────────────────────────────────────────────

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result != null) {
        setState(() {
          for (final f in result.files) {
            if (f.bytes != null) _images.add(f.bytes!);
          }
        });
        _schedulePreviewUpdate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al elegir imagen: $e')),
        );
      }
    }
  }

  void _clearImages() {
    setState(() => _images.clear());
    _schedulePreviewUpdate();
  }

  // ── PDF generation ──────────────────────────────────────────────────────────

  Future<void> _generateAndSave() async {
    setState(() => _isGenerating = true);
    try {
      final articles  = _buildArticles();
      final pdfBytes  = await PdfGeneratorService().generateA5Newspaper(articles);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName  = 'tasmanian_chronicle_$timestamp.pdf';

      if (kIsWeb) {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      } else {
        final dir  = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF guardado: ${file.path}'),
              backgroundColor: _oxfordBlue,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: _surfaceLight,
      appBar: _buildAppBar(),
      body: isDesktop
          ? Row(children: [
              SizedBox(width: 480, child: _buildFormPanel()),
              Expanded(child: _buildPreviewPanel()),
            ])
          : _buildFormPanel(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _addEntry,
        backgroundColor: _oxfordBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Añadir Artículo'),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _oxfordBlue,
      foregroundColor: Colors.white,
      elevation: 2,
      title: const Text(
        'Tasmanian Chronicle — Editor',
        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: FilledButton.icon(
            onPressed: _isGenerating ? null : _generateAndSave,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _oxfordBlue,
              disabledBackgroundColor: Colors.white60,
            ),
            icon: _isGenerating
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_oxfordBlue),
                    ),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(_isGenerating ? 'Generando...' : 'Generar Publicación'),
          ),
        ),
      ],
    );
  }

  // ── Left form panel ─────────────────────────────────────────────────────────

  Widget _buildFormPanel() {
    return Container(
      color: _surfaceLight,
      child: Column(
        children: [
          _buildImageGallery(),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined, size: 64, color: _slateGrey.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'Pulsa "Añadir Artículo" para comenzar',
                          style: TextStyle(color: _slateGrey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) => _buildArticleCard(i),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Image gallery strip ─────────────────────────────────────────────────────

  Widget _buildImageGallery() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: _oxfordBlue.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: _slateGrey.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 15, color: _oxfordBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Galería de Imágenes — asignadas por orden de artículo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: _oxfordBlue,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate, size: 15),
                label: const Text('Añadir', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: _oxfordBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          _images[i],
                          width: 60, height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2, left: 2,
                        child: Container(
                          width: 17, height: 17,
                          decoration: BoxDecoration(
                            color: _oxfordBlue,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearImages,
                style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                child: const Text('Limpiar imágenes', style: TextStyle(fontSize: 11)),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Sin imágenes cargadas. El PDF usará cuadros fantasma.',
                style: TextStyle(fontSize: 11, color: _slateGrey, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // ── Article card ─────────────────────────────────────────────────────────────

  Widget _buildArticleCard(int index) {
    final entry = _entries[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: _oxfordBlue, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: badge + delete
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _oxfordBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Artículo ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (_entries.length > 1)
                  IconButton(
                    onPressed: () => _removeEntry(index),
                    icon: const Icon(Icons.delete_outline, size: 19),
                    tooltip: 'Eliminar artículo',
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: entry.headline,
              label: 'Titular',
              hint: 'Escribe el titular de la noticia...',
              icon: Icons.title,
            ),
            const SizedBox(height: 10),

            _buildField(
              controller: entry.author,
              label: 'Autor',
              hint: 'Nombre del periodista o redactor',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 10),

            _buildField(
              controller: entry.body,
              label: 'Cuerpo de la noticia',
              hint: 'Escribe o pega el contenido. Separa párrafos con una línea en blanco.',
              icon: Icons.article_outlined,
              minLines: 4,
              maxLines: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: _slateGrey.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, size: 17, color: _slateGrey),
        filled: true,
        fillColor: _surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _slateGrey.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _slateGrey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _oxfordBlue, width: 2),
        ),
        labelStyle: TextStyle(color: _slateGrey, fontSize: 12),
        floatingLabelStyle: const TextStyle(color: _oxfordBlue, fontSize: 12),
      ),
    );
  }

  // ── Right preview panel ─────────────────────────────────────────────────────

  Widget _buildPreviewPanel() {
    return Container(
      color: const Color(0xFFDDE1E7),
      child: ValueListenableBuilder<List<Article>>(
        valueListenable: _articlesNotifier,
        builder: (context, articles, _) {
          return PdfPreview(
            build: (format) => PdfGeneratorService().generateA5Newspaper(articles),
            useActions: false,
            allowPrinting: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
            initialPageFormat: PdfPageFormat.a5,
            pdfFileName: 'preview.pdf',
          );
        },
      ),
    );
  }
}
