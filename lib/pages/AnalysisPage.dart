import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:csv/csv.dart'; // For CSV parsing
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

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
        String loanType = row[4].toString(); // Assuming loan type is in the fifth column
        if (loanType.isNotEmpty) {
          loanTypeCounts[loanType] = (loanTypeCounts[loanType] ?? 0) + 1; // Count occurrences
        }
      }
    }

    // Prepare the loan distribution data for the pie chart
    setState(() {
      loanDistribution = loanTypeCounts.entries.map((entry) {
        return PieChartSectionData(
          color: _getColorForLoanType(entry.key),
          value: entry.value.toDouble(),
          title: entry.key,
          radius: 50,
          titleStyle: GoogleFonts.poppins(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: Colors.white,
          ),
        );
      }).toList();
      
      // If no data, add a placeholder
      if (loanDistribution.isEmpty) {
        loanDistribution = [
          PieChartSectionData(
            color: Colors.grey.shade300,
            value: 100,
            title: 'No Data',
            radius: 50,
            titleStyle: GoogleFonts.poppins(
              fontSize: 12, 
              fontWeight: FontWeight.bold, 
              color: Colors.grey.shade700,
            ),
          ),
        ];
      }
    });
  }

  Color _getColorForLoanType(String loanType) {
    // You can customize colors or use a color palette
    switch (loanType) {
      case 'Home Loan':
        return Color(0xFF6A82FB);
      case 'Personal Loan':
        return Color(0xFFFC5C7D);
      case 'Car Loan':
        return Color(0xFF00B4DB);
      case 'GOLD LOAN':
        return Color(0xFFFFB900);
      case 'Education Loan':
        return Color(0xFF1FDA9A);
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A82FB), Color(0xFFFC5C7D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Text(
                      'Financial Analysis',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 40), // Balance layout for center title
                  ],
                ),
              ),
              
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: FadeInDown(
                  duration: Duration(milliseconds: 600),
                  child: Text(
                    "Detailed analysis of your financial health and credit score.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
              
              // Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 20),
                  padding: EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeInUp(
                          duration: Duration(milliseconds: 600),
                          child: Text(
                            "CIBIL Score",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                        FadeInUp(
                          duration: Duration(milliseconds: 800),
                          child: _buildCibilScoreGauge(),
                        ),
                        SizedBox(height: 25),
                        FadeInUp(
                          duration: Duration(milliseconds: 1000),
                          child: Text(
                            "Loan Distribution",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                        FadeInUp(
                          duration: Duration(milliseconds: 1200),
                          child: _buildPieChart(),
                        ),
                        SizedBox(height: 25),
                        FadeInUp(
                          duration: Duration(milliseconds: 1400),
                          child: Text(
                            "Monthly EMI vs Income",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                        FadeInUp(
                          duration: Duration(milliseconds: 1600),
                          child: _buildBarChart(),
                        ),
                        SizedBox(height: 25),
                        FadeInUp(
                          duration: Duration(milliseconds: 1800),
                          child: Text(
                            "Debt-to-Income Ratio",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ),
                        SizedBox(height: 15),
                        FadeInUp(
                          duration: Duration(milliseconds: 2000),
                          child: _buildDebtToIncomeGraph(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCibilScoreGauge() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: _getCibilScoreColor(widget.cibilScore).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 200,
            child: SfRadialGauge(
              enableLoadingAnimation: true,
              animationDuration: 2000,
              axes: [
                RadialAxis(
                  minimum: 300,
                  maximum: 900,
                  ranges: [
                    GaugeRange(startValue: 300, endValue: 550, color: Colors.red),
                    GaugeRange(startValue: 550, endValue: 650, color: Colors.orange),
                    GaugeRange(startValue: 650, endValue: 750, color: Colors.yellow),
                    GaugeRange(startValue: 750, endValue: 900, color: Colors.green),
                  ],
                  pointers: [
                    NeedlePointer(
                      value: _animation.value,
                      needleLength: 0.8,
                      enableAnimation: true,
                      animationType: AnimationType.ease,
                      needleColor: _getCibilScoreColor(widget.cibilScore),
                      knobStyle: KnobStyle(
                        color: _getCibilScoreColor(widget.cibilScore),
                        knobRadius: 0.1,
                        borderColor: Colors.white,
                        borderWidth: 0.05,
                      ),
                    ),
                  ],
                  annotations: [
                    GaugeAnnotation(
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _animation.value.toStringAsFixed(0),
                            style: GoogleFonts.poppins(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: _getCibilScoreColor(widget.cibilScore),
                            ),
                          ),
                          Text(
                            _getCibilScoreCategory(widget.cibilScore),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _getCibilScoreColor(widget.cibilScore),
                            ),
                          ),
                        ],
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
    );
  }

  Color _getCibilScoreColor(double score) {
    if (score > 790) return Colors.green;
    if (score >= 731) return Colors.lightGreen;
    if (score >= 650) return Colors.yellow;
    if (score >= 550) return Colors.orange;
    return Colors.red;
  }

  String _getCibilScoreCategory(double score) {
    if (score > 790) return "Excellent";
    if (score >= 731) return "Good";
    if (score >= 650) return "Fair";
    if (score >= 550) return "Average";
    return "Poor";
  }

  Widget _buildPieChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Color(0xFF6A82FB).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200, 
            child: PieChart(
              PieChartData(
                sections: loanDistribution,
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                startDegreeOffset: 180,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 16.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: _buildLegend(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLegend() {
    List<Widget> legendItems = [];
    
    for (var section in loanDistribution) {
      if (section.title != 'No Data') {
        legendItems.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: section.color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6),
              Text(
                section.title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        );
      }
    }
    
    return legendItems;
  }

  Widget _buildBarChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Color(0xFFFC5C7D).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200, 
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 60000,
                barGroups: _getBarChartGroups(),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 10000,
                  checkToShowHorizontalLine: (value) => value % 10000 == 0,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        String text = '';
                        if (value == 0) text = 'Income';
                        if (value == 1) text = 'EMI';
                        
                        return Text(
                          text,
                          style: GoogleFonts.poppins(
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        String text = '';
                        if (value == 0) text = '0';
                        if (value == 20000) text = '20K';
                        if (value == 40000) text = '40K';
                        if (value == 60000) text = '60K';
                        
                        return Text(
                          text,
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String title = groupIndex == 0 ? 'Income' : 'EMI';
                      return BarTooltipItem(
                        '$title\n₹${rod.toY.toStringAsFixed(0)}',
                        GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _getBarChartGroups() {
    return [
      BarChartGroupData(
        x: 0, 
        barRods: [
          BarChartRodData(
            toY: 50000, 
            color: Color(0xFF6A82FB),
            width: 30,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          )
        ]
      ),
      BarChartGroupData(
        x: 1, 
        barRods: [
          BarChartRodData(
            toY: 20000, 
            color: Color(0xFFFC5C7D),
            width: 30,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          )
        ]
      ),
    ];
  }

  Widget _buildDebtToIncomeGraph() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Color(0xFF00B4DB).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200, 
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        String text = '';
                        if (value.toInt() == 0) text = 'Q1';
                        if (value.toInt() == 1) text = 'Q2';
                        if (value.toInt() == 2) text = 'Q3';
                        if (value.toInt() == 3) text = 'Q4';
                        
                        return Text(
                          text,
                          style: GoogleFonts.poppins(
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 3,
                minY: 0,
                maxY: 0.5,
                lineBarsData: _getLineChartData(),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipMargin: 8,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(2)}',
                          GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(0xFF00B4DB),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 5),
              Text(
                'Debt-to-Income Ratio',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'The ideal debt-to-income ratio should be below 0.35',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
        color: Color(0xFF00B4DB),
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: Color(0xFF00B4DB).withOpacity(0.1),
        ),
      ),
    ];
  }
}
