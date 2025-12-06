import 'dart:typed_data';
import 'dart:ui_web' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:universal_html/html.dart' as html;

class FilePreviewPage extends StatefulWidget {
  final String fileUrl;
  final String fileName;

  const FilePreviewPage({
    super.key,
    required this.fileUrl,
    required this.fileName,
  });

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  bool loading = true;
  Uint8List? fileBytes;
  String? textContent;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final response = await http.get(Uri.parse(widget.fileUrl));
      final bytes = response.bodyBytes;

      setState(() => fileBytes = bytes);

      final lower = widget.fileName.toLowerCase();

      if (lower.endsWith(".txt") || lower.endsWith(".csv")) {
        textContent = String.fromCharCodes(bytes);
      }

      setState(() => loading = false);

    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading file: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _buildPreview(),
    );
  }

  Widget _buildPreview() {
    final name = widget.fileName.toLowerCase();
    final bytes = fileBytes!;

    // PDF VIEWER (cross-platform)
    if (name.endsWith(".pdf")) {
      return _buildPdfViewer(bytes);
    }

    // IMAGE VIEWER
    if (name.endsWith(".jpg") ||
        name.endsWith(".jpeg") ||
        name.endsWith(".png")) {
      return Center(child: Image.memory(bytes, fit: BoxFit.contain));
    }

    // TEXT VIEWER
    if (textContent != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(textContent!, style: const TextStyle(fontSize: 16)),
      );
    }

    return const Center(child: Text("Unsupported file type"));
  }


  Widget _buildPdfViewer(Uint8List bytes) {
    if (kIsWeb) {
      return _buildPdfWebViewer(bytes);
    } else {
      return _buildPdfMobileDesktopViewer(bytes);
    }
  }

  // PDF VIEW - WEB VERSION (HTML iframe)
  Widget _buildPdfWebViewer(Uint8List bytes) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Register the viewType dynamically
    // Each iframe must have a unique id
    final viewId = "pdf-viewer-${DateTime.now().millisecondsSinceEpoch}";

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewId,
          (int _) {
        return html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = "100%"
          ..style.height = "100%";
      },
    );

    return HtmlElementView(
      viewType: viewId,
    );
  }

  // PDF VIEW - MOBILE & DESKTOP VERSION
  Widget _buildPdfMobileDesktopViewer(Uint8List bytes) {
    return PDFView(
      pdfData: bytes,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
    );
  }
}
