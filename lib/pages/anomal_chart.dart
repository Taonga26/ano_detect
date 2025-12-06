import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnomalyChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> allData;
  final List<Map<String, dynamic>> anomalies;
  final GlobalKey chartKey;

  const AnomalyChartWidget({
    super.key,
    required this.allData,
    required this.anomalies,
    required this.chartKey,
  });

  @override
  State<AnomalyChartWidget> createState() => _AnomalyChartWidgetState();
}

class _AnomalyChartWidgetState extends State<AnomalyChartWidget> {
  // 1. State to manage the selected data series
  String _selectedKey = 'Close'; // Default to 'Close'
  final List<String> _availableKeys = ['Open', 'Close', 'High', 'Low', 'Volume'];

  @override
  Widget build(BuildContext context) {
    if (widget.anomalies.isEmpty) return const Text("No anomalies to chart");

    // --- PREPARE DATA ---
    final chartData = widget.allData;
    final anomalyDates = widget.anomalies.map((a) => a['Date']).toSet();

    List<String> titles = chartData.map((d) {
      final rawDateString = d['Date']?.toString() ?? '';
      if (rawDateString.isEmpty) return '';
      try {
        final dateTime = HttpDate.parse(rawDateString);
        return DateFormat("dd/MM/yyyy").format(dateTime);
      } catch (e) {
        return '';
      }
    }).toList();

    List<FlSpot> baselineSpots = [];
    List<FlSpot> anomalySpots = [];

    for (int i = 0; i < chartData.length; i++) {
      // 2. Use the _selectedKey to get the right data
      final yValue = (chartData[i][_selectedKey] ?? 0).toDouble();
      final spot = FlSpot(i.toDouble(), yValue);

      baselineSpots.add(spot);

      if (anomalyDates.contains(chartData[i]['Date'])) {
        anomalySpots.add(spot);
      }
    }

    return RepaintBoundary(
      key: widget.chartKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🚨 Interactive Anomaly Chart',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // Adding ChoiceChips to switch between data series
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableKeys.map((key) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(key),
                    selected: _selectedKey == key,
                    onSelected: (isSelected) {
                      if (isSelected) {
                        setState(() {
                          _selectedKey = key;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // --- The Chart ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: 400,
              width: 800,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LineChart(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: baselineSpots,
                        isCurved: true,
                        color: Colors.grey.withOpacity(0.5),
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: anomalySpots,
                        color: Colors.transparent,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                radius: 2,
                                color: Colors.red,
                                strokeWidth: 1,
                                strokeColor: Colors.white,
                              ),
                        ),
                      ),
                    ],
                    titlesData: FlTitlesData(

                      leftTitles: AxisTitles(
                        axisNameWidget: Text(_selectedKey),
                        sideTitles: SideTitles(reservedSize: 45, showTitles: true),
                      ),
                      bottomTitles: AxisTitles(
                        axisNameWidget: const Text("Date"),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: (chartData.length / 6).ceilToDouble().clamp(1, double.infinity),
                          getTitlesWidget: (value, meta) {
                            int idx = value.toInt();
                            if (idx >= 0 && idx < titles.length) {
                              return SideTitleWidget(
                                meta: meta,
                                angle: -0.5,
                                space: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(titles[idx], style: const TextStyle(fontSize: 10)),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: true),
                    minY: 0,
                  ),

                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
