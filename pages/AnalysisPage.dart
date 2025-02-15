import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:csv/csv.dart'; // For CSV parsing

class AnalysisPage extends StatefulWidget {
  final String panNumber;
  final double cibilScore;
  
  const AnalysisPage({Key? key, required this.panNumber, required this.cibilScore}) : super(key: key);

  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  List<PieChartSectionData> loanDistribution = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = Tween<double>(begin: 300, end: widget.cibilScore).animate(_controller)
      ..addListener(() {
        setState(() {});
      });

    _controller.forward();
    _fetchLoanDistribution();
  }

  Future<void> _fetchLoanDistribution() async {
    final String response = await rootBundle.loadString('backend/cibil_data.csv');
    final List<List<dynamic>> data = const CsvToListConverter().convert(response);

    // Initialize a map to count loan types
    Map<String, int> loanTypeCounts = {};

    // Iterate through the data to find the loan type for the given PAN
    for (var row in data) {
      if (row[1] == widget.panNumber) { // Check PAN number
        String loanType = row[4]; // Assuming loan type is in the fifth column
        loanTypeCounts[loanType] = (loanTypeCounts[loanType] ?? 0) + 1; // Count occurrences
      }
    }

    // Prepare the loan distribution data for the pie chart
    setState(() {
      loanDistribution = loanTypeCounts.entries.map((entry) {
        return PieChartSectionData(
          color: _getColorForLoanType(entry.key),
          value: entry.value.toDouble(),
          title: entry.key,
        );
      }).toList();
    });
  }

  Color _getColorForLoanType(String loanType) {
    // You can customize colors or use a color palette
    switch (loanType) {
      case 'Home Loan':
        return Colors.blue;
      case 'Personal Loan':
        return Colors.green;
      case 'Car Loan':
        return Colors.orange;
      case 'Credit Loan':
        return Colors.red;
      case 'Education Loan':
        return Colors.lime;
      default:
        return Colors.grey; // Default color for unknown loan types
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Analysis for ${widget.panNumber}"),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCibilScoreGauge(),
            SizedBox(height: 20),
            _buildPieChart(),
            SizedBox(height: 20),
            _buildBarChart(),
            SizedBox(height: 20),
            _buildDebtToIncomeGraph(),
          ],
        ),
      ),
    );
  }

  Widget _buildCibilScoreGauge() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("CIBIL Score", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: SfRadialGauge(
                axes: [
                  RadialAxis(
                    minimum: 300,
                    maximum: 900,
                    ranges: [
                      GaugeRange(startValue: 300, endValue: 550, color: Colors.red),
                      GaugeRange(startValue: 550, endValue: 650, color: Colors.orange),
                      GaugeRange(startValue: 650, endValue: 750, color: Colors.lightGreenAccent),
                      GaugeRange(startValue: 750, endValue: 900, color: Colors.green),
                    ],
                    pointers: [
                      NeedlePointer(
                        value: _animation.value,
                        needleLength: 0.8,
                        knobStyle: const KnobStyle(color: Colors.blue),
                      ),
                    ],
                    annotations: [
                      GaugeAnnotation(
                        widget: Text(
                          _animation.value.toStringAsFixed(0),
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        angle: 90,
                        positionFactor: 0.5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Loan Type Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: PieChart(PieChartData(sections: _getPieChartSections()))),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _getPieChartSections() {
    return loanDistribution; // Return the dynamically fetched loan distribution
  }

  Widget _buildBarChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Monthly EMI vs Income", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: BarChart(BarChartData(barGroups: _getBarChartGroups()))),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _getBarChartGroups() {
    return [
      BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 50000, color: Colors.blue)]),
      BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 20000, color: Colors.red)]),
    ];
  }

  Widget _buildDebtToIncomeGraph() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Debt-to-Income Ratio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: LineChart(LineChartData(lineBarsData: _getLineChartData()))),
          ],
        ),
      ),
    );
  }

  List<LineChartBarData> _getLineChartData() {
    return [
      LineChartBarData(
        spots: [
          FlSpot(0, 0.1),
          FlSpot(1, 0.2),
          FlSpot(2, 0.15),
          FlSpot(3, 0.3),
        ],
        isCurved: true,
        color: Colors.green,
      ),
    ];
  }
}
