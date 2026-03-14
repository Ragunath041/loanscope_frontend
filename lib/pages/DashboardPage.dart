import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:math';

class DashboardPage extends StatefulWidget {
  final String panNumber;
  const DashboardPage({Key? key, required this.panNumber}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      print("Searching for PAN: ${widget.panNumber}");
      
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
      print("CSV Data first few rows:");
      for (var i = 0; i < min(5, csvTable.length); i++) {
        print("Row $i: ${csvTable[i].join(', ')}");
      }
      
      // Find all rows for this PAN
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
        throw Exception('PAN number ${widget.panNumber} not found in database');
      }

      // Initialize loan lists
      List<Map<String, dynamic>> goldLoans = [];
      Map<String, dynamic>? personalLoan;
      Map<String, dynamic>? carLoans;
      Map<String, dynamic>? homeLoans;
      Map<String, dynamic>? educationLoans;

      // Process all loans
      for (var row in userRows) {
        String loanType = row[4].toString().trim().toUpperCase();
        
        // Convert loan amounts to numeric values
        double sanctionedAmount = double.tryParse(row[5].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        double currentAmount = double.tryParse(row[6].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        
        Map<String, dynamic> loanDetail = {
          'sanctionedAmount': sanctionedAmount,
          'currentAmount': currentAmount,
        };

        switch (loanType) {
          case 'GOLD LOAN':
            goldLoans.add(loanDetail);
            break;
          case 'CAR LOAN':
            carLoans = loanDetail;
            break;
          case 'PERSONAL LOAN':
            personalLoan = loanDetail;
            break;
          case 'HOME LOAN':
            homeLoans = loanDetail;
            break;
          case 'EDUCATION LOAN':
            educationLoans = loanDetail;
            break;
        }
      }

      // Clean and parse the first row data
      var firstRow = userRows[0];
      Map<String, dynamic> cleanData = {};
      
      // Clean each value by removing quotes and trimming
      for (int i = 0; i < firstRow.length; i++) {
        var value = firstRow[i].toString().replaceAll('"', '').trim();
        cleanData['col_$i'] = value;
      }

      // Convert CIBIL score to numeric value
      double cibilScore = double.tryParse(cleanData['col_2'].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

      setState(() {
        userData = {
          'name': cleanData['col_0'] ?? 'N/A',
          'pan': cleanData['col_1'] ?? 'N/A',
          'cibil': cibilScore,
          'dob': cleanData['col_3'] ?? 'N/A',
          'monthlyIncome': cleanData['col_11'] ?? 'N/A',
          'employmentType': cleanData['col_19'] ?? 'N/A',
          'savings': cleanData['col_21'] ?? 'N/A',
          'totalannualincome': cleanData['col_22'] ?? 'N/A',
          'loanDetails': {
            'personalLoan': personalLoan,
            'goldLoans': goldLoans,
            'carLoans': carLoans,
            'homeLoans': homeLoans,
            'educationLoans': educationLoans,
            'loantype': cleanData['col_4'] ?? 'N/A',
            'sanctionedamount': cleanData['col_5'] ?? 'N/A',
            'currentamount': cleanData['col_6'] ?? 'N/A',
            'creditCard': cleanData['col_7'] ?? 'NO',
            'latePayments': cleanData['col_8'] ?? 'NO',
            'loantenure': cleanData['col_9'] ?? 'N/A',
            'interestRate': cleanData['col_10'] ?? 'N/A',
            'monthlyemi': cleanData['col_12'] ?? 'N/A',
            'previousLoans': cleanData['col_13'] ?? 'N/A',
            'defaults': cleanData['col_14'] ?? 'N/A',
            'creditcardcount': cleanData['col_15'] ?? 'N/A',
            'creditutilization': cleanData['col_16'] ?? 'N/A',
            'loanrepaymenthistory': cleanData['col_17'] ?? 'N/A',
            'otherdebts': cleanData['col_18'] ?? 'N/A',
            'existingemis': cleanData['col_20'] ?? 'N/A',
          }
        };
        isLoading = false;
      });

      print("Successfully loaded user data: ${userData.toString()}");
    } 
    catch (e, stackTrace) {
      print('Error fetching user data: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        isLoading = false;
        userData = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6A82FB), Color(0xFFFC5C7D)],
      ),
    );

    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: backgroundDecoration,
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (userData == null) {
      return Scaffold(
        body: Container(
          decoration: backgroundDecoration,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 70,
                  color: Colors.white,
                ),
                SizedBox(height: 20),
                Text(
                  'No data found',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFFFC5C7D),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: backgroundDecoration,
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
                      'Dashboard',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => fetchUserData(),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 20),
                  padding: EdgeInsets.all(25),
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
                        // Header with user info section
                        _buildUserInfoCard(),
                        SizedBox(height: 20),

                        // CIBIL Score Card with actual score
                        FadeInUp(
                          duration: Duration(milliseconds: 800),
                          child: _buildScoreCard(userData?['cibil'] ?? 0),
                        ),
                        SizedBox(height: 25),

                        // Loan Details Section Title
                        if (userData?['loanDetails'] != null)
                          Text(
                            "Your Loans",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        SizedBox(height: 15),

                        // Loan Details
                        if (userData?['loanDetails'] != null) ...[
                          _buildLoanSection('Personal Loan', userData!['loanDetails']['personalLoan']),
                          SizedBox(height: 15),
                          _buildLoanSection('Gold Loans', userData!['loanDetails']['goldLoans']),
                          SizedBox(height: 15),
                          _buildLoanSection('Car Loans', userData!['loanDetails']['carLoans']),
                          SizedBox(height: 15),
                          _buildLoanSection('Home Loans', userData!['loanDetails']['homeLoans']),
                          SizedBox(height: 15),
                          _buildLoanSection('Education Loans', userData!['loanDetails']['educationLoans']),
                        ],

                        // Credit Card Status
                        SizedBox(height: 25),
                        Text(
                          "Credit Status",
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        SizedBox(height: 15),
                        _buildCreditCardStatus(userData!['loanDetails']['creditCard'] == 'YES'),
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

  Widget _buildUserInfoCard() {
    return FadeInUp(
      duration: Duration(milliseconds: 600),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF6A82FB).withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: Color(0xFF6A82FB).withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF6A82FB).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 30,
                color: Color(0xFF6A82FB),
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userData?['name'] ?? 'User',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Text(
                    'PAN: ${userData?['pan'] ?? 'N/A'}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    title: Text(
                      'Personal Details',
                      style: GoogleFonts.poppins(
                        color: Color(0xFF333333),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Name', userData?['name'] ?? 'N/A'),
                        _buildDetailRow('PAN', userData?['pan'] ?? 'N/A'),
                        _buildDetailRow('Profession', userData?['employmentType'] ?.toString() ?? 'N/A'),
                        _buildDetailRow('DOB', userData?['dob']?.toString() ?? 'N/A'),
                        _buildDetailRow('CIBIL Score', userData?['cibil']?.toString() ?? 'N/A'),
                        _buildDetailRow('Credit Card', userData?['loanDetails']['creditCard']?.toString() ?? 'N/A'),
                        _buildDetailRow('Savings', userData?['savings']?.toString() ?? 'N/A'),
                        _buildDetailRow('Annual Income', userData?['totalannualincome']?.toString() ?? 'N/A'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close',
                          style: GoogleFonts.poppins(color: Color(0xFFFC5C7D)),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFFC5C7D).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Color(0xFFFC5C7D),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Color(0xFF6A82FB),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Color(0xFF333333),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(dynamic score) {
    double scoreValue = 0.0;
    if (score is double) {
      scoreValue = score;
    } else if (score is int) {
      scoreValue = score.toDouble();
    } else if (score is String) {
      scoreValue = double.tryParse(score.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }

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
          color: _getScoreColor(_getScoreDescription(scoreValue)).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your CIBIL Score',
                style: GoogleFonts.poppins(
                  color: Color(0xFF333333),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getScoreColor(_getScoreDescription(scoreValue)).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: _getScoreColor(_getScoreDescription(scoreValue)),
                  size: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scoreValue.toInt().toString(),
                      style: GoogleFonts.poppins(
                        color: Color(0xFF333333),
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getScoreDescription(scoreValue),
                      style: GoogleFonts.poppins(
                        color: _getScoreColor(_getScoreDescription(scoreValue)),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: _getScoreColor(_getScoreDescription(scoreValue)).withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: scoreValue / 900.0,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(_getScoreDescription(scoreValue))),
                      strokeWidth: 10,
                    ),
                    Text(
                      '${((scoreValue / 900.0) * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        color: Color(0xFF333333),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          LinearProgressIndicator(
            value: scoreValue / 900.0,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(_getScoreDescription(scoreValue))),
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
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
      default:
        return Colors.grey;
    }
  }

  Widget _buildLoanSection(String title, dynamic loanData) {
    if (loanData == null || (loanData is List && loanData.isEmpty)) {
      return SizedBox.shrink();
    }

    return FadeInUp(
      duration: Duration(milliseconds: 1000),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF6A82FB).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getLoanIcon(title),
                    size: 20,
                    color: Color(0xFF6A82FB),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Color(0xFF333333),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            if (loanData is List) ...[
              ...loanData.map((loan) => _buildLoanItem(loan)).toList(),
            ] else ...[
              _buildLoanItem(loanData),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getLoanIcon(String loanType) {
    switch (loanType) {
      case 'Personal Loan':
        return Icons.account_balance_wallet;
      case 'Gold Loans':
        return Icons.monetization_on;
      case 'Car Loans':
        return Icons.directions_car;
      case 'Home Loans':
        return Icons.home;
      case 'Education Loans':
        return Icons.school;
      default:
        return Icons.credit_card;
    }
  }

  Widget _buildLoanItem(Map<String, dynamic> loan) {
    // Get the loan amounts
    double sanctionedAmount = loan['sanctionedAmount'] is num 
        ? (loan['sanctionedAmount'] as num).toDouble()
        : 0.0;
    
    double currentAmount = loan['currentAmount'] is num
        ? (loan['currentAmount'] as num).toDouble()
        : 0.0;
    
    // Calculate progress
    double progress = sanctionedAmount > 0 
        ? 1.0 - (currentAmount / sanctionedAmount)
        : 1.0;
    
    // Ensure progress is between 0 and 1
    progress = progress.clamp(0.0, 1.0);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sanctioned: ₹${sanctionedAmount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: currentAmount > 0 
                      ? Colors.orange.withOpacity(0.1) 
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentAmount > 0 ? 'Active' : 'Paid',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: currentAmount > 0 ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current: ₹${currentAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: Color(0xFF333333),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        currentAmount > 0 ? Color(0xFFFC5C7D) : Colors.green,
                      ),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.poppins(
                  color: currentAmount > 0 ? Color(0xFFFC5C7D) : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardStatus(bool hasCreditCard) {
    return FadeInUp(
      duration: Duration(milliseconds: 1200),
      child: Container(
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
            color: hasCreditCard ? Color(0xFFFC5C7D).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasCreditCard 
                    ? Color(0xFFFC5C7D).withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.credit_card,
                size: 30,
                color: hasCreditCard ? Color(0xFFFC5C7D) : Colors.grey,
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credit Card Status',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    hasCreditCard ? 'Active' : 'Inactive',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Text(
                    hasCreditCard 
                        ? 'You have an active credit card'
                        : 'No credit card associated with this account',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: hasCreditCard ? Color(0xFFFC5C7D) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 