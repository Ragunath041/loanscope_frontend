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
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:loanscope/pages/FDCardPage.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:loanscope/pages/FDCardPage.dart';
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
  GoogleMapController? googleMapController;
  Set<Marker> markers = {};
  bool isLoading = false;
  String? nearestBankName;

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
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print("Current Position: ${position.latitude}, ${position.longitude}"); // Debug print
      setState(() {
        currentPosition = position;
        _isLoadingLocations = false;
        markers.add(
          Marker(
            markerId: MarkerId('current_location'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      });
      if (googleMapController != null) {
        googleMapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 14,
            ),
          ),
        );
      }
    } catch (e) {
      print("Location error: $e");
      setState(() => _isLoadingLocations = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }
  Widget _buildBankMap() {
    if (currentPosition == null) {
      return Center(child: CircularProgressIndicator());
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
        zoom: 14,
      ),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onMapCreated: (GoogleMapController controller) {
        googleMapController = controller;
        // Call the function to search for nearby banks
        searchNearbyBanks();
      },
    );
  }
  Future<void> searchNearbyBanks() async {
    if (currentPosition == null) return; // Ensure current position is available
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(
        'https://loanscope.onrender.com/search_nearby_banks?location=${currentPosition!.latitude},${currentPosition!.longitude}&radius=5000'
      ));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          markers.clear(); // Clear existing markers
          for (var bank in data['results']) {
            markers.add(
              Marker(
                markerId: MarkerId(bank['id']),
                position: LatLng(bank['geometry']['location']['lat'], bank['geometry']['location']['lng']),
                infoWindow: InfoWindow(title: bank['name']), // Display bank name
              ),
            );
          }
        });
      } else {
        print("Failed to fetch bank data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error searching banks: $e");
    } finally {
      setState(() => isLoading = false);
    }
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
      backgroundColor: Color(0xFF2C2C54),
      body: Container(
        padding: EdgeInsets.all(20),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                FadeInDown(
                  duration: Duration(milliseconds: 500),
                  child: Text(
                    'Loan Prediction',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 20),
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
                          backgroundColor: Color(0xFF89F7FE),
                          padding: EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Predict CIBIL Score',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      if (_tenureController.text.isNotEmpty) ...[
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                    ],
                    ]
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
                  Text(
                    'Recommended Banks & Loans',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 15),
                  _buildBankRecommendations(),
                ],
                // _buildLoanEligibilityInfo(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (currentPosition != null && googleMapController != null) {
            googleMapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                  zoom: 14,
                ),
              ),
            );
          }
        },
        child: Icon(Icons.my_location),
        backgroundColor: Color(0xFF89F7FE),
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
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: TextFormField(
          controller: controller,
          style: GoogleFonts.poppins(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(color: Colors.white70),
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.white38),
            prefixIcon: Icon(icon, color: Colors.white70),
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white24,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCibilScoreGauge(),
          SizedBox(height: 30),
          if (_calculatedInterestRate != null) 
            _buildInterestRateCard(),
          SizedBox(height: 30),
          // if (_analysis != null) 
          //   _buildAnalysisGraphs(),
          SizedBox(height: 20),
          if (_isEligible != null)
            _buildEligibilityStatus(),
        ],
      ),
    );
  }

  Widget _buildCibilScoreGauge() {
    final score = int.tryParse(_predictionResult ?? '0') ?? 0;
    return Column(
      children: [
        Text(
          'Predicted CIBIL Score',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 16,
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
                  PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 60,
                      sections: [
                        PieChartSectionData(
                          color: _getScoreColor(value.toInt()),
                          value: (value - 300) / (900 - 300) * 100,
                          radius: 20,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          color: Colors.white10,
                          value: (1 - (value - 300) / (900 - 300)) * 100,
                          radius: 20,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    value.toInt().toString(),
                    style: GoogleFonts.poppins(
                      color: _getScoreColor(value.toInt()),
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Interest Rate',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 5),
              Text(
                '$_calculatedInterestRate%',
                style: GoogleFonts.poppins(
                  color: Color(0xFF89F7FE),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Icon(
            Icons.percent_rounded,
            color: Color(0xFF89F7FE),
            size: 40,
          ),
        ],
      ),
    );
  }
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildEligibilityStatus() {
    bool isEligible = _predictionResult != null && int.tryParse(_predictionResult!)! >= 580; // Check eligibility based on predicted score

    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isEligible 
          ? Colors.green.withOpacity(0.1) 
          : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isEligible 
            ? Colors.green.withOpacity(0.3) 
            : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isEligible 
                  ? Icons.check_circle_outline 
                  : Icons.error_outline,
                color: isEligible 
                  ? Colors.green 
                  : Colors.red,
                size: 30,
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEligible 
                        ? 'Eligible for Loan' 
                        : 'Not Eligible for Loan',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isEligible
                        ? 'Your credit score meets our requirements'
                        : 'Your credit score needs improvement',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isEligible) // Show button only if not eligible
            SizedBox(height: 10), // Add some space before the button
          if (!isEligible)
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FDCardPage()), // Navigate to FDCardPage
                );
              },
              child: Text('Improve CIBIL Score'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF89F7FE), // Customize button color
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
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
      _loanEligibility = null;  // Reset loan eligibility
    });
    try {
      final response = await http.post(
        // Uri.parse('https://loanscope.onrender.com/predict_cibil'),
        Uri.parse('http://127.0.0.1:5000/predict_cibil'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        body: jsonEncode({
          'pan_number': widget.panNumber,
          'loan_amount': _loanAmountController.text,
          'tenure': _tenureController.text,
          'monthly_emi': _calculateMonthlyEMI().toStringAsFixed(2),
          'on_time_payments': _onTimePaymentsController.text,
          'late_payments': _calculateLatePayments().toString(),
        }),
      );
      final data = jsonDecode(response.body);
      setState(() {
        _predictionResult = data['predicted_score'].toString();
        _isEligible = data['is_eligible'];
        _analysis = data['analysis'];
        double baseRate = 8.0;
        int cibilScore = int.parse(_predictionResult!);
        if (cibilScore < 600) {
          baseRate += 10.0;
        } else if (cibilScore < 650) {
          baseRate += 6.0;
        } else if (cibilScore < 750) {
          baseRate += 3.0;
        }
        int latePayments = _calculateLatePayments();
        baseRate += (latePayments * 0.5);
        _calculatedInterestRate = (baseRate > 24.0 ? 24.0 : baseRate).toStringAsFixed(2);
        _calculateLoanEligibility(cibilScore);
      });
      print('Predicted Score: $_predictionResult');
      print('Is Eligible: $_isEligible');
      print('Loan Eligibility: $_loanEligibility');

    } catch (e) {
      print('Error occurred: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildBankRecommendations() {
    return Column(
      children: _loanEligibility!.map((bank) {
        return Padding(
          padding: EdgeInsets.only(bottom: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white24,
                width: 1,
              ),
            ),
            child: ExpansionTile(
              leading: Container(
                width: 100, // Adjust the width as needed
                height: 200, // Adjust the height as needed
                padding: EdgeInsets.all(8), // Adjust padding as needed
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  bank['logo'], // Ensure this path is correct
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading logo: $error'); // Debug print
                    return Container(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance,
                            color: Colors.grey,
                            size: 40,
                          ),
                          SizedBox(height: 5),
                          Text(
                            bank['bank'],
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              title: Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text(
                  bank['bank'],
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text(
                  'Interest: ${bank['interest']}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
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
                      Text(
                        'Nearby Branches',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          _showMapDialog(bank['bank']);
                        },
                        child: Text('View Nearest Bank'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF89F7FE),
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
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showMapDialog(String bankName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            height: 450, // Adjust height as needed
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Nearest $bankName',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildBankMap(), // Reuse the map widget
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: Text('Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF89F7FE),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            backgroundColor: Color(0xFF89F7FE), // Customize button color
          ),
        ),
      ],
    );
  }

}
