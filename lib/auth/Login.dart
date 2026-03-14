import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../pages/HomePage.dart';
import '../services/local_database.dart'; // Import our local database service

class LoginPage extends StatefulWidget {
  final bool initialRegister;
  LoginPage({this.initialRegister = false});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final LocalDatabaseService _localDb = LocalDatabaseService();

  // Animation controllers for flip
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;

  // Login fields
  String _email = '';
  String _password = '';

  // Register fields
  String _regEmail = '';
  String _regPassword = '';
  String _regName = '';
  String _regPan = '';

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isFlipped = widget.initialRegister;
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: _isFlipped ? 1.0 : 0.0,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        final userData = await _localDb.loginUser(_email.trim(), _password);

        if (userData != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(
                email: userData['email'],
                panNumber: userData['panNumber'],
                isAdmin: userData['isAdmin'],
              ),
            ),
          );
        } else {
          throw 'Invalid email or password';
        }
      } catch (e) {
        String errorMessage = e is String ? e : 'Login failed: ${e.toString()}';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _register() async {
    if (_registerFormKey.currentState!.validate()) {
      _registerFormKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        final success = await _localDb.registerUser(
          _regEmail.trim(),
          _regPassword,
          _regName.trim(),
          _regPan.trim(),
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration successful!')),
          );
          _toggleFlip();
        } else {
          throw 'Registration failed. Email or PAN number may already be in use.';
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF6A82FB), Color(0xFFFC5C7D)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 40),
                  FadeInDown(
                    duration: Duration(milliseconds: 1200),
                    child: Center(
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            )
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.account_balance,
                            size: 60,
                            color: Color(0xFFFC5C7D),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: FadeInDown(
                      delay: Duration(milliseconds: 400),
                      child: Text(
                        "Loan Scope",
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  FadeInUp(
                    delay: Duration(milliseconds: 800),
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final angle = _flipAnimation.value * math.pi;
                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle),
                          alignment: Alignment.center,
                          child: angle <= math.pi / 2
                              ? _buildLoginCard()
                              : Transform(
                                  transform: Matrix4.identity()
                                    ..rotateY(math.pi),
                                  alignment: Alignment.center,
                                  child: _buildRegisterCard(),
                                ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: FadeInUp(
                      delay: Duration(milliseconds: 1000),
                      child: TextButton(
                        onPressed: _toggleFlip,
                        child: RichText(
                          text: TextSpan(
                            text: _isFlipped
                                ? "Already have an account? "
                                : "Don't have an account? ",
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 13),
                            children: [
                              TextSpan(
                                text: _isFlipped ? "Sign In" : "Sign Up",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
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
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 1),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField('Email', Icons.email_outlined, false,
                (value) => _email = value!),
            SizedBox(height: 15),
            _buildTextField('Password', Icons.lock_outline, true,
                (value) => _password = value!),
            SizedBox(height: 20),
            _buildAuthButton('SIGN IN', _login),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      padding: EdgeInsets.all(18), // Slightly tighter
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 1),
        ],
      ),
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            _buildTextField('Full Name', Icons.person_outline, false,
                (value) => _regName = value!),
            SizedBox(height: 10),
            _buildTextField('Email', Icons.email_outlined, false,
                (value) => _regEmail = value!),
            SizedBox(height: 10),
            _buildTextField('PAN Number', Icons.credit_card_outlined, false,
                (value) => _regPan = value!),
            SizedBox(height: 10),
            _buildTextField('Password', Icons.lock_outline, true,
                (value) => _regPassword = value!),
            SizedBox(height: 15),
            _buildAuthButton('REGISTER', _register),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      String hint, IconData icon, bool isPassword, Function(String?) onSaved) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey[700]),
        ),
        SizedBox(height: 4),
        TextFormField(
          style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
          obscureText: isPassword && !_isPasswordVisible,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            prefixIcon: Icon(icon, color: Color(0xFFFC5C7D), size: 18),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Color(0xFFFC5C7D),
                      size: 18,
                    ),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(0xFFFC5C7D)),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter $hint';
            if (hint == 'Email' && !value.contains('@'))
              return 'Enter valid email';
            if (hint == 'Password' && value.length < 6) return 'Mini 6 chars';
            if (hint == 'PAN Number' && value.length != 10)
              return '10 chars required';
            return null;
          },
          onSaved: onSaved,
        ),
      ],
    );
  }

  Widget _buildAuthButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF6A82FB),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
