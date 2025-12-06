import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'anomal_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isLoading = false;
  List<Map<String, dynamic>> anomalies = [];
  List<Map<String, dynamic>> edaData = [];
  Map<String, dynamic> pieData = {};

  final GlobalKey pieKey = GlobalKey();
  final GlobalKey anomalyChartKey = GlobalKey();
  final Map<String, GlobalKey> edaChartKeys = {
    'Open': GlobalKey(),
    'High': GlobalKey(),
    'Low': GlobalKey(),
    'Close': GlobalKey(),
    'Volume': GlobalKey(),
  };

  
  // CSV UPLOAD
  Future<void> uploadCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;

    setState(() => isLoading = true);

    try {
      final uri = Uri.parse('http://127.0.0.1:8000/api/v1/predict');
      var request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        final fileBytes = result.files.single.bytes!;
        final fileName = result.files.single.name;
        request.files.add(
          http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
        );
      } else {
        final filePath = result.files.single.path!;
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);

        setState(() {
          anomalies = List<Map<String, dynamic>>.from(data['anomalies'] ?? []).reversed.toList();
          edaData = List<Map<String, dynamic>>.from(data['eda'] ?? []).reversed.toList();
          pieData = Map<String, dynamic>.from(data['pie'] ?? {});
          isLoading = false;
        });
      } else {
        throw Exception('Failed to upload CSV');
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

 
  // TABLE VIEW FOR ANOMALIES
  Widget buildAnomaliesTable() {
    if (anomalies.isEmpty) return const Text("No anomalies detected");

    final columns = anomalies.first.keys.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.red.shade100),
        columns: columns
            .map((col) => DataColumn(
          label:
          Text(col, style: const TextStyle(fontWeight: FontWeight.bold)),
        ))
            .toList(),
        rows: anomalies.map((row) {
          return DataRow(
            cells: columns
                .map((col) => DataCell(Text(row[col]?.toString() ?? '')))
                .toList(),
          );
        }).toList(),
      ),
    );
  }

 
  // PIE CHART
  Widget buildPieChart() {
    if (pieData.isEmpty) return const Text("No pie data available");

    final anomalyPercent = (pieData['percentages']?['anomalies'] ?? 0.0).toDouble();
    final normalPercent = (pieData['percentages']?['normal'] ?? 100.0).toDouble();
    final anomalyPoints = pieData['anomalies'] ?? 0;
    final totalPoints = pieData['total_points'] ?? 0;

    return RepaintBoundary(
      key: pieKey,
      child: Column(
        children: [
          Text('Anomalies detected: $anomalyPoints'),
          Text('Total entries: $totalPoints'),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: anomalyPercent,
                    color: Colors.redAccent,
                    title: '${anomalyPercent.toStringAsFixed(1)}%',
                    titleStyle: const TextStyle(color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: normalPercent,
                    color: Colors.green,
                    title: '${normalPercent.toStringAsFixed(1)}%',
                    titleStyle: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // LINE CHART
  Widget buildLineChart(
      String title,
      List<Map<String, dynamic>> data,
      String dataKey,
      Color color,
      String xLabel,
      String yLabel,
      ) {
    if (edaData.isEmpty) return const Text("No data available");

    List<String> titles = data.map((d) {
      final rawDateString = d['Date']?.toString() ?? '';
      if (rawDateString.isEmpty) return '';

    
      try {
        final dateTime = HttpDate.parse(rawDateString);
        return DateFormat("dd/MM/yyyy").format(dateTime); 
      } catch (e) {
        // If HttpDate fails, fall back to the standard Dart parser
        final dateTime = DateTime.tryParse(rawDateString);
        if (dateTime != null) {
          return DateFormat("dd/MM/yyyy").format(dateTime);
        }
      }

      return rawDateString.length > 10 ? rawDateString.substring(0, 10) : rawDateString;
    }).toList();

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final raw = data[i][dataKey];
      final val = (raw is num) ? raw.toDouble() :
      double.tryParse(raw?.toString() ?? '') ?? 0.0;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return RepaintBoundary(
      key: edaChartKeys[dataKey],
      child: SizedBox(
        height: 300,
        child: Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 15),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                            spots: spots,
                            dotData: FlDotData(
                              show: false,
                            ),
                            isCurved: true,
                            color: color,
                            barWidth: 2)
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                            reservedSize: 45
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, // Always try to show titles
                            reservedSize: 40, // Adjust size
                            interval: (data.length / 6).ceilToDouble().clamp(1, double.infinity), // Dynamic interval
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i >= 0 && i < titles.length) {
                                // Rotate titles slightly for better fit
                                return SideTitleWidget(
                                  meta: meta,
                                  angle: -0.5,
                                  space: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(titles[i], style: const TextStyle(fontSize: 10)),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(show: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // WEB OR MOBILE — decide layout
  bool isWideWeb(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return kIsWeb && width > 900;
  }

  Widget buildChartsSection() {
    final charts = [
      buildLineChart("Open Prices", edaData, "Open", Colors.orange, "Date", "Open"),
      buildLineChart("High Prices", edaData, "High", Colors.green, "Date", "High"),
      buildLineChart("Low Prices", edaData, "Low", Colors.red, "Date", "Low"),
      buildLineChart("Close Prices", edaData, "Close", Colors.blue, "Date", "Close"),
      buildLineChart("Volume", edaData, "Volume", Colors.grey, "Date", "Volume"),
    ];

    if (isWideWeb(context)) {
      // ------------------------ WEB GRID ------------------------
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: charts,
      );
    }

    // ------------------------ MOBILE LIST ------------------------
    return Column(children: charts);
  }


  // PDF GENERATION
  Future<Uint8List?> captureWidget(GlobalKey key,
      {int maxRetries = 10, int delayMs = 150}) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      final context = key.currentContext;
      if (context != null) {
        final renderObject = context.findRenderObject() as RenderRepaintBoundary?;
        if (renderObject != null) {
          try {
            // Lowered pixelRatio for smaller images that still look fine in PDFs
            final image = await renderObject.toImage(pixelRatio: 1.5);
            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              return byteData.buffer.asUint8List();
            }
          } catch (e) {
            debugPrint('Error capturing widget: $e');
          }
        }
      }
      attempts++;
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    debugPrint('Failed to capture widget after $maxRetries attempts.');
    return null;
  }

  Future<Uint8List?> _captureWidgetByScrolling(GlobalKey key) async {
    if (key.currentContext != null) {
      try {
        await Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
        );
      } catch (_) {
        // ignored - ensureVisible can throw if widget not in a scrollable
      }

      // Give Flutter a moment to paint the widget after scrolling
      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetsBinding.instance.endOfFrame;

      return await captureWidget(key);
    }

    debugPrint("Could not find context for key. The widget might not be in the tree.");
    return null;
  }

  // -------------------- GENERATE PDF (WEB-SAFE) --------------------
  Future<void> generatePdf() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to upload PDF!')),
      );
      return;
    }

    if (anomalies.isEmpty && pieData.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available for PDF')),
      );
      return;
    }

    // Show a persistent loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Generating & Uploading PDF...")),
          ],
        ),
      ),
    );

    try {
      
      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetsBinding.instance.endOfFrame;

      // --- Capture images by SCROLLING them into view first ---
      final anomalyImage = await _captureWidgetByScrolling(anomalyChartKey);
      final pieChartImage = await _captureWidgetByScrolling(pieKey);
      final openPriceImage = await _captureWidgetByScrolling(edaChartKeys["Open"]!);
      final closePriceImage = await _captureWidgetByScrolling(edaChartKeys["Close"]!);

      // --- Check if essential captures were successful ---
      if (anomalyImage == null || pieChartImage == null) {
        debugPrint('Failed to capture essential charts. Aborting PDF generation.');
        if (mounted) {
          Navigator.of(context).pop(); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Could not capture chart images for PDF.')),
          );
        }
        return;
      }

      // --- Build the PDF document ---
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            final widgets = <pw.Widget>[];

            widgets.add(pw.Text("Anomaly Report",
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.SizedBox(height: 20));

            // Anomaly Chart
            widgets.add(pw.Text("Anomaly Chart", style: pw.TextStyle(fontSize: 16)));
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(pw.Image(pw.MemoryImage(anomalyImage), width: 400, height: 250));
            widgets.add(pw.SizedBox(height: 20));

            // Pie Summary
            widgets.add(pw.Text("Pie Summary", style: pw.TextStyle(fontSize: 16)));
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(pw.Image(pw.MemoryImage(pieChartImage), width: 300, height: 200));
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(pw.Text("Anomalies: ${pieData['anomalies'] ?? 0} | Total: ${pieData['total_points'] ?? 0}"));
            widgets.add(pw.SizedBox(height: 20));

            // Other charts
            if (openPriceImage != null) {
              widgets.add(pw.Text("Open Prices Chart", style: pw.TextStyle(fontSize: 16)));
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(pw.Image(pw.MemoryImage(openPriceImage)));
              widgets.add(pw.SizedBox(height: 20));
            }
            if (closePriceImage != null) {
              widgets.add(pw.Text("Close Prices Chart", style: pw.TextStyle(fontSize: 16)));
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(pw.Image(pw.MemoryImage(closePriceImage)));
              widgets.add(pw.SizedBox(height: 20));
            }

            // Anomalies Table
            if (anomalies.isNotEmpty) {
              widgets.add(pw.Text("Detected Anomalies Table", style: pw.TextStyle(fontSize: 16)));
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(pw.Table.fromTextArray(
                headers: anomalies.first.keys.toList(),
                data: anomalies
                    .map((row) => row.values.map((v) => v.toString()).toList())
                    .toList(),
              ));
            }

            return widgets;
          },
        ),
      );

      // --- Save and Upload ---
      final bytes = await pdf.save();
      final fileName = 'anomaly_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${user.id}/$fileName';

      await Supabase.instance.client.storage.from('reports').uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF generated and uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${e.toString()}')));
      }
    }
  }

  // =====================================================
  // BUILD UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomaly Detection Dashboard'),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
          const Text('Analysis charts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (edaData.isNotEmpty) buildChartsSection(),

          const Divider(),

          const Text('Detected Anomalies',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          buildAnomaliesTable(),

          const Divider(),

          AnomalyChartWidget(
            allData: edaData,
            anomalies: anomalies,
            chartKey: anomalyChartKey,
          ),

          const Divider(),

          const Text('Pie Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          buildPieChart(),
                  ],
                ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "upload",
            backgroundColor: Colors.blueAccent,
            onPressed: uploadCSV,
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "pdf",
            backgroundColor: Colors.green,
            onPressed: generatePdf,
            child: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
    );
  }
}
