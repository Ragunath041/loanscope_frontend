import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:geolocator/geolocator.dart';
import 'package:loanscope/pages/FDCardPage.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:loanscope/services/prediction_service.dart';
import 'dart:math' as math;
import 'package:loanscope/widgets/bank_map.dart';

class LoanPage extends StatefulWidget {
  final String panNumber;
  const LoanPage({
    super.key,
    required this.panNumber,
  });
  @override
  _LoanPageState createState() => _LoanPageState();
}

class _LoanPageState extends State<LoanPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _predictionResult;
  bool? _isEligible;
  Map<String, dynamic>? _analysis;
  String? _calculatedInterestRate;
  List<Map<String, dynamic>>? _loanEligibility;
  final _loanAmountController = TextEditingController();
  final _tenureController = TextEditingController();
  final _onTimePaymentsController = TextEditingController();
  final mapController = flutter_map.MapController();
  Position? currentPosition;
  StreamSubscription<Position>? positionStream;
  bool _isLoadingLocations = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoadingLocations = true);
    try {
      // Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permissions are required to find nearby banks'),
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Enable',
                onPressed: () => _initializeLocation(),
              ),
            ),
          );
          setState(() => _isLoadingLocations = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in settings to use this feature.'),
            duration: Duration(seconds: 5),
          ),
        );
        setState(() => _isLoadingLocations = false);
        return;
      }

      // Get the most accurate position possible
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 15),
      );
      
      print("EXACT Current Position: ${position.latitude}, ${position.longitude}");
      
      setState(() {
        currentPosition = position;
        _isLoadingLocations = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location updated successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Location error: $e");
      setState(() => _isLoadingLocations = false);
      
      // Give user more specific error info
      String errorMessage = 'Error getting location';
      if (e.toString().contains('TIMEOUT')) {
        errorMessage = 'Location request timed out. Please try again.';
      } else if (e.toString().contains('SERVICE_STATUS_DISABLED')) {
        errorMessage = 'Location services are disabled. Please enable GPS.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _initializeLocation(),
          ),
              ),
            );
          }
  }

  // Use the new BankMap widget instead of building map functionality directly
  Widget _buildBankMap([String bankName = '']) {
    return BankMap(
      currentPosition: currentPosition,
      bankName: bankName,
      isLoading: _isLoadingLocations,
    );
  }

  double _calculateMonthlyEMI() {
    double loanAmount = double.tryParse(_loanAmountController.text) ?? 0;
    int tenure = int.tryParse(_tenureController.text) ?? 1;
    return loanAmount / tenure;
  }

  int _calculateLatePayments() {
    int tenure = int.tryParse(_tenureController.text) ?? 0;
    int onTimePayments = int.tryParse(_onTimePaymentsController.text) ?? 0;
    return tenure - onTimePayments;
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
                    'Loan Prediction',
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
                    "Predict your CIBIL score and check loan eligibility",
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
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInputField(
                        'Loan Amount',
                        _loanAmountController,
                        'Enter loan amount',
                        Icons.money,
                      ),
                      SizedBox(height: 15),
                      _buildInputField(
                        'Loan Tenure (months)',
                        _tenureController,
                        'Enter loan tenure',
                        Icons.access_time,
                      ),
                      SizedBox(height: 15),
                      _buildInputField(
                        'On-time Payments',
                        _onTimePaymentsController,
                        'Number of on-time payments',
                        Icons.check_circle,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _predictCibilScore,
                        style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF6A82FB),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                          shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                          ),
                                  elevation: 2,
                        ),
                        child: _isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                            : Text(
                                'Predict CIBIL Score',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                        
                SizedBox(height: 30),
                if (_predictionResult != null)
                  FadeInUp(
                    duration: Duration(milliseconds: 1000),
                    child: _buildResultsCard(),
                  ),
                if (_loanEligibility != null && _loanEligibility!.isNotEmpty) ...[
                  SizedBox(height: 30),
                          FadeInUp(
                            duration: Duration(milliseconds: 1200),
                            child: Text(
                    'Recommended Banks & Loans',
                    style: GoogleFonts.poppins(
                                color: Color(0xFF333333),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                  SizedBox(height: 15),
                          FadeInUp(
                            duration: Duration(milliseconds: 1400),
                            child: _buildBankRecommendations(),
                          ),
                ],
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
  Widget _buildInputField(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return FadeInLeft(
      duration: Duration(milliseconds: 800),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Color(0xFF6A82FB).withOpacity(0.2),
            width: 1,
        ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        margin: EdgeInsets.only(bottom: 5),
        child: TextFormField(
          controller: controller,
          style: GoogleFonts.poppins(color: Color(0xFF333333)),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(color: Color(0xFF666666)),
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Color(0xFF999999)),
            prefixIcon: Icon(icon, color: Color(0xFF6A82FB)),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
  Widget _buildResultsCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF6A82FB).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCibilScoreGauge(),
          SizedBox(height: 30),
          if (_calculatedInterestRate != null) 
            _buildInterestRateCard(),
          SizedBox(height: 30),
          if (_isEligible != null)
            _buildEligibilityStatus(),
        ],
      ),
    );
  }
  Widget _buildCibilScoreGauge() {
    final score = int.tryParse(_predictionResult ?? '0') ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Predicted CIBIL Score',
          style: GoogleFonts.poppins(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 300, end: score.toDouble()),
            duration: Duration(seconds: 2),
            builder: (context, value, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SfRadialGauge(
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
                            value: value,
                            needleLength: 0.8,
                            enableAnimation: true,
                            animationType: AnimationType.ease,
                            needleColor: _getScoreColor(value.toInt()),
                            knobStyle: KnobStyle(
                          color: _getScoreColor(value.toInt()),
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
                                  value.toInt().toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: _getScoreColor(value.toInt()),
                    ),
                  ),
                  Text(
                                  _getScoreLabel(value.toInt()),
                    style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                      color: _getScoreColor(value.toInt()),
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
                ],
              );
            },
          ),
        ),
      ],
    );
  }
  Widget _buildInterestRateCard() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Color(0xFF6A82FB).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Interest Rate',
                style: GoogleFonts.poppins(
                  color: Color(0xFF666666),
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 5),
              Text(
                '$_calculatedInterestRate%',
                style: GoogleFonts.poppins(
                  color: Color(0xFF6A82FB),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Icon(
            Icons.percent_rounded,
            color: Color(0xFF6A82FB),
            size: 40,
          ),
        ],
      ),
    );
  }
  Widget _buildEligibilityStatus() {
    bool isEligible = _isEligible ?? false;
    String eligibilityStatus = isEligible ? "Eligible" : "Not Eligible";
    Color statusColor = isEligible ? Colors.green : Colors.red;
    
    String riskLevel = "High";
    if (_analysis != null && _analysis!.containsKey('risk_level')) {
      riskLevel = _analysis!['risk_level'] as String;
    }
    
    Color riskColor = Colors.red;
    if (riskLevel == "Low") {
      riskColor = Colors.green;
    } else if (riskLevel == "Moderate") {
      riskColor = Colors.orange;
    }
    
    List<Widget> scoreComponents = [];
    if (_analysis != null && _analysis!.containsKey('score_components')) {
      final components = _analysis!['score_components'] as Map<String, dynamic>;
      components.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final score = value['score'];
          final maxScore = value['max_score'];
          final percentage = value['percentage'];
          
          String displayKey = key.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
          
          scoreComponents.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayKey,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "$score/$maxScore",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getScoreComponentColor(percentage),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: _getScoreComponentColor(percentage),
                ),
                SizedBox(height: 10),
              ],
            ),
          );
        }
      });
    }
    
    // Get recommendations
    List<String> recommendations = [];
    if (_analysis != null && _analysis!.containsKey('recommendations')) {
      recommendations = List<String>.from(_analysis!['recommendations']);
    } else {
      recommendations = [
        "Ensure timely payment of all EMIs and credit card bills",
        "Keep credit utilization below 30%",
        "Avoid multiple loan applications in short periods"
      ];
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Loan Eligibility Status",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                eligibilityStatus,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Risk Level",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: riskColor),
              ),
              child: Text(
                riskLevel,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: riskColor,
                ),
              ),
            ),
          ],
        ),
        
        if (scoreComponents.isNotEmpty) ...[
          SizedBox(height: 20),
          Text(
            "Score Components",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 10),
          ...scoreComponents,
        ],
        
        SizedBox(height: 20),
        Text(
          "Recommendations",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 10),
        ...recommendations.map((rec) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  rec,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }
  
  Color _getScoreComponentColor(dynamic percentage) {
    int score = percentage is int ? percentage : (percentage as double).toInt();
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  Widget _buildBankRecommendations() {
    return Column(
      children: _loanEligibility!.map((bank) {
        return Padding(
          padding: EdgeInsets.only(bottom: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Color(0xFF6A82FB).withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ExpansionTile(
              leading: Container(
                width: 60,
                height: 60,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  bank['logo'],
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.account_balance,
                        color: Color(0xFF6A82FB),
                        size: 30,
                      ),
                    );
                  },
                ),
              ),
              title: Text(
                bank['bank'],
                style: GoogleFonts.poppins(
                  color: Color(0xFF333333),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Interest: ${bank['interest']}',
                style: GoogleFonts.poppins(
                  color: Color(0xFF666666),
                  fontSize: 14,
                ),
              ),
              iconColor: Color(0xFF6A82FB),
              collapsedIconColor: Color(0xFF6A82FB),
              tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Padding(
                  padding: EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLoanDetail('Available Loans', 
                        bank['loans'].join(', ')),
                      SizedBox(height: 10),
                      _buildLoanDetail('Processing Fee', 
                        bank['processing_fee']),
                      SizedBox(height: 10),
                      _buildLoanDetail('Maximum Amount', 
                        bank['max_amount']),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          _showBankBranchesDialog(bank['bank']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6A82FB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'View Nearest Branches',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  Widget _buildLoanDetail(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            '$label:',
            style: GoogleFonts.poppins(
              color: Color(0xFF666666),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Color(0xFF333333),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
  void _showBankBranchesDialog(String bankName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nearby $bankName Branches', 
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: currentPosition == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Location permission is required',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _initializeLocation().then((_) {
                            if (currentPosition != null) {
                              _showBankBranchesDialog(bankName);
                            }
                          });
                        },
                        child: Text('Enable Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6A82FB),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: _buildBankMap(bankName),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.my_location, color: Colors.blue, size: 20),
                            SizedBox(width: 4),
                            Text('Your location',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.account_balance, color: Color(0xFF6A82FB), size: 20),
                            SizedBox(width: 4),
                            Text('Bank branch',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFF6A82FB),
              ),
            ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 750) return Colors.green;
    if (score >= 650) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(int score) {
    if (score >= 750) return 'Excellent';
    if (score >= 650) return 'Good';
    if (score >= 550) return 'Fair';
    return 'Poor';
  }

  void _calculateLoanEligibility(int score) {
    _loanEligibility = [];
    if (score >= 750) {
  _loanEligibility!.addAll([
    {
      'bank': 'SBI',
      'logo': 'assets/images/banks/sbi.png',
      'loans': ['Home Loan', 'Personal Loan', 'Car Loan', 'Business Loan'],
      'interest': '8.0% - 10.0%',
      'processing_fee': '0.5% - 1.0%',
      'max_amount': '₹1,00,00,000'
    },
    {
      'bank': 'HDFC',
      'logo': 'assets/images/banks/hdfc.png',
      'loans': ['Home Loan', 'Personal Loan', 'Car Loan'],
      'interest': '8.5% - 10.5%',
      'processing_fee': '0.75% - 1.25%',
      'max_amount': '₹75,00,000'
    },
    {
      'bank': 'Axis Bank',
      'logo': 'assets/images/banks/axis.png',
      'loans': ['Home Loan', 'Personal Loan', 'Business Loan', 'Education Loan'],
      'interest': '8.5% - 11.5%',
      'processing_fee': '1.0% - 1.5%',
      'max_amount': '₹75,00,000'
    },
    {
      'bank': 'Bank of Baroda',
      'logo': 'assets/images/banks/bob.png',
      'loans': ['Home Loan', 'Car Loan', 'Gold Loan', 'Education Loan'],
      'interest': '7.9% - 9.5%',
      'processing_fee': '0.5% - 1.2%',
      'max_amount': '₹90,00,000'
    },
    {
      'bank': 'Canara Bank',
      'logo': 'assets/images/banks/canara.png',
      'loans': ['Home Loan', 'Personal Loan', 'Business Loan', 'Education Loan'],
      'interest': '7.75% - 9.25%',
      'processing_fee': '0.25% - 1.0%',
      'max_amount': '₹80,00,000'
    },
    {
      'bank': 'Citibank',
      'logo': 'assets/images/banks/citibank.png',
      'loans': ['Home Loan', 'Personal Loan', 'Car Loan'],
      'interest': '9.0% - 12.0%',
      'processing_fee': '1.0% - 2.0%',
      'max_amount': '₹50,00,000'
    },
    {
      'bank': 'DBS Bank',
      'logo': 'assets/images/banks/dbs.png',
      'loans': ['Home Loan', 'Personal Loan', 'Business Loan'],
      'interest': '8.2% - 10.5%',
      'processing_fee': '0.5% - 1.25%',
      'max_amount': '₹85,00,000'
    },
    {
      'bank': 'IDFC First Bank',
      'logo': 'assets/images/banks/idfc.png',
      'loans': ['Home Loan', 'Personal Loan', 'Education Loan'],
      'interest': '9.5% - 12.5%',
      'processing_fee': '1.0% - 1.5%',
      'max_amount': '₹60,00,000'
    },
    {
      'bank': 'Indian Bank',
      'logo': 'assets/images/banks/indian.png',
      'loans': ['Home Loan', 'Personal Loan', 'Business Loan'],
      'interest': '7.75% - 9.0%',
      'processing_fee': '0.5% - 1.0%',
      'max_amount': '₹70,00,000'
    },
    {
      'bank': 'IndusInd Bank',
      'logo': 'assets/images/banks/indusind.png',
      'loans': ['Home Loan', 'Personal Loan', 'Car Loan'],
      'interest': '8.5% - 11.0%',
      'processing_fee': '1.0% - 1.75%',
      'max_amount': '₹65,00,000'
    },
    {
      'bank': 'Kotak Mahindra Bank',
      'logo': 'assets/images/banks/kotak.png',
      'loans': ['Home Loan', 'Personal Loan', 'Business Loan', 'Car Loan'],
      'interest': '8.3% - 10.8%',
      'processing_fee': '0.75% - 1.5%',
      'max_amount': '₹90,00,000'
    },
    {
      'bank': 'UCO Bank',
      'logo': 'assets/images/banks/uco.png',
      'loans': ['Home Loan', 'Personal Loan', 'Education Loan'],
      'interest': '7.9% - 9.25%',
      'processing_fee': '0.5% - 1.25%',
      'max_amount': '₹50,00,000'
    },
    {
      'bank': 'Union Bank of India',
      'logo': 'assets/images/banks/unionbank.png',
      'loans': ['Home Loan', 'Business Loan', 'Gold Loan'],
      'interest': '7.75% - 9.5%',
      'processing_fee': '0.5% - 1.2%',
      'max_amount': '₹75,00,000'
    },
    {
      'bank': 'Yes Bank',
      'logo': 'assets/images/banks/yesbank.png',
      'loans': ['Home Loan', 'Personal Loan', 'Car Loan', 'Business Loan'],
      'interest': '8.9% - 11.5%',
      'processing_fee': '1.0% - 1.5%',
      'max_amount': '₹70,00,000'
    },
    {
      'bank': 'ICICI',
      'logo': 'assets/images/banks/icici.png',
      'loans': ['Personal Loan', 'Business Loan', 'Education Loan'],
      'interest': '9.0% - 11.0%',
      'processing_fee': '1.0% - 1.5%',
      'max_amount': '₹50,00,000'
    },
  ]);
} else if (score >= 650 && score <= 749) {
  _loanEligibility!.addAll([
    {
      'bank': 'Axis Bank',
      'logo': 'assets/images/banks/axis.png',
      'loans': ['Personal Loan', 'Car Loan'],
      'interest': '11.0% - 13.0%',
      'processing_fee': '1.5% - 2.0%',
      'max_amount': '₹30,00,000'
    },
    {
      'bank': 'HDFC Bank',
      'logo': 'assets/images/banks/hdfc.png',
      'loans': ['Personal Loan', 'Car Loan'],
      'interest': '10.0% - 12.0%',
      'processing_fee': '1.5% - 2.0%',
      'max_amount': '₹30,00,000'
    },
    {
      'bank': 'Kotak',
      'logo': 'assets/images/banks/kotak.png',
      'loans': ['Personal Loan'],
      'interest': '12.0% - 14.0%',
      'processing_fee': '1.75% - 2.25%',
      'max_amount': '₹25,00,000'
    },
    {
      'bank': 'Federal Bank',
      'logo': 'assets/images/banks/federal.png',
      'loans': ['Personal Loan', 'Car Loan'],
      'interest': '11.5% - 13.5%',
      'processing_fee': '1.5% - 2.0%',
      'max_amount': '₹20,00,000'
    },
    {
      'bank': 'IDBI Bank',
      'logo': 'assets/images/banks/idbi.png',
      'loans': ['Personal Loan', 'Education Loan'],
      'interest': '11.0% - 13.0%',
      'processing_fee': '1.0% - 1.75%',
      'max_amount': '₹25,00,000'
    },
  ]);
} else if (score >= 581 && score <= 649) {
  _loanEligibility!.addAll([
    {
      'bank': 'IndusInd',
      'logo': 'assets/images/banks/indusind.png',
      'loans': ['Personal Loan'],
      'interest': '14.0% - 16.0%',
      'processing_fee': '2.0% - 2.5%',
      'max_amount': '₹15,00,000'
    },
    {
      'bank': 'RBL Bank',
      'logo': 'assets/images/banks/rbl.png',
      'loans': ['Personal Loan'],
      'interest': '14.5% - 16.5%',
      'processing_fee': '2.0% - 2.75%',
      'max_amount': '₹10,00,000'
    },
    {
      'bank': 'Bandhan Bank',
      'logo': 'assets/images/banks/bandhan.png',
      'loans': ['Personal Loan'],
      'interest': '13.5% - 15.5%',
      'processing_fee': '1.75% - 2.25%',
      'max_amount': '₹12,00,000'
    },
    {
      'bank': 'Tata Capital',
      'logo': 'assets/images/banks/tatacapital.png',
      'loans': ['Personal Loan'],
      'interest': '14.0% - 16.0%',
      'processing_fee': '2.0% - 2.5%',
      'max_amount': '₹15,00,000'
      },
    ]);
    } else {
      
      _buildLoanEligibilityInfo();
    }
  }

  Future<void> _predictCibilScore() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _predictionResult = null;
      _analysis = null;
      _calculatedInterestRate = null;
      _loanEligibility = null;
    });
    
    try {
      final predictionService = PredictionService();
      final double loanAmount = double.parse(_loanAmountController.text);
      final int tenure = int.parse(_tenureController.text);
      final double monthlyEMI = _calculateMonthlyEMI();
      final int onTimePayments = int.parse(_onTimePaymentsController.text);
      final int latePayments = _calculateLatePayments();
      
      final result = await predictionService.predictCibilScore(
        panNumber: widget.panNumber,
        loanAmount: loanAmount,
        tenure: tenure,
        monthlyEMI: monthlyEMI,
        onTimePayments: onTimePayments,
        latePayments: latePayments,
      );
      
      setState(() {
        final dynamic rawScore = result['predicted_score'];
        if (rawScore is int) {
          _predictionResult = rawScore.toString();
        } else if (rawScore is double) {
          _predictionResult = rawScore.toInt().toString();
        } else {
          _predictionResult = "0";
          print("Unexpected score type: ${rawScore.runtimeType}");
        }
        
        _isEligible = result['is_eligible'] as bool?;
        _analysis = result['analysis'] as Map<String, dynamic>?;
        
        double baseRate = 8.0;
        int cibilScore = int.tryParse(_predictionResult!) ?? 0;
        
        if (cibilScore < 600) {
          baseRate += 10.0;
        } else if (cibilScore < 650) {
          baseRate += 6.0;
        } else if (cibilScore < 750) {
          baseRate += 3.0;
        }
        
        baseRate += (latePayments * 0.5);
        _calculatedInterestRate = (baseRate > 24.0 ? 24.0 : baseRate).toStringAsFixed(2);
        _calculateLoanEligibility(cibilScore);
      });
      
      print('Predicted Score: $_predictionResult');
      print('Is Eligible: $_isEligible');
      print('Analysis: $_analysis');
    } catch (e) {
      print('Error predicting CIBIL score: $e');
      setState(() {
        _predictionResult = "Error occurred";
        _isEligible = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildLoanEligibilityInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing eligibility sections...
        
        // Add a button to navigate to FD Card Page
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FDCardPage()),
            );
          },
          child: Text('Learn About FD Card'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6A82FB), // Customize button color
          ),
        ),
      ],
    );
  }

}
