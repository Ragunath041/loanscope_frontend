import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../auth/Login.dart';
import 'DashboardPage.dart';
import 'LoanPage.dart';
import 'EducationPage.dart';
import 'AnalysisPage.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:loanscope/services/local_database.dart';
import 'package:loanscope/services/prediction_service.dart';

class HomePage extends StatefulWidget {
  final String email;
  final String panNumber;
  final bool isAdmin;

  const HomePage({
    super.key,
    required this.email,
    required this.panNumber,
    required this.isAdmin,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double? userCibilScore;
  bool _isLoadingCibilScore = true;
  double _cibilScore = 0;
  bool _isEligible = false;
  bool _isLoadingMLInsights = true;
  Map<String, dynamic>? _defaultPrediction;
  Map<String, dynamic>? _loanScenario;
  final PredictionService _predictionService = PredictionService();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  bool _isBackendAvailable = false;
  String userName = '';
  String userLoanStatus = '';
  String userEmploymentType = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  Future<void> _initializeData() async {
    // Check backend availability
    _isBackendAvailable = await _predictionService.checkServerHealth();
    
    // Fetch user data in parallel
    await Future.wait([
      _fetchUserCibilScore(),
      _fetchMLInsights(),
    ]);
  }

  Future<void> _fetchUserCibilScore() async {
    try {
      setState(() {
        _isLoadingCibilScore = true;
      });

      // Try reading from backend directory first
      String csvData;
      try {
        csvData = await rootBundle.loadString('backend/cibil_data.csv');
        print("Successfully read CSV from backend directory");
      } catch (e) {
        print("Error reading from backend directory: $e");
        // Fallback to assets directory
        csvData = await rootBundle.loadString('assets/cibil_data.csv');
        print("Successfully read CSV from assets directory");
      }

      List<List<dynamic>> csvTable = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
        fieldDelimiter: ','
      ).convert(csvData);
      
      print("Total rows in CSV: ${csvTable.length}");
      
      // Find the row for this PAN
      final userRows = csvTable.where(
        (row) {
          if (row.length > 1) {
            String csvPan = row[1].toString().trim().toUpperCase();
            String searchPan = widget.panNumber.trim().toUpperCase();
            // Remove any quotes or extra spaces
            csvPan = csvPan.replaceAll('"', '').trim();
            searchPan = searchPan.replaceAll('"', '').trim();
            print("Comparing CSV PAN: '$csvPan' with search PAN: '$searchPan'");
            return csvPan == searchPan;
          }
          return false;
        }
      ).toList();

      print("Found ${userRows.length} matching rows");

      if (userRows.isEmpty) {
        throw Exception('PAN number not found in database');
      }

      // Get CIBIL score from the first matching row
      var cibilScore = double.tryParse(
        userRows[0][2].toString().replaceAll(RegExp(r'[^0-9.]'), '')
      ) ?? 0.0;

      setState(() {
        _cibilScore = cibilScore;
        _isLoadingCibilScore = false;
      });

      print("Successfully loaded CIBIL score: $_cibilScore");
    } catch (e) {
      print('Error fetching CIBIL score: $e');
      setState(() {
        _cibilScore = 0;
        _isLoadingCibilScore = false;
      });
    }
  }
  
  Future<void> _fetchMLInsights() async {
    if (widget.panNumber.isEmpty) return;
    
    setState(() {
      _isLoadingMLInsights = true;
    });
    
    try {
      // Get user profile data
      final userData = await _localDb.getUserProfile(widget.panNumber);
      if (userData == null) {
        throw 'User profile not found';
      }
      
      // Extract financial information
      final double monthlyIncome = double.tryParse(userData['monthlyIncome'] ?? '50000') ?? 50000;
      final double loanAmount = 300000; // Default loan amount for analysis
      final int tenureMonths = 36; // Default tenure for analysis
      final double interestRate = 10.0; // Default interest rate for analysis
      
      // Get default prediction if backend is available
      if (_isBackendAvailable) {
        try {
          _defaultPrediction = await _predictionService.predictDefaultProbability(
            cibilScore: _cibilScore,
            loanAmount: loanAmount,
            tenureMonths: tenureMonths,
            interestRate: interestRate,
            monthlyIncome: monthlyIncome,
          );
          
          // Get loan scenario recommendations
          _loanScenario = await _predictionService.getForecastScenarios(
            currentCibil: _cibilScore,
            monthlyIncome: monthlyIncome,
          );
        } catch (e) {
          print("Error from ML backend: $e");
          // Fall back to local predictions - use public methods
          _defaultPrediction = {
            'status': 'success',
            'note': 'Using fallback prediction (server unavailable)',
            'default_probability': _calculateDefaultProbability(
              cibilScore: _cibilScore,
              loanAmount: loanAmount,
              monthlyIncome: monthlyIncome,
            ),
            'risk_category': _calculateRiskCategory(_cibilScore),
          };
          
          _loanScenario = _generateFallbackScenarios(
            currentCibil: _cibilScore, 
            monthlyIncome: monthlyIncome,
          );
        }
      } else {
        // Use fallback predictions if backend is not available
        _defaultPrediction = {
          'status': 'success',
          'note': 'Using fallback prediction (server unavailable)',
          'default_probability': _calculateDefaultProbability(
            cibilScore: _cibilScore,
            loanAmount: loanAmount,
            monthlyIncome: monthlyIncome,
          ),
          'risk_category': _calculateRiskCategory(_cibilScore),
        };
        
        _loanScenario = _generateFallbackScenarios(
          currentCibil: _cibilScore, 
          monthlyIncome: monthlyIncome,
        );
      }
      
      setState(() {
        _isLoadingMLInsights = false;
      });
    } catch (e) {
      print("Error fetching ML insights: $e");
      setState(() {
        _isLoadingMLInsights = false;
      });
    }
  }
  
  // Helper method to calculate default probability when backend is unavailable
  double _calculateDefaultProbability({
    required double cibilScore,
    required double loanAmount,
    required double monthlyIncome,
  }) {
    // Base probability based on CIBIL score
    double defaultProbability;
    
    if (cibilScore >= 750) {
      defaultProbability = 5.0; // 5%
    } else if (cibilScore >= 650) {
      defaultProbability = 15.0; // 15%
    } else if (cibilScore >= 550) {
      defaultProbability = 30.0; // 30%
    } else {
      defaultProbability = 50.0; // 50%
    }
    
    // Adjust for loan amount to income ratio
    final double annualIncome = monthlyIncome * 12;
    final double loanToIncome = loanAmount / annualIncome;
    
    defaultProbability += loanToIncome * 10; // Higher ratio = higher risk
    
    // Cap at reasonable values
    return defaultProbability.clamp(1.0, 95.0);
  }
  
  // Helper method to determine risk category based on CIBIL score
  String _calculateRiskCategory(double cibilScore) {
    if (cibilScore >= 750) {
      return "Very Low Risk";
    } else if (cibilScore >= 700) {
      return "Low Risk";
    } else if (cibilScore >= 650) {
      return "Moderate Risk";
    } else if (cibilScore >= 600) {
      return "High Risk";
    } else {
      return "Very High Risk";
    }
  }
  
  // Helper method to generate loan scenarios when backend is unavailable
  Map<String, dynamic> _generateFallbackScenarios({
    required double currentCibil,
    required double monthlyIncome,
    double existingEmis = 0,
  }) {
    // Generate three simple scenarios
    const List<double> loanAmounts = [100000, 300000, 500000];
    const List<int> tenures = [12, 36, 60];
    const List<double> interestRates = [8.0, 10.0, 12.0];
    
    final List<Map<String, dynamic>> scenarios = [];
    
    // Generate just a few key scenarios instead of all combinations
    for (int i = 0; i < 3; i++) {
      final double loanAmount = loanAmounts[i];
      final int tenure = tenures[i];
      final double rate = interestRates[i];
      
      // Calculate EMI using existing method in PredictionService
      final double monthlyRate = rate / (12 * 100);
      final double emi = _calculateEmi(loanAmount, rate, tenure);
      
      // Calculate DTI
      final double dti = (existingEmis + emi) / monthlyIncome;
      
      // Estimate CIBIL impact based on DTI
      final double impact = -(dti * 50); // Higher DTI = more negative impact
      
      // Estimate default probability
      double defaultProb = 5.0; // Base 5%
      if (dti > 0.5) defaultProb = 40.0;
      else if (dti > 0.4) defaultProb = 25.0;
      else if (dti > 0.3) defaultProb = 15.0;
      
      // Determine risk category
      String riskCategory;
      if (defaultProb < 10) {
        riskCategory = "Very Low Risk";
      } else if (defaultProb < 20) {
        riskCategory = "Low Risk";
      } else if (defaultProb < 40) {
        riskCategory = "Moderate Risk";
      } else if (defaultProb < 60) {
        riskCategory = "High Risk";
      } else {
        riskCategory = "Very High Risk";
      }
      
      // Determine affordability
      String affordability;
      if (dti < 0.3) {
        affordability = "Highly Affordable";
      } else if (dti < 0.4) {
        affordability = "Affordable";
      } else if (dti < 0.5) {
        affordability = "Moderately Affordable";
      } else if (dti < 0.6) {
        affordability = "Stretching Budget";
      } else {
        affordability = "Not Affordable";
      }
      
      scenarios.add({
        'loan_amount': loanAmount,
        'tenure_months': tenure,
        'interest_rate': rate,
        'monthly_payment': emi,
        'cibil_impact': impact,
        'predicted_cibil': currentCibil + impact,
        'default_probability': defaultProb,
        'risk_category': riskCategory,
        'debt_to_income': dti * 100, // Convert to percentage
        'affordability_index': affordability
      });
    }
    
    // Sort by CIBIL impact (least negative first)
    scenarios.sort((a, b) => (b['cibil_impact'] as double).compareTo(a['cibil_impact'] as double));
    
    // Find "best" scenario
    Map<String, dynamic> bestScenario = scenarios.first;
    if (scenarios.length > 1) {
      // Choose the scenario with best DTI among the top 2 CIBIL impacts
      bestScenario = scenarios[0]['debt_to_income'] < scenarios[1]['debt_to_income'] ? scenarios[0] : scenarios[1];
    }
    
    return {
      'status': 'success',
      'note': 'Using fallback forecast (server unavailable)',
      'current_cibil': currentCibil,
      'scenarios': scenarios,
      'recommendation': {
        'message': 'Recommended loan scenario based on affordability and CIBIL impact',
        'recommended_scenario': bestScenario
      }
    };
  }
  
  // Utility to calculate EMI
  double _calculateEmi(double principal, double interestRate, int tenureMonths) {
    final double monthlyRate = interestRate / (12 * 100);
    final double emi = (principal * monthlyRate * _pow((1 + monthlyRate), tenureMonths)) / 
                      (_pow((1 + monthlyRate), tenureMonths) - 1);
    return emi;
  }
  
  // Helper for exponentiation (pow function)
  double _pow(double x, int y) {
    double result = 1.0;
    for (int i = 0; i < y; i++) {
      result *= x;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A82FB), Color(0xFFFC5C7D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top profile section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          widget.email.substring(0, 1).toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                          FadeInLeft(
                            duration: Duration(milliseconds: 800),
                            child: Text(
                              'Welcome',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          FadeInLeft(
                            duration: Duration(milliseconds: 1000),
              child: Text(
                              _shortenEmail(widget.email),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                                fontSize: 20,
                  fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Title and clock section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInUp(
                      duration: Duration(milliseconds: 1000),
                      child: Text(
                        "LoanScope",
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    SizedBox(height: 5),
                    FadeInUp(
                      duration: Duration(milliseconds: 1200),
                      child: Text(
                        "Financial management simplified",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content container
            Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 10),
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
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Main Features",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          SizedBox(height: 25),
                          
                          // Dashboard and Predict CIBIL row
                          Row(
                children: [
                              Expanded(
                                child: _buildFeatureCard(
                                  'Dashboard',
                                  Icons.dashboard_rounded,
                                  Color(0xFF6A82FB),
                                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DashboardPage(panNumber: widget.panNumber),
                      ),
                    );
                                  },
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: _buildFeatureCard(
                                  'Predict CIBIL',
                                  Icons.trending_up_rounded,
                                  Color(0xFFFC5C7D),
                                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoanPage(panNumber: widget.panNumber),
                      ),
                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 25),
                          
                          // Education and Analytics row
                          Row(
                            children: [
                              Expanded(
                                child: _buildFeatureCard(
                                  'Education',
                                  Icons.school_rounded,
                                  Color(0xFF00B4DB),
                                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EducationPage(isAdmin: widget.isAdmin),
                      ),
                    );
                                  },
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: _buildFeatureCard(
                                  'Analytics',
                                  Icons.analytics_rounded,
                                  Color(0xFFFF8C00),
                                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnalysisPage(
                          panNumber: widget.panNumber,
                          cibilScore: userCibilScore ?? 750,
                        ),
                      ),
                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 30),
                          Text(
                            "Quick Info",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          SizedBox(height: 20),
                          
                          // Quick info card for CIBIL score
                          _buildQuickInfoCard(
                            "Your CIBIL Score",
                            _isLoadingCibilScore ? "Loading..." : "${_cibilScore.toInt()}",
                            _isLoadingCibilScore ? "" : _getScoreDescription(_cibilScore),
                            Icons.credit_score_rounded,
                            Color(0xFF6A82FB),
                          ),
                          
                          SizedBox(height: 15),
                          
                          // Quick info card for default risk
                          if (!_isLoadingMLInsights && _defaultPrediction != null)
                            _buildQuickInfoCard(
                              "Default Risk",
                              "${(_defaultPrediction!['default_probability'] as double).toStringAsFixed(1)}%",
                              _defaultPrediction!['risk_category'] as String,
                              Icons.security_rounded,
                              Color(0xFFFF8C00),
                            ),
                          
                          if (!_isLoadingMLInsights && _defaultPrediction != null)
                            SizedBox(height: 15),
                          
                          // Loan recommendation card
                          if (!_isLoadingMLInsights && _loanScenario != null && 
                              _loanScenario!['recommendation'] != null)
                            _buildLoanRecommendationCard(),
                          
                          if (!_isLoadingMLInsights && _loanScenario != null)
                            SizedBox(height: 15),
                          
                          // Quick info card for user type
                          _buildQuickInfoCard(
                            "Account Type",
                            widget.isAdmin ? "Admin" : "User",
                            widget.isAdmin ? "Full access" : "Standard access",
                            Icons.badge_outlined,
                            Color(0xFFFC5C7D),
                          ),
                          
                          SizedBox(height: 25),
                          // Logout button
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Color(0xFFFC5C7D),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: BorderSide(color: Color(0xFFFC5C7D)),
                                ),
                              ),
                              onPressed: _logout,
                              icon: Icon(Icons.logout_rounded),
                              label: Text(
                                'Logout',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                ],
              ),
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
  
  Widget _buildLoanRecommendationCard() {
    final recommendation = _loanScenario!['recommendation']['recommended_scenario'];
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF00B4DB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 30,
                  color: Color(0xFF00B4DB),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Text(
                  "Recommended Loan Option",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Divider(),
          SizedBox(height: 10),
          _buildLoanDetailRow("Amount", "₹${recommendation['loan_amount'].toInt()}"),
          _buildLoanDetailRow("Tenure", "${recommendation['tenure_months']} months"),
          _buildLoanDetailRow("Interest", "${recommendation['interest_rate']}%"),
          _buildLoanDetailRow("Monthly EMI", "₹${recommendation['monthly_payment'].toInt()}"),
          _buildLoanDetailRow("Affordability", "${recommendation['affordability_index']}"),
          _buildLoanDetailRow("CIBIL Impact", "${recommendation['cibil_impact'].toStringAsFixed(1)} points"),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00B4DB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoanPage(panNumber: widget.panNumber),
                  ),
                );
              },
              child: Text(
                'Explore More Options',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoanDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  String _shortenEmail(String email) {
    if (email.length > 20) {
      final atIndex = email.indexOf('@');
      if (atIndex > 0) {
        return email.substring(0, min(atIndex, 15)) + '...';
      }
    }
    return email;
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }

  String _getScoreDescription(double score) {
    if (score > 790) return 'Excellent';
    if (score >= 771 && score <= 790) return 'Good';
    if (score >= 731 && score <= 770) return 'Fair';
    if (score >= 681 && score <= 730) return 'Average';
    return 'Poor';
  }

  Color _getScoreColor(String description) {
    switch (description) {
      case 'Poor':
        return Colors.red;
      case 'Fair':
        return Colors.orange;
      case 'Good':
        return Colors.green;
      case 'Excellent':
        return Colors.teal;
      case 'Average':
        return Colors.amber;
      case 'Very Low Risk':
        return Colors.teal;
      case 'Low Risk':
        return Colors.green;
      case 'Moderate Risk':
        return Colors.amber;
      case 'High Risk':
        return Colors.orange;
      case 'Very High Risk':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFeatureCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: FadeInUp(
        duration: Duration(milliseconds: 1200),
        child: AspectRatio(
          aspectRatio: 1,
      child: Container(
            padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
              color: Colors.white,
          borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: color.withOpacity(0.05),
                width: 1,
              ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: color,
                  ),
                ),
                Spacer(),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickInfoCard(String title, String value, String subtitle, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        if (title == "Your CIBIL Score") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardPage(panNumber: widget.panNumber),
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Color(0xFF333333),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              SizedBox(height: 5),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: _getScoreColor(subtitle),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      // Clear local session data
      await _localDb.close(); // Close Hive boxes
      
      // Navigate to login page
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
}
