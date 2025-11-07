import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class EDAChart extends StatelessWidget {
  final Map<String, dynamic> eda;
  const EDAChart({super.key, required this.eda});

  @override
  Widget build(BuildContext context) {
    if (eda.isEmpty) {
      return const Text("No EDA data available");
    }

    final series = {
      'Close': List<double>.from(eda['Close'] ?? []),
      'High': List<double>.from(eda['High'] ?? []),
      'Low': List<double>.from(eda['Low'] ?? []),
      'Open': List<double>.from(eda['Open'] ?? []),
      'Volume': List<double>.from(eda['Volume'] ?? []),
    };

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          lineBarsData: series.entries.map((entry) {
            final points = <FlSpot>[];
            for (int i = 0; i < entry.value.length; i++) {
              points.add(FlSpot(i.toDouble(), entry.value[i]));
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
