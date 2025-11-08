import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// EDAChart
///
/// Renders line charts for Exploratory Data Analysis (EDA) using either:
/// 1. Server-provided EDA data (preferred) with keys: `dates`, `series`
/// 2. Local CSV file or bytes (fallback) containing columns like Date, Open, High, Low, Close, Volume
class EDAChart extends StatelessWidget {
  final File? csvFile;
  final Uint8List? csvBytes;
  final Map<String, dynamic>? edaFromServer;
  final bool forceReadCsv;

  const EDAChart({
    super.key,
    this.csvFile,
    this.csvBytes,
    this.edaFromServer,
    this.forceReadCsv = false,
  });

  // Predefined colors for consistent series visualization
  static const seriesColors = {
    'Close': Colors.blue,
    'High': Colors.green,
    'Low': Colors.red,
    'Open': Colors.orange,
    'Volume': Colors.purple,
  };

  // Helper to safely convert various number formats to double
  double _toDouble(dynamic v) {
    if (v == null) return double.nan;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '');
    return double.tryParse(s) ?? double.nan;
  }

  @override
  Widget build(BuildContext context) {
    // Data containers
    List<String> dates = [];
    final Map<String, List<double>> series = {};
    String? errorMessage;

    // 1. Try server-provided EDA data first
    if (edaFromServer != null) {
      try {
        final rawDates = edaFromServer!['dates'] as List?;
        final rawSeries = edaFromServer!['series'] as Map?;

        if (rawDates != null) {
          dates = rawDates.map((d) => d.toString()).toList();
        }

        if (rawSeries != null) {
          rawSeries.forEach((k, v) {
            if (v is List) {
              final converted = v
                  .map((e) => _toDouble(e))
                  .where((d) => !d.isNaN)
                  .toList();
              if (converted.isNotEmpty) series[k.toString()] = converted;
            }
          });
        }
      } catch (e) {
        print('Error parsing server EDA: $e'); // Debug log
        errorMessage = 'Error parsing server data';
      }
    }

    // 2. CSV fallback if server data is missing or empty
    if (series.isEmpty && errorMessage == null) {
      if (csvFile == null) {
        errorMessage = 'No EDA data available';
      } else {
        try {
          final csvContent = csvFile!.readAsStringSync();
          final rows = const CsvToListConverter().convert(csvContent);

          if (rows.isEmpty || rows.length < 2) {
            errorMessage = 'CSV file contains no data rows';
          } else {
            final headers = rows.first.map((h) => h.toString()).toList();
            final dataRows = rows.skip(1).toList();

            // Extract numeric columns
            List<double> extractColumn(String name) {
              final idx = headers.indexWhere(
                (h) => h.toLowerCase() == name.toLowerCase(),
              );
              if (idx == -1) return [];
              return dataRows
                  .map((r) => _toDouble(r[idx]))
                  .where((v) => !v.isNaN)
                  .toList();
            }

            // Get all important columns
            series['Close'] = extractColumn('Close');
            series['High'] = extractColumn('High');
            series['Low'] = extractColumn('Low');
            series['Open'] = extractColumn('Open');
            series['Volume'] = extractColumn('Volume');

            // Extract dates if present
            final dateIdx = headers.indexWhere(
              (h) => h.toLowerCase() == 'date',
            );
            if (dateIdx != -1) {
              dates = dataRows.map((r) => r[dateIdx].toString()).toList();
            }
          }
        } catch (e) {
          print('Error reading CSV: $e'); // Debug log
          errorMessage = 'Error reading CSV file';
        }
      }
    }

    // Show error state if we encountered problems
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            errorMessage,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.red[700]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Convert data series to fl_chart format
    final lineBars = <LineChartBarData>[];
    var maxLength = 0;

    series.forEach((name, values) {
      if (values.isEmpty) return;
      maxLength = values.length > maxLength ? values.length : maxLength;

      final spots = List<FlSpot>.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i]),
      );

      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: seriesColors[name] ?? Colors.grey,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          barWidth: 2,
        ),
      );
    });

    if (lineBars.isEmpty) {
      return const Center(child: Text('No numeric columns found in the data'));
    }

    // Configure date labels on bottom axis
    AxisTitles bottomAxis = AxisTitles(
      sideTitles: SideTitles(showTitles: false),
    );

    if (dates.isNotEmpty) {
      final len = dates.length;
      final step = (len / 4).ceil().clamp(1, len);

      bottomAxis = AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: step.toDouble(),
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= dates.length) {
              return const SizedBox.shrink();
            }

            final raw = dates[idx];
            String label;
            try {
              final dt = DateTime.parse(raw);
              label = dt.toIso8601String().split('T').first;
            } catch (_) {
              label = raw.length > 10 ? raw.substring(0, 10) : raw;
            }

            return Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(label, style: const TextStyle(fontSize: 10)),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (maxLength - 1).toDouble(),
              lineBarsData: lineBars,
              titlesData: FlTitlesData(
                bottomTitles: bottomAxis,
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                  );
                },
              ),
            ),
          ),
        ),
        // Legend showing available data series
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Wrap(
            spacing: 16.0,
            runSpacing: 8.0,
            children: series.keys.map((name) {
              final color = seriesColors[name] ?? Colors.grey;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 16, height: 2, color: color),
                  const SizedBox(width: 4),
                  Text(
                    name,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black87),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
