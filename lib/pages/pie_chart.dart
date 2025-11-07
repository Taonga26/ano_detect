import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PieChartWidget extends StatelessWidget {
  final Map<String, dynamic> pie;
  const PieChartWidget({super.key, required this.pie});

  @override
  Widget build(BuildContext context) {
    final total = pie['total'] ?? 0;
    final anomalies = pie['anomalies'] ?? 0;
    final normal = pie['normal'] ?? 0;

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(value: anomalies.toDouble(), color: Colors.red, title: 'Anomalies'),
            PieChartSectionData(value: normal.toDouble(), color: Colors.green, title: 'Normal'),
          ],
          sectionsSpace: 2,
          centerSpaceRadius: 30,
        ),
      ),
    );
  }
}
