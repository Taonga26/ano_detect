import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class RecentChart extends StatelessWidget {
  final Map<String, dynamic> recent;
  const RecentChart({super.key, required this.recent});

  @override
  Widget build(BuildContext context) {
    // Basic validation
    final datesList = recent['dates'] ?? [];
    final closeList = recent['close'] ?? [];
    final flagsList = recent['flags'] ?? [];

    if (datesList.isEmpty || closeList.isEmpty) {
      return const Text("No recent data");
    }

    final dates = List<String>.from(datesList.map((d) => d.toString()));

    double _toDouble(dynamic v) {
      if (v == null) return double.nan;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? double.nan;
    }

    final close = List<double>.from(closeList.map(_toDouble));
    final flags = List<dynamic>.from(flagsList);

    // Prepare spots for the full close series
    final spots = <FlSpot>[];
    for (int i = 0; i < close.length; i++) {
      final v = close[i];
      if (!v.isNaN) spots.add(FlSpot(i.toDouble(), v));
    }

    // Prepare spots that correspond to detected anomalies (flag == 1 or true)
    final anomalySpots = <FlSpot>[];
    for (int i = 0; i < flags.length && i < close.length; i++) {
      final flag = flags[i];
      final v = close[i];
      final isAnomaly =
          (flag == 1 || flag == true || flag == '1' || flag == 'true');
      if (isAnomaly && !v.isNaN) {
        anomalySpots.add(FlSpot(i.toDouble(), v));
      }
    }

    // Compute Y bounds for nicer viewport
    double minY = spots.isEmpty
        ? 0
        : spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.isEmpty
        ? 0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPadding = (maxY - minY) * 0.1;
    if (yPadding.isNaN || yPadding <= 0) {
      // fallback small padding
      minY = minY - 1;
      maxY = maxY + 1;
    } else {
      minY = minY - yPadding;
      maxY = maxY + yPadding;
    }

    return SizedBox(
      height: 320,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.isEmpty ? 0 : spots.last.x),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            // Full series
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue.shade400,
              barWidth: 2,
              dotData: FlDotData(show: false),
            ),
            // Anomaly points overlay
            LineChartBarData(
              spots: anomalySpots,
              isCurved: false,
              color: Colors.red,
              barWidth: 0,
              dotData: FlDotData(show: true),
              // show only dots (no connecting line)
            ),
          ],
          // Enable touch tooltip that shows date and value
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              // Keep default background; construct tooltip items with date + value
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((ts) {
                  final idx = ts.x.toInt();
                  final date = (idx >= 0 && idx < dates.length)
                      ? dates[idx]
                      : ts.x.toString();
                  return LineTooltipItem(
                    '$date\n${ts.y.toStringAsFixed(2)}',
                    const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          // Minimal axes and border for a clean look
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
        ),
      ),
    );
  }
}
