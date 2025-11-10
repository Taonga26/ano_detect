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
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Keys to capture charts
  final GlobalKey pieKey = GlobalKey();
  final GlobalKey anomalyChartKey = GlobalKey();
  final Map<String, GlobalKey> edaChartKeys = {
    'Open': GlobalKey(),
    'High': GlobalKey(),
    'Low': GlobalKey(),
    'Close': GlobalKey(),
    'Volume': GlobalKey(),
  };

  // -------------------- CSV UPLOAD --------------------
  Future<void> uploadCSV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;

    setState(() => isLoading = true);

    try {
      final uri = Uri.parse('http://192.168.201.98:8000/api/v1/predict');
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
          anomalies = List<Map<String, dynamic>>.from(data['anomalies'] ?? []);
          edaData = List<Map<String, dynamic>>.from(data['eda'] ?? []);
          pieData = Map<String, dynamic>.from(data['pie'] ?? {});
          isLoading = false;
        });
      } else {
        throw Exception('Failed to upload CSV');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // -------------------- ANOMALIES TABLE --------------------
  Widget buildAnomaliesTable() {
    if (anomalies.isEmpty) return const Text("No anomalies detected");
    final columns = anomalies.first.keys.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.red.shade100),
        columns: columns
            .map((col) => DataColumn(
          label: Text(col,
              style: const TextStyle(fontWeight: FontWeight.bold)),
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

  // -------------------- PIE CHART --------------------
  Widget buildPieChart() {
    if (pieData.isEmpty) return const Text("No pie data available");

    final anomalyPercent = pieData['percentages']?['anomalies'] ?? 0.0;
    final normalPercent = pieData['percentages']?['normal'] ?? 100.0;
    final anomalyPoints = pieData['anomalies'] ?? 0;
    final totalPoints = pieData['total_points'] ?? 0;

    return RepaintBoundary(
      key: pieKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anomalies detected: $anomalyPoints'),
            const SizedBox(height: 5),
            Text('Total entries: $totalPoints'),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: anomalyPercent.toDouble(),
                        color: Colors.redAccent,
                        title: '${anomalyPercent.toStringAsFixed(1)}%',
                        titleStyle: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                        radius: 60,
                        titlePositionPercentageOffset: 0.6,
                      ),
                      PieChartSectionData(
                        value: normalPercent.toDouble(),
                        color: Colors.green,
                        title: '${normalPercent.toStringAsFixed(1)}%',
                        titleStyle: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                        radius: 60,
                        titlePositionPercentageOffset: 0.6,
                      ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- LINE CHART --------------------
  Widget buildLineChart(String title, List<Map<String, dynamic>> data, String key,
      Color color, String xLabel, String yLabel) {
    if (edaData.isEmpty) return const Text("No data available for chart");

    List<String> titles = data.map((d) {
      String date = d['Date']?.toString() ?? '';
      return date.split(' ')[0];
    }).toList();

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i][key] ?? 0).toDouble()));
    }

    return RepaintBoundary(
      key: edaChartKeys[key],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: 300,
              width: 400,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(xLabel),
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (data.length / 5).floorToDouble() > 0
                            ? (data.length / 5).floorToDouble()
                            : 1,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx >= 0 && idx < titles.length) {
                            return Text(
                              titles[idx],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(yLabel),
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  minY: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // -------------------- ANOMALY CHART --------------------
  Widget buildAnomalyChart() {
    if (anomalies.isEmpty) return const Text("No anomalies to chart");

    List<String> titles = anomalies.map((d) {
      String date = d['Date']?.toString() ?? '';
      return date.split(' ')[0];
    }).toList();

    List<FlSpot> spots = [];
    for (int i = 0; i < anomalies.length; i++) {
      spots.add(FlSpot(i.toDouble(), (anomalies[i]['Close'] ?? 0).toDouble()));
    }

    return RepaintBoundary(
      key: anomalyChartKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🚨 Anomaly Chart', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: 300,
              width: 450,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.redAccent,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text("Date"),
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (anomalies.length / 5).floorToDouble() > 0
                            ? (anomalies.length / 5).floorToDouble()
                            : 1,
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx >= 0 && idx < titles.length) {
                            return Text(titles[idx],
                                style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text("Close"),
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // -------------------- CAPTURE WIDGET WITH RETRY --------------------
  Future<Uint8List?> captureWidget(GlobalKey key,
      {int maxRetries = 10, int delayMs = 100}) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      final context = key.currentContext;
      if (context != null) {
        final renderObject = context.findRenderObject() as RenderRepaintBoundary?;
        if (renderObject != null) {
          try {
            final image = await renderObject.toImage(pixelRatio: 3.0);
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

  // -------------------- GENERATE PDF --------------------
  Future<void> generatePdf() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to upload PDF!')),
      );
      return;
    }

    if (anomalies.isEmpty && pieData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available for PDF')),
      );
      return;
    }

    setState(() => isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Generating PDF...")),
          ],
        ),
      ),
    );

    try {
      // Ensure charts are rendered
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 200));

      final anomalyImage = await captureWidget(anomalyChartKey);
      final pieChartImage = await captureWidget(pieKey);

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            final widgets = <pw.Widget>[];

            widgets.add(
              pw.Text("📊 Anomaly Report",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            );
            widgets.add(pw.SizedBox(height: 20));

            if (anomalyImage != null) {
              widgets.add(pw.Text("🚨 Anomaly Chart", style: pw.TextStyle(fontSize: 16)));
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(pw.Image(pw.MemoryImage(anomalyImage), width: 400, height: 250));
              widgets.add(pw.SizedBox(height: 20));
            }

            if (pieChartImage != null) {
              widgets.add(pw.Text("🥧 Pie Summary", style: pw.TextStyle(fontSize: 16)));
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(pw.Image(pw.MemoryImage(pieChartImage), width: 300, height: 200));
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(
                pw.Text(
                  "Anomalies: ${pieData['anomalies'] ?? 0} | Total: ${pieData['total_points'] ?? 0}",
                ),
              );
              widgets.add(pw.SizedBox(height: 20));
            }

            if (anomalies.isNotEmpty) {
              widgets.add(pw.Text("Detected Anomalies Table", style: pw.TextStyle(fontSize: 16)));
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(
                pw.Table.fromTextArray(
                  headers: anomalies.first.keys.toList(),
                  data: anomalies
                      .map((row) => row.values.map((v) => v.toString()).toList())
                      .toList(),
                ),
              );
            }

            return widgets;
          },
        ),
      );



      // Upload to Supabase with RLS-safe user_id
      final supabase = Supabase.instance.client;

      try {
        final bytes = await pdf.save();

        // Save locally
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'anomaly_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PDF saved & uploaded!')));
        await OpenFile.open(file.path);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${e.toString()}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('PDF generation error: $e')));
    } finally {
      Navigator.of(context).pop(); // Close loading dialog
      setState(() => isLoading = false);
    }
  }


  // -------------------- BUILD --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomaly Detection Dashboard'),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text('Analysis charts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (edaData.isNotEmpty) ...[
              buildLineChart("Open Prices", edaData, "Open", Colors.orange, "Date", "Open"),
              buildLineChart("High Prices", edaData, "High", Colors.green, "Date", "High"),
              buildLineChart("Low Prices", edaData, "Low", Colors.red, "Date", "Low"),
              buildLineChart("Close Prices", edaData, "Close", Colors.blue, "Date", "Close"),
              buildLineChart("Volume", edaData, "Volume", Colors.grey, "Date", "Volume"),
            ],
            const Divider(height: 30),
            const Text('🚨 Detected Anomalies',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            buildAnomaliesTable(),
            const Divider(height: 30),
            buildAnomalyChart(),
            const Divider(height: 30),
            const Text('🥧 Pie Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            buildPieChart(),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.blueAccent,
            onPressed: uploadCSV,
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            backgroundColor: Colors.green,
            onPressed: generatePdf,
            child: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
    );
  }
}
