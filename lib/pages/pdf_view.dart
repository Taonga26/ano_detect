import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PdfPreviewPage extends StatefulWidget {
  final Uint8List anomalyImage;
  final Uint8List pieImage;
  final List<Map<String, dynamic>> anomaliesTable;
  final Map<String, dynamic> pieData;

  const PdfPreviewPage({
    super.key,
    required this.anomalyImage,
    required this.pieImage,
    required this.anomaliesTable,
    required this.pieData,
  });

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  bool isSaving = false;
  final supabase = Supabase.instance.client;

  pw.Document _buildPdf() {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text("📊 Anomaly Detection Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Text("🚨 Anomaly Chart", style: pw.TextStyle(fontSize: 16)),
          pw.Image(pw.MemoryImage(widget.anomalyImage), width: 400, height: 250),
          pw.SizedBox(height: 20),
          pw.Text("🥧 Pie Chart Summary", style: pw.TextStyle(fontSize: 16)),
          pw.Image(pw.MemoryImage(widget.pieImage), width: 300, height: 200),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ["Category", "Value"],
            data: widget.pieData.entries.map((e) => [e.key, e.value.toString()]).toList(),
          ),
          pw.SizedBox(height: 20),
          if (widget.anomaliesTable.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("📋 Detected Anomalies Table", style: pw.TextStyle(fontSize: 16)),
                pw.Table.fromTextArray(
                  headers: widget.anomaliesTable.first.keys.toList(),
                  data: widget.anomaliesTable.map((row) => row.values.map((v) => v.toString()).toList()).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ],
            ),
        ],
      ),
    );
    return pdf;
  }

  Future<void> _saveAndUploadPdf() async {
    setState(() => isSaving = true);

    try {
      // 1️⃣ Build PDF
      final pdfDoc = _buildPdf();
      final bytes = await pdfDoc.save(); // returns Uint8List

      // 2️⃣ Save locally
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/anomaly_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);

      // 3️⃣ Upload to Supabase Storage
      final fileName = file.uri.pathSegments.last;
      await supabase.storage.from('reports').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(contentType: 'application/pdf'),
      );

      final publicUrl = supabase.storage.from('reports').getPublicUrl(fileName);

      // 4️⃣ Insert metadata into pdf_reports (include user_id!)
      await supabase.from('pdf_reports').insert({
        'file_name': fileName,
        'url': publicUrl,
        'user_id': supabase.auth.currentUser!.id, // REQUIRED for RLS
        'created_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PDF saved & uploaded!')));

      // 5️⃣ Open PDF locally
      await OpenFile.open(file.path);

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    setState(() => isSaving = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Preview')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            const Text('PDF ready to generate & upload', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isSaving ? null : _saveAndUploadPdf,
              icon: const Icon(Icons.save),
              label: Text(isSaving ? 'Saving...' : 'Save & Upload PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
