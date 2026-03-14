import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  static Box<dynamic>? _userBox;
  static Box<dynamic>? _loanDataBox;
  static Box<dynamic>? _cibilDataBox;
  static Box<dynamic>? _educationBox;

  factory LocalDatabaseService() {
    return _instance;
  }

  LocalDatabaseService._internal();

  Future<void> initialize() async {
    // Initialize Hive
    await Hive.initFlutter();
    _userBox = await Hive.openBox('users');
    _loanDataBox = await Hive.openBox('loan_data');
    _cibilDataBox = await Hive.openBox('cibil_data');
    _educationBox = await Hive.openBox('education');

    // If this is the first run, load sample data
    if (_userBox!.isEmpty) {
      await _loadSampleData();
    }
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    // Special case for admin
    if (email == 'kitcbe.25.21bcb041@gmail.com' && password == 'Admin@1234') {
      return {
        'id': 'admin-1',
        'email': email,
        'name': 'Admin',
        'panNumber': 'ADMIN',
        'isAdmin': true
      };
    }

    try {
      // First try to use the MongoDB API
      try {
        print('Attempting to login with MongoDB API');
        // Create request body
        final Map<String, dynamic> requestBody = {
          'email': email,
          'password': password
        };
        
        // List of possible API endpoints to try
        final List<String> apiEndpoints = [
          'https://loanscope-backend.onrender.com/login',
        ];
        
        // Try each endpoint
        for (final endpoint in apiEndpoints) {
          try {
            print('Trying to connect to: $endpoint');
            final response = await http.post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
              },
              body: json.encode(requestBody),
            ).timeout(const Duration(seconds: 5)); // Add timeout
            
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              print('API response: $data');
              
              if (data['status'] == 'success' && data['user'] != null) {
                final user = data['user'];
                return {
                  'id': user['user_id'],
                  'email': user['email'],
                  'name': user['name'] ?? 'User',
                  'panNumber': user['pan_number'] ?? '',
                  'isAdmin': user['email'] == 'kitcbe.25.21bcb041@gmail.com'
                };
              } else {
                print('API login failed: ${data['message']}');
                return null;
              }
            } else {
              print('API returned error status: ${response.statusCode}');
              print('Response body: ${response.body}');
            }
          } catch (e) {
            print('Error connecting to $endpoint: $e');
            // Continue to next endpoint
          }
        }
        
        // If all API calls fail, fall back to local Hive login
        print('All API calls failed, falling back to Hive');
      } catch (e) {
        print('Error in API login attempt: $e');
        // Continue to Hive login
      }
      
      // Fallback to local Hive login
      return _loginWithHive(email, password);
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _loginWithHive(String email, String password) async {
    try {
      // Regular user login using Hive
      final box = await Hive.openBox('users');
      final users = box.values.where((user) => 
        user['email'] == email && user['password'] == password
      );
      
      if (users.isNotEmpty) {
        final user = users.first;
        return {
          'id': user['id'],
          'email': user['email'],
          'name': user['name'],
          'panNumber': user['panNumber'],
          'isAdmin': false // Regular users aren't admins
        };
      }
      
      return null;
    } catch (e) {
      print('Error in Hive login: $e');
      return null;
    }
  }

  Future<bool> registerUser(String email, String password, String name, String panNumber) async {
    try {
      // First try to use the MongoDB API
      try {
        print('Attempting to register with MongoDB API');
        // Create request body
        final Map<String, dynamic> requestBody = {
          'email': email,
          'password': password,
          'name': name,
          'pan_number': panNumber.toUpperCase()
        };
        
        // List of possible API endpoints to try
        final List<String> apiEndpoints = [
          'https://loanscope-backend.onrender.com/register',
        ];
        
        // Try each endpoint
        for (final endpoint in apiEndpoints) {
          try {
            print('Trying to connect to: $endpoint');
            final response = await http.post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
              },
              body: json.encode(requestBody),
            ).timeout(const Duration(seconds: 5)); // Add timeout
            
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              print('API response: $data');
              
              if (data['status'] == 'success') {
                // Also save to local Hive for offline access
                final userId = data['user_id'] ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
                await _saveUserToHive(userId, email, password, name, panNumber);
                return true;
              } else {
                print('API registration failed: ${data['message']}');
                return false;
              }
            } else {
              print('API returned error status: ${response.statusCode}');
              print('Response body: ${response.body}');
            }
          } catch (e) {
            print('Error connecting to $endpoint: $e');
            // Continue to next endpoint
          }
        }
        
        // If all API calls fail, fall back to local Hive registration
        print('All API calls failed, falling back to Hive');
      } catch (e) {
        print('Error in API registration attempt: $e');
        // Continue to Hive registration
      }
      
      // Fallback to local Hive registration
      return _registerWithHive(email, password, name, panNumber);
    } catch (e) {
      print('Error registering user: $e');
      return false;
    }
  }
  
  Future<bool> _registerWithHive(String email, String password, String name, String panNumber) async {
    try {
      // Check if user with this email already exists
      final box = await Hive.openBox('users');
      final existingUsers = box.values.where((user) => 
        user['email'] == email || user['panNumber'] == panNumber
      );
      
      if (existingUsers.isNotEmpty) {
        print('User already exists in Hive');
        return false; // User with this email or PAN already exists
      }
      
      // Create a unique userId
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      
      // Store the user data
      await _saveUserToHive(userId, email, password, name, panNumber);
      
      return true;
    } catch (e) {
      print('Error in Hive registration: $e');
      return false;
    }
  }
  
  Future<void> _saveUserToHive(String userId, String email, String password, String name, String panNumber) async {
    final box = await Hive.openBox('users');
    await box.put(userId, {
      'id': userId,
      'email': email,
      'password': password, // In a real app, this should be hashed
      'name': name,
      'panNumber': panNumber.toUpperCase(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getUserByPAN(String panNumber) async {
    try {
      final box = await Hive.openBox('users');
      final users = box.values.where((user) => 
        user['panNumber'] == panNumber
      );
      
      if (users.isNotEmpty) {
        return Map<String, dynamic>.from(users.first);
      }
      
      return null;
    } catch (e) {
      print('Error getting user by PAN: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCibilData(String panNumber) async {
    try {
      final box = await Hive.openBox('cibil_data');
      final List<Map<String, dynamic>> result = [];
      
      // Search for matching records in the box
      for (var key in box.keys) {
        final data = box.get(key);
        if (data != null && data['panNumber'] == panNumber) {
          result.add(Map<String, dynamic>.from(data));
        }
      }
      
      return result;
    } catch (e) {
      print('Error getting CIBIL data: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> predictCibilScore(String panNumber, {
    double? loanAmount,
    int? tenure,
    double? monthlyEMI,
    int? onTimePayments,
    int? latePayments,
  }) async {
    // Use Flask API for prediction
    try {
      // Create request body
      final Map<String, dynamic> requestBody = {
        'pan_number': panNumber,
        'loan_amount': loanAmount ?? 0,
        'monthly_emi': monthlyEMI ?? 0,
        'on_time_payments': onTimePayments ?? 0,
        'late_payments': latePayments ?? 0,
      };
      
      // Use the Render backend URL
      final url = 'https://loanscope-backend.onrender.com/predict_cibil';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 5)); // Add timeout
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API response: $data');
        return data;
      }
      
      print('API returned error status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      // If all API calls fail, use fallback
      print('All API connections failed, using local calculation');
      return _calculateLocalPrediction(panNumber, loanAmount, tenure, monthlyEMI, onTimePayments, latePayments);
      
    } catch (e) {
      print('Error predicting CIBIL score: $e');
      // Use fallback local prediction
      return _calculateLocalPrediction(panNumber, loanAmount, tenure, monthlyEMI, onTimePayments, latePayments);
    }
  }
  
  Future<Map<String, dynamic>> _calculateLocalPrediction(
    String panNumber,
    double? loanAmount,
    int? tenure,
    double? monthlyEMI,
    int? onTimePayments,
    int? latePayments
  ) async {
    try {
      // Get base score from local data
      final baseScore = await _getLocalCibilScore(panNumber);
      double finalScore = baseScore.toDouble(); // Ensure it's a double
      
      // Apply adjustments based on payment history
      if (latePayments != null && latePayments > 0) {
        finalScore -= (latePayments * 20.0); 
      }
      
      // Adjust for on-time payment ratio
      if (onTimePayments != null && tenure != null && tenure > 0) {
        final ratio = onTimePayments / tenure;
        if (ratio >= 0.9) {
          finalScore += 100.0;
        } else if (ratio >= 0.7) {
          finalScore += 50.0;
        } else if (ratio >= 0.5) {
          finalScore += 20.0;
        }
      }
      
      // Calculate and adjust for repayment ratio
      double repaymentRatio = 0.0;
      if (loanAmount != null && loanAmount > 0 && monthlyEMI != null) {
        repaymentRatio = monthlyEMI / loanAmount;
        if (repaymentRatio > 0.15) {
          finalScore -= 6.0;
        }
      }
      
      // Ensure score stays in valid range
      finalScore = finalScore.clamp(300.0, 900.0);
      
      // Return in the same format as the API
      return {
        'status': 'success',
        'predicted_score': finalScore, // Already a double
        'is_eligible': finalScore >= 700.0,
        'analysis': {
          'base_score': baseScore.toDouble(),
          'payment_history': (latePayments == null || latePayments == 0) 
              ? 'Excellent' 
              : 'Poor',
          'emi_ratio': '${(repaymentRatio * 100).toStringAsFixed(1)}% of loan amount',
          'risk_level': (latePayments == null || latePayments == 0) && repaymentRatio <= 0.15
              ? 'Low'
              : 'Moderate'
        }
      };
    } catch (e) {
      print('Error in local prediction calculation: $e');
      return {
        'status': 'error',
        'predicted_score': 600.0, // Ensure it's a double
        'is_eligible': false,
        'analysis': {
          'base_score': 600.0, // Ensure it's a double
          'payment_history': 'Data unavailable',
          'emi_ratio': 'Data unavailable',
          'risk_level': 'Unknown'
        }
      };
    }
  }
  
  Future<int> _getLocalCibilScore(String panNumber) async {
    try {
      final cibilData = await getCibilData(panNumber);
      if (cibilData.isNotEmpty && cibilData.first.containsKey('cibilScore')) {
        return cibilData.first['cibilScore'] as int? ?? 600;
      }
      return 600; // Default score if not found
    } catch (e) {
      return 600; // Default score on error
    }
  }

  Future<bool> saveLoanApplication(String userId, String panNumber, double loanAmount, int tenure, 
    double monthlyEMI, int onTimePayments, int latePayments) async {
    try {
      final box = await Hive.openBox('loan_data');
      final id = 'loan_${DateTime.now().millisecondsSinceEpoch}';
      
      await box.put(id, {
        'id': id,
        'userId': userId,
        'panNumber': panNumber,
        'loanAmount': loanAmount,
        'tenure': tenure,
        'monthlyEMI': monthlyEMI,
        'onTimePayments': onTimePayments,
        'latePayments': latePayments,
        'status': 'Pending',
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      print('Error saving loan application: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLoanApplications(String userId) async {
    try {
      final box = await Hive.openBox('loan_data');
      final allApplications = box.values.toList();
      
      if (userId == 'admin-1') {
        // Admin can see all applications
        return allApplications.map((app) => Map<String, dynamic>.from(app)).toList();
      } else {
        // Regular users see only their own applications
        final userApplications = allApplications
            .where((app) => app['userId'] == userId)
            .toList();
        
        return userApplications.map((app) => Map<String, dynamic>.from(app)).toList();
      }
    } catch (e) {
      print('Error getting loan applications: $e');
      return [];
    }
  }

  Future<void> saveCibilData(Map<String, dynamic> data) async {
    try {
      final box = await Hive.openBox('cibil_data');
      final panNumber = data['panNumber'];
      
      // Generate a key for this data
      String cibilKey = '';
      
      // Check if record exists
      for (var key in box.keys) {
        final existing = box.get(key);
        if (existing != null && existing['panNumber'] == panNumber) {
          cibilKey = key;
          break;
        }
      }
      
      if (cibilKey.isNotEmpty) {
        // Update existing record
        await box.put(cibilKey, data);
      } else {
        // Insert new record with a unique key
        final newKey = 'cibil_${DateTime.now().millisecondsSinceEpoch}';
        await box.put(newKey, data);
      }
    } catch (e) {
      print('Error saving CIBIL data: $e');
    }
  }

  Future<void> _loadSampleData() async {
    try {
      // Add sample CIBIL data
      final cibilBox = await Hive.openBox('cibil_data');
      
      final List<Map<String, dynamic>> sampleCibilData = [
        {
          'panNumber': 'KOSDE3421L',
          'name': 'Kondalrao',
          'cibilScore': 720,
          'dob': '24-05-2001',
          'loanType': 'Personal Loan',
          'sanctionedAmount': 300000,
          'currentAmount': 350000,
          'creditCard': 'NO',
          'latePayment': 'YES',
          'loanTenure': 9,
          'interestRate': 3.5,
          'monthlyIncome': 25000,
          'monthlyEMI': 30000,
          'previousLoans': 1,
          'defaults': 4,
          'creditCardsCount': 0,
          'creditUtilization': 0,
          'loanRepaymentHistory': 'Good',
          'otherDebts': 'YES',
          'employmentType': 'Freelancer',
          'existingEMIs': 1,
          'savingsBalance': 60000,
          'totalAnnualIncome': 700000,
          'debtToIncomeRatio': 0.004
        },
        {
          'panNumber': 'KWFBS3421S',
          'name': 'Kowsic Anand S',
          'cibilScore': 690,
          'dob': '15-02-2002',
          'loanType': 'Home Loan',
          'sanctionedAmount': 1500000,
          'currentAmount': 1502100,
          'creditCard': 'NO',
          'latePayment': 'YES',
          'loanTenure': 20,
          'interestRate': 8.7,
          'monthlyIncome': 45000,
          'monthlyEMI': 75000,
          'previousLoans': 1,
          'defaults': 4,
          'creditCardsCount': 0,
          'creditUtilization': 0,
          'loanRepaymentHistory': 'Good',
          'otherDebts': 'YES',
          'employmentType': 'Freelancer',
          'existingEMIs': 1,
          'savingsBalance': 60000,
          'totalAnnualIncome': 700000,
          'debtToIncomeRatio': 0.004
        },
        {
          'panNumber': 'BMGDE3421L',
          'name': 'Ameer Jafar Y',
          'cibilScore': 720,
          'dob': '24-05-2001',
          'loanType': 'Personal Loan',
          'sanctionedAmount': 300000,
          'currentAmount': 350000,
          'creditCard': 'NO',
          'latePayment': 'YES',
          'loanTenure': 9,
          'interestRate': 3.5,
          'monthlyIncome': 25000,
          'monthlyEMI': 30000,
          'previousLoans': 1,
          'defaults': 4,
          'creditCardsCount': 0,
          'creditUtilization': 0,
          'loanRepaymentHistory': 'Good',
          'otherDebts': 'YES',
          'employmentType': 'Freelancer',
          'existingEMIs': 1,
          'savingsBalance': 60000,
          'totalAnnualIncome': 700000,
          'debtToIncomeRatio': 0.004
        },
        {
          'panNumber': 'PRSSEA3421L',
          'name': 'Nandhini V',
          'cibilScore': 720,
          'dob': '24-05-2001',
          'loanType': 'Personal Loan',
          'sanctionedAmount': 300000,
          'currentAmount': 350000,
          'creditCard': 'NO',
          'latePayment': 'YES',
          'loanTenure': 9,
          'interestRate': 3.5,
          'monthlyIncome': 25000,
          'monthlyEMI': 30000,
          'previousLoans': 1,
          'defaults': 4,
          'creditCardsCount': 0,
          'creditUtilization': 0,
          'loanRepaymentHistory': 'Good',
          'otherDebts': 'YES',
          'employmentType': 'Freelancer',
          'existingEMIs': 1,
          'savingsBalance': 60000,
          'totalAnnualIncome': 700000,
          'debtToIncomeRatio': 0.004
        }
      ];
      
      // Insert sample data into the box
      for (var i = 0; i < sampleCibilData.length; i++) {
        await cibilBox.put('cibil_$i', sampleCibilData[i]);
      }
      
      // Create sample users
      await registerUser('user1@example.com', 'password123', 'User One', 'ABCDE1234F');
      await registerUser('user2@example.com', 'password123', 'User Two', 'XYZAB5678G');
      
      // Create admin user
      final userBox = await Hive.openBox('users');
      await userBox.put('admin-1', {
        'id': 'admin-1',
        'email': 'kitcbe.25.21bcb041@gmail.com',
        'password': 'Admin@1234', // In a real app, this should be hashed
        'name': 'Admin',
        'panNumber': 'ADMIN',
        'isAdmin': true
      });
      
      // Add sample education content
      final educationBox = await Hive.openBox('education');
      final List<Map<String, dynamic>> sampleEducation = [
        {
          'id': 'question_1',
          'question': 'What is a CIBIL score?',
          'answer': 'A CIBIL score is a three-digit number between 300 and 900 that represents your creditworthiness. The higher the score, the better your chances of getting a loan approved.',
          'timestamp': DateTime.now().subtract(Duration(days: 10)).toIso8601String(),
        },
        {
          'id': 'question_2',
          'question': 'How can I improve my credit score?',
          'answer': 'You can improve your credit score by paying bills on time, keeping credit card balances low, not applying for too much credit, and maintaining a good mix of credit types.',
          'timestamp': DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
        },
        {
          'id': 'question_3',
          'question': 'What factors affect my loan eligibility?',
          'answer': 'Loan eligibility is determined by factors such as credit score, income, existing debt, employment stability, and the purpose of the loan.',
          'timestamp': DateTime.now().subtract(Duration(days: 5)).toIso8601String(),
        },
      ];
      
      for (var item in sampleEducation) {
        await educationBox.put(item['id'], item);
      }
    } catch (e) {
      print('Error loading sample data: $e');
    }
  }

  Future<void> close() async {
    await Hive.close();
  }

  // Education methods
  Future<bool> addQuestion(String question, String answer) async {
    try {
      final box = await Hive.openBox('education');
      final id = 'question_${DateTime.now().millisecondsSinceEpoch}';
      
      await box.put(id, {
        'id': id,
        'question': question,
        'answer': answer,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      print('Error adding question: $e');
      return false;
    }
  }

  Future<bool> deleteQuestion(String id) async {
    try {
      final box = await Hive.openBox('education');
      await box.delete(id);
      return true;
    } catch (e) {
      print('Error deleting question: $e');
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> watchQuestions() async* {
    final box = await Hive.openBox('education');
    
    // Initial data
    yield _getQuestionsFromBox(box);
    
    // Create a stream that emits whenever the box changes
    await for (final _ in box.watch()) {
      yield _getQuestionsFromBox(box);
    }
  }
  
  List<Map<String, dynamic>> _getQuestionsFromBox(Box box) {
    return box.values
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
      ..sort((a, b) => (b['timestamp']).compareTo(a['timestamp']));
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String panNumber) async {
    try {
      final userBox = await Hive.openBox('users');
      
      // Check if user exists
      if (!userBox.containsKey(panNumber)) {
        return null;
      }
      
      // Return user data
      final userData = userBox.get(panNumber);
      return Map<String, dynamic>.from(userData);
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }
} 