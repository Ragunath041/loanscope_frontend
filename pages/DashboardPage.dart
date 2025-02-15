import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/Login.dart';
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
      final String csvData = await rootBundle.loadString('backend/cibil_data.csv');
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvData);
      
      print("CSV Data first few rows:");
      for (var i = 0; i < min(5, csvTable.length); i++) {
        print("Row $i: ${csvTable[i]}");
      }
      
      // Find all rows for this PAN
      final userRows = csvTable.where(
        (row) {
          if (row.length > 1) {
            String csvPan = row[1].toString().trim().toUpperCase();
            String searchPan = widget.panNumber.trim().toUpperCase();
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
        String loanType = row[4].toString();
        Map<String, dynamic> loanDetail = {
          'sanctionedAmount': double.tryParse(row[5].toString()) ?? 0.0,
          'currentAmount': double.tryParse(row[6].toString()) ?? 0.0,
        };

        switch (loanType.toUpperCase()) {
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

      setState(() {
        userData = {
          'name': userRows[0][0] ?? 'N/A',
          'pan': userRows[0][1] ?? 'N/A',
          'cibil': double.tryParse(userRows[0][2].toString()) ?? 0.0,
          'dob': userRows[0][3] ?? 'N/A',
          'monthlyIncome': userRows[0][11] ?? 'N/A',
          'employmentType': userRows[0][19] ?? 'N/A',
          'savings': userRows[0][21] ?? 'N/A', 
          'totalannualincome': userRows[0][22] ?? 'N/A',
          'loanDetails': {
            'personalLoan': personalLoan,
            'goldLoans': goldLoans,
            'carLoans': carLoans,
            'homeLoans': homeLoans,
            'educationLoans': educationLoans,
            'loantype': userRows[0][4] ?? 'N/A',
            'sanctionedamount': userRows[0][5] ?? 'N/A',
            'currentamount': userRows[0][6] ?? 'N/A',
            'creditCard': userRows[0][7] ?? 'NO',
            'latePayments': userRows[0][8] ?? 'NO',
            'loantenure': userRows[0][9] ?? 'N/A',
            'interestRate': userRows[0][10] ?? 'N/A',
            'monthlyemi': userRows[0][12] ?? 'N/A',
            'previousLoans': userRows[0][13] ?? 'N/A',
            'defaults': userRows[0][14] ?? 'N/A',
            'creditcardcount': userRows[0][15] ?? 'N/A',
            'creditutilization': userRows[0][16] ?? 'N/A',
            'loanrepaymenthistory': userRows[0][17] ?? 'N/A',
            'otherdebts': userRows[0][18] ?? 'N/A',
            'existingemis': userRows[0][20] ?? 'N/A',
          }
        };
        isLoading = false;
      });
    } 
    catch (e) {
      print('Error fetching user data: $e');
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
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D2671), Color.fromARGB(255, 195, 55, 55)],
      ),
    );

    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: backgroundDecoration,
          child: Center(
            child: CircularProgressIndicator(
              color: Color.fromARGB(255, 34, 215, 247),
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
            child: Text(
              'No data found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: backgroundDecoration,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome,',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          userData?['name'] ?? 'User',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.account_circle, color: Colors.white, size: 30),
                      color: Color.fromARGB(255, 247, 66, 66),
                      onSelected: (value) async {
                        if (value == 'profile') {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Color(0xFF2D2D44),
                              title: Text(
                                'Personal Details',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
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
                                  _buildDetailRow('SAVINGS', userData?['savings']?.toString() ?? 'N/A'),
                                  _buildDetailRow('Total Annual Income', userData?['totalannualincome']?.toString() ?? 'N/A'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Close',
                                    style: GoogleFonts.poppins(color: Color(0xFF64E8FF)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else if (value == 'logout') {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => LoginPage()),
                            (route) => false,
                          );
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(Icons.person, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Personal Details',
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // CIBIL Score Card with actual score
                FadeInDown(
                  child: _buildScoreCard(userData?['cibil'] ?? 0),
                ),
                SizedBox(height: 20),

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
                SizedBox(height: 15),
                _buildCreditCardStatus(userData!['loanDetails']['creditCard'] == 'YES'),

                // Payment History
                // _buildPaymentHistory(userData!['loanDetails']['latePayments'] == 'YES'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(double score) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your CIBIL Score',
                style: GoogleFonts.poppins(
                  color: const Color.fromARGB(255, 243, 241, 241),
                  fontSize: 16,
                ),
              ),
              Icon(Icons.info_outline, color: const Color.fromARGB(255, 255, 255, 255)),
            ],
          ),
          SizedBox(height: 20),
          Text(
            '$score',
            style: GoogleFonts.poppins(
              color: Color(0xFF89F7FE),
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _getScoreDescription(score),
            style: GoogleFonts.poppins(
              color: _getScoreColor(_getScoreDescription(score)),
              fontSize: 18,
            ),
          ),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: score / 900,
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF89F7FE)),
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
        return const Color.fromARGB(255, 241, 26, 11);
      case 'Fair':
        return Color.fromARGB(255, 248, 214, 43);
      case 'Good':
        return const Color.fromARGB(255, 99, 249, 104);
      case 'Excellent':
        return Color.fromARGB(229, 29, 204, 17);
      case 'Average':
        return Color.fromARGB(255, 251, 26, 153);
      default:
        return Colors.white; // Default color if needed
    }
  }

  Widget _buildLoanSection(String title, dynamic loanData) {
    if (loanData == null || (loanData is List && loanData.isEmpty)) {
      return SizedBox.shrink();
    }

    return FadeInDown(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
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

  Widget _buildLoanItem(Map<String, dynamic> loan) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sanctioned: ₹${loan['sanctionedAmount']}',
                style: GoogleFonts.poppins(color: const Color.fromARGB(255, 255, 255, 255)),
              ),
              Text(
                'Current: ₹${loan['currentAmount']}',
                style: GoogleFonts.poppins(color: const Color.fromARGB(255, 255, 255, 255)),
              ),
            ],
          ),
          Icon(
            loan['currentAmount'] > 0 ? Icons.pending : Icons.check_circle,
            color: loan['currentAmount'] > 0 ? const Color.fromARGB(255, 255, 77, 0) : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardStatus(bool hasCreditCard) {
    return FadeInDown(
      delay: Duration(milliseconds: 200),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credit Card Status',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 15),
            Text(
              hasCreditCard ? 'Active' : 'Inactive',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory(bool hasLatePayments) {
    return FadeInDown(
      delay: Duration(milliseconds: 400),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment History',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 15),
            Text(
              hasLatePayments ? 'Late Payments' : 'No late payments',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 