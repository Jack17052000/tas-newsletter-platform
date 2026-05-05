import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'services/pdf_generator_service.dart';
import 'models/article_model.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const NewsletterApp());
}

class NewsletterApp extends StatelessWidget {
  const NewsletterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Newspaper Live Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1), brightness: Brightness.dark),
      ),
      themeMode: ThemeMode.system,
      home: const EditorPage(),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController contentController = TextEditingController();
  
  // Lista de imágenes introducidas por el usuario
  List<Uint8List> userImages = [];

  final Uint8List placeholderBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0B, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0x60, 0x00, 0x02, 0x00,
    0x00, 0x05, 0x00, 0x01, 0xE2, 0x26, 0x05, 0x9B, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
    0xAE, 0x42, 0x60, 0x82
  ]);

  late ValueNotifier<List<Article>> articlesNotifier;

  @override
  void initState() {
    super.initState();
    articlesNotifier = ValueNotifier<List<Article>>(_parseInputToArticles('', []));
    contentController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    contentController.dispose();
    articlesNotifier.dispose();
    super.dispose();
  }

  void _updatePreview() {
    articlesNotifier.value = _parseInputToArticles(contentController.text, userImages);
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result != null) {
        setState(() {
          for (var file in result.files) {
            if (file.bytes != null) {
              userImages.add(file.bytes!);
            }
          }
        });
        _updatePreview(); // Refrescar el PDF con las nuevas imágenes
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al elegir imagen: $e')));
    }
  }

  void _clearImages() {
    setState(() {
      userImages.clear();
    });
    _updatePreview();
  }

  List<Article> _parseInputToArticles(String text, List<Uint8List> availableImages) {
    if (text.trim().isEmpty) {
      return [
        Article(
          heading: 'Esperando contenido...',
          body: 'Ingresa texto estructurado aquí...',
          graphics: []
        )
      ];
    }

    // Dividimos SOLO por "Artículo X" para no romper el bloque si encontramos "Heading:" en medio.
    List<String> blocks = text.split(RegExp(r'(?=(?:Artículo|Article)\s*\d+)', caseSensitive: false));
    if (blocks.length == 1 || blocks.where((b) => b.trim().isNotEmpty).isEmpty) {
        blocks = [text]; // Fallback si no usan "Artículo"
    }

    List<Article> parsedArticles = [];
    int imageIndex = 0; 

    for (var block in blocks) {
      if (block.trim().isEmpty) continue;
      
      String parsedHeading = 'Noticia Principal';
      
      // Busca la etiqueta Heading y toma todo hasta que encuentre \n\n (un párrafo doble)
      final headMatch = RegExp(r'(?:Heading|Título).*?:\s*(?:>\s*)?(.*?)(?=\n\n|\nGraphic|\nVertical|\nColumn|\nCaption|\nBody)', multiLine: true, dotAll: true).firstMatch(block);
      
      if (headMatch != null && headMatch.group(1) != null && headMatch.group(1)!.trim().isNotEmpty) {
        parsedHeading = headMatch.group(1)!.trim();
      } else {
        // Fallback: Tomar la primera línea que no esté vacía
        final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (lines.isNotEmpty) {
          parsedHeading = lines.first.replaceAll(RegExp(r'Artículo \d+:\s*'), '').trim();
        }
      }

      String parsedBody = block.trim(); 
      final bodyMatch = RegExp(r'(?:Body|Cuerpo).*?:\s*(.*)', multiLine: true, dotAll: true).firstMatch(block);
      if (bodyMatch != null && bodyMatch.group(1) != null) {
        parsedBody = bodyMatch.group(1)!.trim();
      } else {
        // Si no usaron la etiqueta "Body:", tomamos el bloque completo
        parsedBody = block.trim();
      }

      int span = 1;
      VerticalPosition pos = VerticalPosition.top;
      String cap = 'Imagen segmentada automáticamente';

      if (block.toLowerCase().contains('columnspan: 2')) span = 2;
      if (block.toLowerCase().contains('columnspan: 3') || block.toLowerCase().contains('fullwidth')) span = 3;
      if (block.toLowerCase().contains('verticalposition: middle')) pos = VerticalPosition.middle;
      if (block.toLowerCase().contains('verticalposition: bottom')) pos = VerticalPosition.bottom;

      final capMatch = RegExp(r'Caption(?:\s*\([^)]*\))?:\s*(.*?)(?=\n|Body)', multiLine: true).firstMatch(block);
      if (capMatch != null && capMatch.group(1) != null) {
        cap = capMatch.group(1)!.trim();
      }

      Uint8List imageToUse = placeholderBytes;
      if (imageIndex < availableImages.length) {
        imageToUse = availableImages[imageIndex];
        imageIndex++;
      } else if (block.toLowerCase().contains('graphic') || block.toLowerCase().contains('imagen')) {
         imageIndex++; // Incrementa pero usa dummy
      }

      parsedArticles.add(Article(
        heading: parsedHeading,
        body: parsedBody,
        graphics: [
          Graphic(
            imageBytes: imageToUse,
            caption: cap,
            columnSpan: span,
            verticalPosition: pos,
          )
        ]
      ));
    }

    if (parsedArticles.isEmpty) {
      parsedArticles.add(Article(heading: 'Segmentando...', body: text, graphics: []));
    }

    return parsedArticles;
  }

  Future<void> savePdfDirectly() async {
    try {
      final pdfBytes = await PdfGeneratorService().generateA5Newspaper(articlesNotifier.value);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'newspaper_a5_$timestamp.pdf';
      final file = File('/mnt/d/Users/User/Desktop/$fileName');
      await file.writeAsBytes(pdfBytes);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Guardado como: $fileName en el Escritorio'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Newspaper Live Layout Studio', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilledButton.icon(
              onPressed: savePdfDirectly,
              icon: const Icon(Icons.download),
              label: const Text('Export PDF to Desktop'),
            ),
          )
        ],
      ),
      body: Row(
        children: [
          // PANEL IZQUIERDO: RAW EDITOR + IMAGE UPLOADER
          Container(
            width: isDesktop ? 450 : MediaQuery.of(context).size.width,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === ZONA DE SELECCIÓN DE IMÁGENES ===
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('📸 Galería de Imágenes (Ordenadas)', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Añadir'),
                          )
                        ],
                      ),
                      if (userImages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 70,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: userImages.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 70,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: MemoryImage(userImages[index]),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2, left: 2,
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.black87,
                                        child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _clearImages,
                            child: const Text('Limpiar Imágenes', style: TextStyle(fontSize: 11, color: Colors.red)),
                          ),
                        ),
                      ] else ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Ninguna imagen cargada. Se usarán cuadros fantasma grises.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        )
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                const Text('📝 Pega o Escribe el Raw Text Aquí', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text(
                  'El motor detectará automáticamente los datos y los combinará con tu galería de imágenes secuencialmente (Imagen 1 va al Artículo 1, etc.).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: contentController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // PANEL DERECHO: LIVE PDF PREVIEW
          if (isDesktop)
            Expanded(
              child: Container(
                color: Colors.grey[200],
                child: ValueListenableBuilder<List<Article>>(
                  valueListenable: articlesNotifier,
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
              ),
            ),
        ],
      ),
    );
  }
}
