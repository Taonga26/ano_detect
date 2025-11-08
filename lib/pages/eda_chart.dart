import 'dart:io';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class EDAChart extends StatelessWidget {
  final File csvFile;
  const EDAChart({super.key, required this.csvFile});

  double _toDouble(dynamic v) {
    if (v == null) return double.nan;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '');
    return double.tryParse(s) ?? double.nan;
  }

  @override
  Widget build(BuildContext context) {
    final csvContent = csvFile.readAsStringSync();
    final rows = const CsvToListConverter().convert(csvContent);

    if (rows.isEmpty || rows.length < 2) {
      return const Text("No EDA data available");
    }

    final headers = rows.first.map((h) => h.toString()).toList();
    final dataRows = rows.skip(1).toList();

    List<double> extractColumn(String name) {
      final idx = headers.indexWhere(
        (h) => h.toLowerCase() == name.toLowerCase(),
      );
      if (idx == -1) return [];
      return dataRows
          .map((row) => _toDouble(row[idx]))
          .where((v) => !v.isNaN)
          .toList();
    }

    final series = {
      'Close': extractColumn('Close'),
      'High': extractColumn('High'),
      'Low': extractColumn('Low'),
      'Open': extractColumn('Open'),
      'Volume': extractColumn('Volume'),
    };

    // Build line series for fl_chart
    final lineBars = <LineChartBarData>[];
    int maxLength = 0;
    series.forEach((name, list) {
      if (list.isNotEmpty) {
        maxLength = list.length > maxLength ? list.length : maxLength;
        final spots = <FlSpot>[];
        for (int i = 0; i < list.length; i++) {
          spots.add(FlSpot(i.toDouble(), list[i]));
        }
        lineBars.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            barWidth: 2,
          ),
        );
      }
    });

    if (lineBars.isEmpty) return const Text('No numeric EDA columns found');

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (maxLength - 1).toDouble(),
          lineBarsData: lineBars,
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
