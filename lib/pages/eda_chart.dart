export 'eda_chart_clean.dart';export 'eda_chart_clean.dart';


/// EDAChart
///
/// Renders line charts using server-provided EDA data when available
/// (expected keys: `columns`, `dates`, `series`) and falls back to
/// parsing a provided CSV `File`.
class EDAChart extends StatelessWidget {
  final File? csvFile;
  final Map<String, dynamic>? edaFromServer;

  const EDAChart({super.key, this.csvFile, this.edaFromServer});

  double _toDouble(dynamic v) {
    if (v == null) return double.nan;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '');
    return double.tryParse(s) ?? double.nan;
  }

  @override
  Widget build(BuildContext context) {
    // Prepare containers for X labels (dates) and series.
    List<String> dates = [];
    final Map<String, List<double>> series = {};

    // 1) Prefer server-provided EDA if present and well-formed
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
      } catch (_) {
        // If server payload parsing fails, ignore and fall back to CSV below.
      }
    }

    // 2) CSV fallback: if we have no server series or they are empty
    if (series.isEmpty) {
      if (csvFile == null) return const Text('No EDA data available');

      final csvContent = csvFile!.readAsStringSync();
      final rows = const CsvToListConverter().convert(csvContent);
      if (rows.isEmpty || rows.length < 2) return const Text('No EDA data available');

      final headers = rows.first.map((h) => h.toString()).toList();
      final dataRows = rows.skip(1).toList();

      List<double> extractColumn(String name) {
        final idx = headers.indexWhere((h) => h.toLowerCase() == name.toLowerCase());
        if (idx == -1) return [];
        return dataRows
            .map((r) => _toDouble(r[idx]))
            .where((v) => !v.isNaN)
            .toList();
      }

      series['Close'] = extractColumn('Close');
      series['High'] = extractColumn('High');
      series['Low'] = extractColumn('Low');
      series['Open'] = extractColumn('Open');
      series['Volume'] = extractColumn('Volume');

      final dateIdx = headers.indexWhere((h) => h.toLowerCase() == 'date');
      if (dateIdx != -1) {
        dates = dataRows.map((r) => r[dateIdx].toString()).toList();
      }
    }

    // Build fl_chart line series
    final lineBars = <LineChartBarData>[];
    var maxLength = 0;
    series.forEach((name, values) {
      if (values.isEmpty) return;
      maxLength = values.length > maxLength ? values.length : maxLength;
      final spots = <FlSpot>[];
      for (var i = 0; i < values.length; i++) {
        spots.add(FlSpot(i.toDouble(), values[i]));
      }
      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        barWidth: 2,
      ));
    });

    if (lineBars.isEmpty) return const Text('No numeric EDA columns found');

    // Build bottom axis titles using dates when available
    AxisTitles bottomAxis = AxisTitles(sideTitles: SideTitles(showTitles: false));
    if (dates.isNotEmpty) {
      final len = dates.length;
      final step = (len / 4).ceil().clamp(1, len);
      final side = SideTitles(
        showTitles: true,
        interval: step.toDouble(),
        getTitlesWidget: (value, meta) {
          final idx = value.toInt();
          if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
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
      );
      bottomAxis = AxisTitles(sideTitles: side);
    }

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (maxLength - 1).toDouble(),
          lineBarsData: lineBars,
          titlesData: FlTitlesData(
            bottomTitles: bottomAxis,
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// EDAChart
///
/// Renders line charts using server-provided EDA data when available
/// (expected keys: `columns`, `dates`, `series`) and falls back to
/// parsing a provided CSV `File`.
class EDAChart extends StatelessWidget {
  final File? csvFile;
  final Map<String, dynamic>? edaFromServer;

  const EDAChart({super.key, this.csvFile, this.edaFromServer});

  double _toDouble(dynamic v) {
    if (v == null) return double.nan;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '');
    return double.tryParse(s) ?? double.nan;
  }

  @override
  Widget build(BuildContext context) {
    // Prepare containers for X labels (dates) and series.
    List<String> dates = [];
    final Map<String, List<double>> series = {};

    // 1) Prefer server-provided EDA if present and well-formed
    if (edaFromServer != null) {
      try {
        final rawDates = edaFromServer!['dates'] as List?;
        final rawSeries = edaFromServer!['series'] as Map?;

        if (rawDates != null) dates = rawDates.map((d) => d.toString()).toList();

        if (rawSeries != null) {
          rawSeries.forEach((k, v) {
            if (v is List) {
              final converted = v.map((e) => _toDouble(e)).where((d) => !d.isNaN).toList();
              if (converted.isNotEmpty) series[k.toString()] = converted;
            }
          });
        }
      } catch (_) {
        // If server payload parsing fails, ignore and fall back to CSV below.
      }
    }

    // 2) CSV fallback: if we have no server series or they are empty
    if (series.isEmpty) {
      if (csvFile == null) return const Text('No EDA data available');

      final csvContent = csvFile!.readAsStringSync();
      final rows = const CsvToListConverter().convert(csvContent);
      if (rows.isEmpty || rows.length < 2) return const Text('No EDA data available');

      final headers = rows.first.map((h) => h.toString()).toList();
      final dataRows = rows.skip(1).toList();

      List<double> extractColumn(String name) {
        final idx = headers.indexWhere((h) => h.toLowerCase() == name.toLowerCase());
        if (idx == -1) return [];
        return dataRows.map((r) => _toDouble(r[idx])).where((v) => !v.isNaN).toList();
      }

      series['Close'] = extractColumn('Close');
      series['High'] = extractColumn('High');
      series['Low'] = extractColumn('Low');
      series['Open'] = extractColumn('Open');
      series['Volume'] = extractColumn('Volume');

      final dateIdx = headers.indexWhere((h) => h.toLowerCase() == 'date');
      if (dateIdx != -1) {
        dates = dataRows.map((r) => r[dateIdx].toString()).toList();
      }
    }

    // Build fl_chart line series
    final lineBars = <LineChartBarData>[];
    var maxLength = 0;
    series.forEach((name, values) {
      if (values.isEmpty) return;
      maxLength = values.length > maxLength ? values.length : maxLength;
      final spots = <FlSpot>[];
      for (var i = 0; i < values.length; i++) {
        spots.add(FlSpot(i.toDouble(), values[i]));
      }
      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        barWidth: 2,
      ));
    });

    if (lineBars.isEmpty) return const Text('No numeric EDA columns found');

    // Build bottom axis titles using dates when available
    AxisTitles bottomAxis = AxisTitles(sideTitles: SideTitles(showTitles: false));
    if (dates.isNotEmpty) {
      final len = dates.length;
      final step = (len / 4).ceil().clamp(1, len);
      final side = SideTitles(
        showTitles: true,
        interval: step.toDouble(),
        getTitlesWidget: (value, meta) {
          final idx = value.toInt();
          if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
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
      );
      bottomAxis = AxisTitles(sideTitles: side);
    }

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (maxLength - 1).toDouble(),
          lineBarsData: lineBars,
          titlesData: FlTitlesData(
            bottomTitles: bottomAxis,
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class EDAChart extends StatelessWidget {
  final File? csvFile;
  final Map<String, dynamic>? edaFromServer;

  const EDAChart({super.key, this.csvFile, this.edaFromServer});

  double _toDouble(dynamic v) {
    if (v == null) return double.nan;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '');
    return double.tryParse(s) ?? double.nan;
  }

  @override
  Widget build(BuildContext context) {
    // dates for x-axis labels, series is map of column->values
    List<String> dates = [];
    Map<String, List<double>> series = {};

    // Try using server-provided EDA first (expected keys: columns, dates, series)
    if (edaFromServer != null && edaFromServer!['series'] != null) {
      try {
        final rawDates = edaFromServer!['dates'] as List?;
        final rawSeries = edaFromServer!['series'] as Map?;

        if (rawDates != null) dates = rawDates.map((d) => d.toString()).toList();

        if (rawSeries != null) {
          rawSeries.forEach((k, v) {
            if (v is List) {
              final converted = v.map((e) => _toDouble(e)).where((d) => !d.isNaN).toList();
              series[k.toString()] = converted;
            }
          });
        }
      } catch (_) {
        series = {};
      }
    }

    // CSV fallback when server EDA is not available or empty
    if (series.isEmpty) {
      if (csvFile == null) return const Text("No EDA data available");
      final csvContent = csvFile!.readAsStringSync();
      final rows = const CsvToListConverter().convert(csvContent);

      if (rows.isEmpty || rows.length < 2) {
        return const Text("No EDA data available");
      }

      final headers = rows.first.map((h) => h.toString()).toList();
      final dataRows = rows.skip(1).toList();

      List<double> extractColumn(String name) {
        final idx = headers.indexWhere((h) => h.toLowerCase() == name.toLowerCase());
        if (idx == -1) return [];
        return dataRows.map((row) => _toDouble(row[idx])).where((v) => !v.isNaN).toList();
      }

      series = {
        'Close': extractColumn('Close'),
        'High': extractColumn('High'),
        'Low': extractColumn('Low'),
        'Open': extractColumn('Open'),
        'Volume': extractColumn('Volume'),
      };

      final dateIdx = headers.indexWhere((h) => h.toLowerCase() == 'date');
      if (dateIdx != -1) {
        dates = dataRows.map((r) => r[dateIdx].toString()).toList();
      }
    }

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
        lineBars.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          barWidth: 2,
        ));
      }
    });

    if (lineBars.isEmpty) return const Text('No numeric EDA columns found');

    // Prepare bottom titles (use dates if available)
    SideTitles bottomTitles = SideTitles(showTitles: false);
    if (dates.isNotEmpty) {
      final int len = dates.length;
      final int step = (len / 4).ceil().clamp(1, len);
      bottomTitles = SideTitles(
        showTitles: true,
        interval: step.toDouble(),
        getTitlesWidget: (value, meta) {
          final idx = value.toInt();
          if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
          String label;
          try {
            final dt = DateTime.parse(dates[idx]);
            label = dt.toIso8601String().split('T').first;
          } catch (_) {
            final raw = dates[idx];
            label = raw.length > 10 ? raw.substring(0, 10) : raw;
          }
          return Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(label, style: const TextStyle(fontSize: 10)),
          );
        },
      );
    }

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (maxLength - 1).toDouble(),
          lineBarsData: lineBars,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: bottomTitles),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class EDAChart extends StatelessWidget {
  final File? csvFile;
  final Map<String, dynamic>? edaFromServer;

  const EDAChart({super.key, this.csvFile, this.edaFromServer});

  double _toDouble(dynamic v) {
    if (v == null) return double.nan;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '');
    return double.tryParse(s) ?? double.nan;
  }

  @override
  Widget build(BuildContext context) {
  // If server EDA is present prefer it (dates, series)
    List<String> dates = [];
    Map<String, List<double>> series = {};

    if (edaFromServer != null && edaFromServer!['series'] != null) {
      try {
        final rawCols = edaFromServer!['columns'] as List?;
        final rawDates = edaFromServer!['dates'] as List?;
        final rawSeries = edaFromServer!['series'] as Map?;

  if (rawCols != null) {/* columns available if needed: rawCols.map((c) => c.toString()).toList(); */}
        if (rawDates != null) dates = rawDates.map((d) => d.toString()).toList();

        if (rawSeries != null) {
          rawSeries.forEach((k, v) {
            if (v is List) {
              final converted = v.map((e) => _toDouble(e)).where((d) => !d.isNaN).toList();
              series[k.toString()] = converted;
            }
          });
        }
      } catch (e) {
        // fall through to CSV fallback
        series = {};
          },
        );
      }
    }

    if (lineBars.isEmpty) return const Text('No numeric EDA columns found');

    // Prepare bottom titles (use dates if available)
    SideTitles bottomTitles = SideTitles(showTitles: false);
      if (rows.isEmpty || rows.length < 2) {
        return const Text("No EDA data available");
      }

      final headers = rows.first.map((h) => h.toString()).toList();
      final dataRows = rows.skip(1).toList();

      List<double> extractColumn(String name) {
        final idx = headers.indexWhere((h) => h.toLowerCase() == name.toLowerCase());
        if (idx == -1) return [];
        return dataRows.map((row) => _toDouble(row[idx])).where((v) => !v.isNaN).toList();
      }

      series = {
        'Close': extractColumn('Close'),
        'High': extractColumn('High'),
        'Low': extractColumn('Low'),
        'Open': extractColumn('Open'),
        'Volume': extractColumn('Volume'),
      };
      // dates may be present in CSV headers or a Date column; try to extract
      final dateIdx = headers.indexWhere((h) => h.toLowerCase() == 'date');
      if (dateIdx != -1) {
        import 'dart:io';

        import 'package:csv/csv.dart';
        import 'package:fl_chart/fl_chart.dart';
        import 'package:flutter/material.dart';

        class EDAChart extends StatelessWidget {
          final File? csvFile;
          final Map<String, dynamic>? edaFromServer;

          const EDAChart({super.key, this.csvFile, this.edaFromServer});

          double _toDouble(dynamic v) {
            if (v == null) return double.nan;
            if (v is num) return v.toDouble();
            final s = v.toString().replaceAll(',', '');
            return double.tryParse(s) ?? double.nan;
          }

          @override
          Widget build(BuildContext context) {
            List<String> dates = [];
            Map<String, List<double>> series = {};

            // Try using server-provided EDA first
            if (edaFromServer != null && edaFromServer!['series'] != null) {
              try {
                final rawDates = edaFromServer!['dates'] as List?;
                final rawSeries = edaFromServer!['series'] as Map?;

                if (rawDates != null) dates = rawDates.map((d) => d.toString()).toList();

                if (rawSeries != null) {
                  rawSeries.forEach((k, v) {
                    if (v is List) {
                      final converted = v.map((e) => _toDouble(e)).where((d) => !d.isNaN).toList();
                      series[k.toString()] = converted;
                    }
                  });
                }
              } catch (_) {
                series = {};
              }
            }

            // CSV fallback when server EDA is not available or empty
            if (series.isEmpty) {
              if (csvFile == null) return const Text("No EDA data available");
              final csvContent = csvFile!.readAsStringSync();
              final rows = const CsvToListConverter().convert(csvContent);

              if (rows.isEmpty || rows.length < 2) {
                return const Text("No EDA data available");
              }

              final headers = rows.first.map((h) => h.toString()).toList();
              final dataRows = rows.skip(1).toList();

              List<double> extractColumn(String name) {
                final idx = headers.indexWhere((h) => h.toLowerCase() == name.toLowerCase());
                if (idx == -1) return [];
                return dataRows.map((row) => _toDouble(row[idx])).where((v) => !v.isNaN).toList();
              }

              series = {
                'Close': extractColumn('Close'),
                'High': extractColumn('High'),
                'Low': extractColumn('Low'),
                'Open': extractColumn('Open'),
                'Volume': extractColumn('Volume'),
              };

              final dateIdx = headers.indexWhere((h) => h.toLowerCase() == 'date');
              if (dateIdx != -1) {
                dates = dataRows.map((r) => r[dateIdx].toString()).toList();
              }
            }

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
                lineBars.add(LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                  barWidth: 2,
                ));
              }
            });

            if (lineBars.isEmpty) return const Text('No numeric EDA columns found');

            // Prepare bottom titles (use dates if available)
            SideTitles bottomTitles = SideTitles(showTitles: false);
            if (dates.isNotEmpty) {
              final int len = dates.length;
              final int step = (len / 4).ceil().clamp(1, len);
              bottomTitles = SideTitles(
                showTitles: true,
                interval: step.toDouble(),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                  String label;
                  try {
                    final dt = DateTime.parse(dates[idx]);
                    label = dt.toIso8601String().split('T').first;
                  } catch (_) {
                    final raw = dates[idx];
                    label = raw.length > 10 ? raw.substring(0, 10) : raw;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(label, style: const TextStyle(fontSize: 10)),
                  );
                },
              );
            }

            return SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (maxLength - 1).toDouble(),
                  lineBarsData: lineBars,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: bottomTitles),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),

