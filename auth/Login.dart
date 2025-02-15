import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/HomePage.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _email = '';
  String _password = '';
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        // Special case for admin login
        if (_email.trim() == 'kitcbe.25.21bcb041@gmail.com' && _password == 'Admin@1234') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(
                email: _email.trim(),
                panNumber: 'ADMIN',
                isAdmin: true,
              ),
            ),
          );
          return;
        }

        // Regular user login continues here...
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _email.trim(),
          password: _password,
        );

        // Get user data from Firestore
        DocumentSnapshot userData = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userData.exists) {
          throw 'User data not found';
        }

        Map<String, dynamic> userDataMap = userData.data() as Map<String, dynamic>;
        String panNumber = userDataMap['panNumber'] ?? '';
        
        // Check if user is admin from Firestore
        bool isAdmin = userDataMap['isAdmin'] ?? false;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              email: _email.trim(),
              panNumber: panNumber,
              isAdmin: isAdmin,
            ),
          ),
        );
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No user found with this email.';
            break;
          case 'wrong-password':
            errorMessage = 'Wrong password provided.';
            break;
          default:
            errorMessage = 'Login failed: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1E2E), Color(0xFF2D2D44), Color(0xFF2C2C54)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 40),
                  FadeInDown(
                    duration: Duration(milliseconds: 1500),
                    child: Icon(Icons.lock, size: 100, color: Colors.white),
                  ),
                  SizedBox(height: 30),
                  FadeInDown(
                    delay: Duration(milliseconds: 500),
                    child: Text(
                      "Welcome Back",
                      style: GoogleFonts.poppins(
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  FadeInDown(
                    delay: Duration(milliseconds: 700),
                    child: Text(
                      "Sign in to continue",
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
                    ),
                  ),
                  SizedBox(height: 40),
                  FadeInUp(
                    delay: Duration(milliseconds: 1000),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField('Email', Icons.email_outlined, false, (value) => _email = value!),
                          SizedBox(height: 20),
                          _buildTextField('Password', Icons.lock_outline, true, (value) => _password = value!),
                          SizedBox(height: 30),
                          _buildLoginButton(),
                          SizedBox(height: 20),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/register'),
                            child: RichText(
                              text: TextSpan(
                                text: "Don't have an account? ",
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: "Sign Up",
                                    style: GoogleFonts.poppins(
                                      color: Color(0xFF89F7FE),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildTextField(String hint, IconData icon, bool isPassword, Function(String?) onSaved) {
    return TextFormField(
      style: GoogleFonts.poppins(color: Colors.white),
      obscureText: isPassword && !_isPasswordVisible,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        prefixIcon: Icon(icon, color: Color(0xFF89F7FE)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Color(0xFF89F7FE)),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.white60),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Please enter your $hint' : null,
      onSaved: onSaved,
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 15),
          backgroundColor: Color(0xFF89F7FE),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: _login,
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.black87)
            : Text('SIGN IN', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
