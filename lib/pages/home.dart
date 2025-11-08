import 'dart:io';
import 'package:ano_detect/pages/pie_chart.dart';
import 'package:ano_detect/pages/recent.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/service.dart';
import 'eda_chart_clean.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService api = ApiService();
  bool isLoading = false;
  Map<String, dynamic>? result;
  File? selectedFile;

  Future<void> pickAndUploadFile() async {
    FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (picked != null) {
      setState(() => isLoading = true);
      File file = File(picked.files.single.path!);
      setState(() => selectedFile = file);
      try {
        final res = await api.uploadCsv(file);
        // store result in state
        setState(() => result = res);

        // Debug prints to confirm server payloads were received
        try {
          // Print high-level keys and sizes
          print('== Server response keys: ${res.keys.toList()}');
          print(
            'EDA keys: ${res['eda'] != null ? (res['eda'] as Map).keys.toList() : 'null'}',
          );
          print(
            'Recent keys: ${res['recent'] != null ? (res['recent'] as Map).keys.toList() : 'null'}',
          );
          print('Pie payload: ${res['pie']}');
          final anomaliesList = res['anomalies'] as List?;
          print(
            'Anomalies count (raw from server): ${anomaliesList?.length ?? 0}',
          );
          if (anomaliesList != null && anomaliesList.isNotEmpty) {
            print('First anomaly record: ${anomaliesList.first}');
          }
        } catch (e) {
          print('Error while printing server response: $e');
        }

        // Quick user-visible confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload complete — anomalies: ${(res['anomalies'] as List?)?.length ?? 0}, eda cols: ${(res['eda']?['columns'] as List?)?.length ?? 0}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomaly Detection Dashboard'),
        backgroundColor: Colors.blueGrey[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : result == null
            ? Center(
                child: ElevatedButton.icon(
                  onPressed: pickAndUploadFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload CSV File'),
                ),
              )
            : buildDashboard(),
      ),
    );
  }

  Widget buildDashboard() {
    final recent = result!['recent'];
    final pie = result!['pie'];
    final anomalies = List<Map<String, dynamic>>.from(result!['anomalies']);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: pickAndUploadFile,
            icon: const Icon(Icons.refresh),
            label: const Text('Upload New File'),
          ),
          const SizedBox(height: 20),
          Text(
            "📊 Exploratory Data Analysis",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          // Prefer server EDA when available; still pass csvFile for fallback parsing
          EDAChart(csvFile: selectedFile, edaFromServer: result?['eda']),
          const SizedBox(height: 30),
          Text(
            "🚨 Recent Anomalies",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          RecentChart(recent: recent),
          const SizedBox(height: 30),
          Text(
            "🧮 Anomaly Summary",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          PieChartWidget(pie: pie),
          const SizedBox(height: 30),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "📋 Detected Anomalies",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                "Total Anomalies: ${anomalies.length}",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Close')),
                DataColumn(label: Text('High')),
                DataColumn(label: Text('Low')),
                DataColumn(label: Text('Open')),
                DataColumn(label: Text('Volume')),
              ],
              rows: anomalies
                  .map(
                    (a) => DataRow(
                      cells: [
                        DataCell(Text(a['Date'].toString())),
                        DataCell(Text(a['Close']?.toString() ?? '-')),
                        DataCell(Text(a['High']?.toString() ?? '-')),
                        DataCell(Text(a['Low']?.toString() ?? '-')),
                        DataCell(Text(a['Open']?.toString() ?? '-')),
                        DataCell(Text(a['Volume']?.toString() ?? '-')),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
