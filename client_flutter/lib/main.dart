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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // Indigo
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
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
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  bool isLoading = false;
  String statusMessage = '';

  Future<void> generatePdf() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete title and content.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF generated successfully!'), 
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
    final isDesktop = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text('Newsletter Builder', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Row(
        children: [
          // Sidebar for Desktop
          if (isDesktop)
            Container(
              width: 280,
              color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mark_email_read_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Newsletter\nStudio',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'Design and generate premium newsletters seamlessly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        height: 1.5,
                      ),
                    ),
                  )
                ],
              ),
            ),
          
          // Main Editor Area
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 40.0 : 20.0),
                    child: Card(
                      elevation: isDesktop ? 4 : 0,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: isDesktop ? BorderSide.none : BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      color: isDesktop ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: EdgeInsets.all(isDesktop ? 40.0 : 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isDesktop) ...[
                              Text(
                                'Create New Campaign',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                            
                            // Title Field
                            TextField(
                              controller: titleController,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                labelText: 'Newsletter Title',
                                prefixIcon: const Icon(Icons.title_rounded),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Content Field
                            Expanded(
                              child: TextField(
                                controller: contentController,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                decoration: InputDecoration(
                                  labelText: 'Newsletter Content (Markdown supported)',
                                  alignLabelWithHint: true,
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton.icon(
                                onPressed: isLoading ? null : generatePdf,
                                icon: isLoading 
                                    ? SizedBox(
                                        width: 20, 
                                        height: 20, 
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary)
                                      )
                                    : const Icon(Icons.auto_awesome),
                                label: Text(
                                  isLoading ? 'Generating PDF...' : 'Generate Newsletter',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            if (statusMessage.isNotEmpty && !isLoading) ...[
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  statusMessage,
                                  style: TextStyle(
                                    color: statusMessage.contains('Error') || statusMessage.contains('Failed') 
                                      ? Colors.red 
                                      : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
