import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loanscope/auth/Login.dart';
import 'DashboardPage.dart';
import 'LoanPage.dart';
import 'EducationPage.dart';
import 'AnalysisPage.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchUserCibilScore();
  }

  Future<void> _fetchUserCibilScore() async {
    final String response = await rootBundle.loadString('backend/cibil_data.csv');
    final List<List<dynamic>> data = const CsvToListConverter().convert(response);
    print(data);
    for (var row in data) {
      if (row[1] == widget.panNumber) {
        setState(() {
          userCibilScore = row[2];
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1D2671), Color.fromARGB(255, 195, 55, 55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 60),
            FadeInDown(
              child: Text(
                'Welcome, ${widget.email}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                padding: EdgeInsets.all(20),
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  _buildMenuCard('Dashboard', Icons.dashboard, Colors.blue, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DashboardPage(panNumber: widget.panNumber),
                      ),
                    );
                  }),
                  _buildMenuCard('Predict CIBIL', Icons.trending_up, Colors.green, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoanPage(panNumber: widget.panNumber),
                      ),
                    );
                  }),
                  _buildMenuCard('Education', Icons.school, Colors.red, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EducationPage(isAdmin: widget.isAdmin),
                      ),
                    );
                  }),
                  _buildMenuCard('Analytics', Icons.analytics, Colors.orange, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnalysisPage(
                          panNumber: widget.panNumber,
                          cibilScore: userCibilScore ?? 750,
                          // print(userCibilScore);
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            FadeInUp(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                    (route) => false,
                  );
                },
                child: Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
