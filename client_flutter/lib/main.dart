import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'services/api_service.dart';

void main() {
  runApp(const NewsletterApp());
}

class NewsletterApp extends StatelessWidget {
  const NewsletterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Newsletter Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
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
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  bool isLoading = false;
  String statusMessage = '';

  Future<void> generatePdf() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      setState(() {
        statusMessage = 'Please complete title and content.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      statusMessage = 'Generating PDF...';
    });

    try {
      final Uint8List? pdfBytes =
          await ApiService.generateNewsletter(title, content);

      if (pdfBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/newsletter.pdf';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        await OpenFilex.open(filePath);

        setState(() {
          statusMessage = 'PDF generated successfully.';
        });
      } else {
        setState(() {
          statusMessage = 'Failed to generate PDF.';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Newsletter Editor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: contentController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : generatePdf,
              child: Text(isLoading ? 'Generating...' : 'Generate Newsletter'),
            ),
            const SizedBox(height: 12),
            Text(statusMessage),
          ],
        ),
      ),
    );
  }
}
