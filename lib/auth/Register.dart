import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/local_database.dart'; // Import our local database service
import 'Login.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  String _email = '';
  String _password = '';
  String _panNumber = '';
  String _name = ''; // Add name field for local database

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        // Use local database for registration
        final success = await _localDb.registerUser(
          _email.trim(),
          _password,
          _name.trim(),
          _panNumber.trim(),
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration successful!')),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  // Back button
                  FadeInLeft(
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: FadeInDown(
                      duration: Duration(milliseconds: 1200),
                      child: Container(
                        height: 80,
                        width: 80,
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
                            Icons.person_add,
                            size: 50, // Reduced from 60
                            color: Color(0xFFFC5C7D),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10), // Reduced from 15
                  FadeInLeft(
                    delay: Duration(milliseconds: 500),
                    child: Text(
                      "Create",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  FadeInLeft(
                    delay: Duration(milliseconds: 700),
                    child: Text(
                      "Your Account",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 15), // Reduced from 20
                  FadeInUp(
                    delay: Duration(milliseconds: 900),
                    child: Container(
                      padding: EdgeInsets.all(20), // Reduced from 28
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildTextField('Email', Icons.email_outlined,
                                false, (value) => _email = value!),
                            SizedBox(height: 15), // Reduced from 25
                            _buildTextField('Full Name', Icons.person, false,
                                (value) => _name = value!),
                            SizedBox(height: 15), // Reduced from 25
                            _buildTextField('PAN Number', Icons.credit_card,
                                false, (value) => _panNumber = value!),
                            SizedBox(height: 15), // Reduced from 25
                            _buildTextField('Password', Icons.lock_outline,
                                true, (value) => _password = value!),
                            SizedBox(height: 20), // Reduced from 30
                            _buildRegisterButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 5), // Reduced from 10
                  Center(
                    child: FadeInUp(
                      delay: Duration(milliseconds: 1100),
                      child: TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => LoginPage()),
                        ),
                        child: RichText(
                          text: TextSpan(
                            text: "Already have an account? ",
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 15),
                            children: [
                              TextSpan(
                                text: "Sign In",
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
                  SizedBox(height: 10), // Reduced from 20
                ],
              ),
            ),
          ),
        ],
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
            fontSize: 15,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          style: GoogleFonts.poppins(color: Colors.black87),
          obscureText: isPassword && !_isPasswordVisible,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Color(0xFFFC5C7D)),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Color(0xFFFC5C7D),
                    ),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFFC5C7D)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '$hint is required';
            }
            if (hint == 'Email' && !value.contains('@')) {
              return 'Please enter a valid email';
            }
            if (hint == 'Password' && value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            if (hint == 'PAN Number' && value.length != 10) {
              return 'Please enter a valid 10-character PAN';
            }
            return null;
          },
          onSaved: onSaved,
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return Container(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFFC5C7D),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                'Register',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
