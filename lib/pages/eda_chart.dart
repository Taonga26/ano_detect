import 'dart:io';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class EDAChart extends StatelessWidget {
  final File csvFile;
  const EDAChart({super.key, required this.csvFile});

  @override
  Widget build(BuildContext context) {
    final csvContent = csvFile.readAsStringSync();
    final rows = const CsvToListConverter().convert(csvContent);

    if (rows.isEmpty || rows.length < 2) {
      return const Text("No EDA data available");
    }

    final headers = rows.first.cast<String>();
    final dataRows = rows.skip(1).toList();

    final dates = dataRows
        .map((row) => row[headers.indexOf('Date')].toString())
        .toList();
    final series = {
      'Close': dataRows.map((row) => row[headers.indexOf('Close')]).toList(),
      'High': dataRows.map((row) => row[headers.indexOf('High')]).toList(),
      'Low': dataRows.map((row) => row[headers.indexOf('Low')]).toList(),
      'Open': dataRows.map((row) => row[headers.indexOf('Open')]).toList(),
    };

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          lineBarsData: series.entries.map((entry) {
            final points = <FlSpot>[];
            for (int i = 0; i < entry.value.length; i++) {
              final val = entry.value[i];
              if (val != null) points.add(FlSpot(i.toDouble(), val.toDouble()));
            }
            return LineChartBarData(
              spots: points,
              isCurved: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            );
          }).toList(),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
