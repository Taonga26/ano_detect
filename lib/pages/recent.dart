import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class RecentChart extends StatelessWidget {
  final Map<String, dynamic> recent;
  const RecentChart({super.key, required this.recent});

  @override
  Widget build(BuildContext context) {
    if (recent['dates'].isEmpty) return const Text("No recent data");

    final dates = List<String>.from(recent['dates']);
    final close = List<dynamic>.from(recent['close']);
    final flags = List<dynamic>.from(recent['flags']);

    final spots = <FlSpot>[];
    for (int i = 0; i < close.length; i++) {
      if (close[i] != null) spots.add(FlSpot(i.toDouble(), close[i].toDouble()));
    }

    final anomalySpots = <FlSpot>[];
    for (int i = 0; i < flags.length; i++) {
      if (flags[i] == 1 && close[i] != null) {
        anomalySpots.add(FlSpot(i.toDouble(), close[i].toDouble()));
      }
    }

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(spots: spots, isCurved: true, color: Colors.blue),
            LineChartBarData(spots: anomalySpots, isCurved: false, color: Colors.red, dotData: FlDotData(show: true)),
          ],
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
