import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'local_database.dart';
import 'csv_service.dart';
import 'package:flutter/foundation.dart';

class PredictionService {
  static final PredictionService _instance = PredictionService._internal();
  final LocalDatabaseService _databaseService = LocalDatabaseService();
  final CsvService _csvService = CsvService();
  final String baseUrl = 'https://loanscope-backend.onrender.com';

  factory PredictionService() {
    return _instance;
  }

  PredictionService._internal();

  // Function to predict CIBIL score locally
  Future<Map<String, dynamic>> predictCibilScore({
    required String panNumber,
    double? loanAmount,
    int? tenure,
    double? monthlyEMI,
    int? onTimePayments,
    int? latePayments,
  }) async {
    try {
      // Try to make API call first
      try {
        final url = Uri.parse('$baseUrl/predict_cibil');
        
        // Create request body with all necessary parameters
        final Map<String, dynamic> requestBody = {
          'pan_number': panNumber,
          'loan_amount': loanAmount ?? 0,
          'tenure_months': tenure ?? 0,
          'monthly_emi': monthlyEMI ?? 0,
          'late_payments': latePayments ?? 0,
          'credit_utilization': 30, // Default values for new parameters
          'credit_age_months': 24,
          'total_accounts': 1,
          'credit_mix_types': 1,
          'recent_inquiries': 0,
          'monthly_income': 50000,
        };
        
        // Make API call
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        ).timeout(Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          
          // Make sure the response format matches what the app expects
          return {
            'status': 'success',
            'predicted_score': responseData['calculated_score'],
            'is_eligible': responseData['is_eligible'],
            'analysis': {
              'base_score': responseData['starting_score'],
              'score_components': responseData['score_components'],
              'improvement_potential': responseData['improvement_potential'],
              'recovery_timeline': responseData['recovery_timeline'],
              'risk_level': responseData['risk_level'],
              'recommendations': responseData['recommendations'],
            }
          };
        }
      } catch (e) {
        print('API call failed, using local prediction: $e');
        // Continue with local prediction if API call fails
      }
      
      // Get CIBIL data from CSV (fallback method)
      final cibilData = await _csvService.getCibilDataByPan(panNumber);
      int baseScore = cibilData.isNotEmpty && cibilData.first.containsKey('CIBIL') 
          ? int.tryParse(cibilData.first['CIBIL'].toString()) ?? 600 
          : 600;
           
      int predictedScore = baseScore;
      
      // Apply basic adjustments based on input parameters
      if (loanAmount == null || tenure == null || monthlyEMI == null || 
          onTimePayments == null || latePayments == null) {
        return {
          'status': 'success',
          'predicted_score': predictedScore,
          'is_eligible': predictedScore >= 700,
          'note': 'Using base score only due to missing parameters',
          'analysis': {
            'base_score': baseScore,
            'payment_history': 'No history available',
            'risk_level': predictedScore >= 750 ? 'Low' : (predictedScore >= 650 ? 'Moderate' : 'High'),
          }
        };
      }

      // Adjust score based on payment history (35% weight)
      int paymentHistoryScore = 0;
      if (onTimePayments > 0 && tenure > 0) {
        double paymentRatio = onTimePayments / tenure;
        if (paymentRatio >= 0.9) paymentHistoryScore = 35;
        else if (paymentRatio >= 0.7) paymentHistoryScore = 25;
        else if (paymentRatio >= 0.5) paymentHistoryScore = 15;
        else paymentHistoryScore = 5;
      }
      
      // Credit utilization (30% weight)
      int utilizationScore = 30; // Default to full score
      
      // Credit age (15% weight)
      int ageScore = 10; // Default medium score
      
      // Credit mix (10% weight)
      int mixScore = 5; // Default basic score
      
      // Recent inquiries (10% weight)
      int inquiryScore = 10; // Default full score - no inquiries
      
      // Late payments penalty (part of payment history)
      int latePaymentPenalty = 0;
      if (latePayments > 0) {
        latePaymentPenalty = math.min(35, latePayments * 10); // Cap at max payment history weight
      }
      
      // Calculate total factor score (max 100)
      int totalFactorScore = paymentHistoryScore + utilizationScore + ageScore + mixScore + inquiryScore - latePaymentPenalty;
      
      // Convert to CIBIL range (300-900)
      predictedScore = 300 + ((totalFactorScore / 100) * 600).toInt();
      
      // Ensure score stays within valid range
      predictedScore = predictedScore.clamp(300, 900);
      
      // Save the application data for future reference
      await _databaseService.saveLoanApplication(
        'user-${DateTime.now().millisecondsSinceEpoch}',
        panNumber,
        loanAmount,
        tenure,
        monthlyEMI,
        onTimePayments,
        latePayments
      );
      
      // Calculate risk level
      String riskLevel = 'High';
      if (predictedScore >= 750) {
        riskLevel = 'Low';
      } else if (predictedScore >= 650) {
        riskLevel = 'Moderate';
      }
      
      // Generate recovery timeline
      List<Map<String, dynamic>> recoveryTimeline = [];
      int currentScore = predictedScore;
      
      for (int month = 3; month <= 24; month += 3) {
        int improvement = 0;
        
        // Add improvement if there were late payments (assuming they're now making on-time payments)
        if (latePayments > 0) {
          improvement += 5; // Points per quarter of good behavior
        }
        
        currentScore = math.min(900, currentScore + improvement);
        recoveryTimeline.add({
          'month': month,
          'score': currentScore,
          'improvement': currentScore - predictedScore
        });
      }
      
      // Return the result with detailed analysis
      return {
        'status': 'success',
        'predicted_score': predictedScore,
        'is_eligible': predictedScore >= 700,
        'analysis': {
          'base_score': baseScore,
          'payment_history': latePayments > 2 ? 'Poor' : (latePayments > 0 ? 'Fair' : 'Good'),
          'risk_level': riskLevel,
          'score_components': {
            'payment_history': {
              'score': paymentHistoryScore - latePaymentPenalty,
              'max_score': 35,
              'percentage': ((paymentHistoryScore - latePaymentPenalty) / 35 * 100).round()
            },
            'credit_utilization': {
              'score': utilizationScore,
              'max_score': 30,
              'percentage': (utilizationScore / 30 * 100).round()
            },
            'credit_age': {
              'score': ageScore,
              'max_score': 15,
              'percentage': (ageScore / 15 * 100).round()
            },
            'credit_mix': {
              'score': mixScore,
              'max_score': 10,
              'percentage': (mixScore / 10 * 100).round()
            },
            'recent_inquiries': {
              'score': inquiryScore,
              'max_score': 10,
              'percentage': (inquiryScore / 10 * 100).round()
            }
          },
          'recovery_timeline': recoveryTimeline
        }
      };
      
    } catch (e) {
      print('Error predicting CIBIL score: $e');
      return {
        'status': 'error',
        'message': 'Failed to predict CIBIL score',
        'error': e.toString()
      };
    }
  }
  
  // Helper function to get monthly income from existing data
  Future<double> _getMonthlyIncome(String panNumber) async {
    final cibilData = await _csvService.getCibilDataByPan(panNumber);
    if (cibilData.isNotEmpty && cibilData.first.containsKey('Monthly_Income')) {
      return double.tryParse(cibilData.first['Monthly_Income'].toString()) ?? 50000.0;
    }
    return 50000.0; // Default value if not found
  }
  
  // Function to search for nearby banks - mock implementation for offline use
  Future<Map<String, dynamic>> searchNearbyBanks(double latitude, double longitude) async {
    // Since we can't do a real API call for places when offline,
    // we'll return mock data based on sample banks
    return {
      'status': 'OK',
      'results': [
        {
          'id': 'bank-1',
          'name': 'State Bank of India',
          'vicinity': 'Main Street, City',
          'geometry': {
            'location': {
              'lat': latitude - 0.01,
              'lng': longitude - 0.01
            }
          }
        },
        {
          'id': 'bank-2',
          'name': 'HDFC Bank',
          'vicinity': 'Market Road, City',
          'geometry': {
            'location': {
              'lat': latitude + 0.01,
              'lng': longitude + 0.01
            }
          }
        },
        {
          'id': 'bank-3',
          'name': 'ICICI Bank',
          'vicinity': 'Park Avenue, City',
          'geometry': {
            'location': {
              'lat': latitude - 0.02,
              'lng': longitude + 0.02
            }
          }
        },
        {
          'id': 'bank-4',
          'name': 'Axis Bank',
          'vicinity': 'Central Road, City',
          'geometry': {
            'location': {
              'lat': latitude + 0.02,
              'lng': longitude - 0.02
            }
          }
        },
        {
          'id': 'bank-5',
          'name': 'Bank of Baroda',
          'vicinity': 'Station Road, City',
          'geometry': {
            'location': {
              'lat': latitude,
              'lng': longitude - 0.03
            }
          }
        }
      ]
    };
  }
  
  // Calculate loan EMI
  double calculateEMI(double principal, double rate, int time) {
    // Convert interest rate from annual to monthly
    double monthlyRate = rate / (12 * 100);
    double emi = principal * monthlyRate * (math.pow((1 + monthlyRate), time) / (math.pow((1 + monthlyRate), time) - 1));
    return emi;
  }

  // Prediction services for CIBIL score impact
  Future<Map<String, dynamic>> predictCibilImpact({
    required double currentCibil,
    required double loanAmount,
    required int tenureMonths,
    required double interestRate,
    required double monthlyIncome,
    int existingLoans = 0,
    double creditCardLimit = 0,
    double creditCardBalance = 0,
    int age = 30,
    double existingEmis = 0,
    double paymentHistory = 100,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/predict_cibil');
      
      // Create request body
      final Map<String, dynamic> requestBody = {
        'current_cibil': currentCibil,
        'loan_amount': loanAmount,
        'tenure_months': tenureMonths,
        'interest_rate': interestRate,
        'monthly_income': monthlyIncome,
        'existing_loans': existingLoans,
        'credit_card_limit': creditCardLimit,
        'credit_card_balance': creditCardBalance,
        'age': age,
        'existing_emis': existingEmis,
        'payment_history': paymentHistory,
      };
      
      // Make API call
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        // Parse response
        final responseData = jsonDecode(response.body);
        return responseData;
      } else {
        throw Exception('Failed to predict CIBIL impact: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error predicting CIBIL impact: $e');
      }
      // Return fallback prediction
      return _fallbackCibilPrediction(
        currentCibil: currentCibil,
        loanAmount: loanAmount,
        tenureMonths: tenureMonths,
        interestRate: interestRate,
        monthlyIncome: monthlyIncome,
        existingEmis: existingEmis,
      );
    }
  }
  
  // Prediction service for loan default probability
  Future<Map<String, dynamic>> predictDefaultProbability({
    required double cibilScore,
    required double loanAmount,
    required int tenureMonths,
    required double interestRate,
    required double monthlyIncome,
    int existingLoans = 0,
    int employmentYears = 0,
    int age = 30,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/predict_default');
      
      // Create request body
      final Map<String, dynamic> requestBody = {
        'cibil_score': cibilScore,
        'loan_amount': loanAmount,
        'tenure_months': tenureMonths,
        'interest_rate': interestRate,
        'monthly_income': monthlyIncome,
        'existing_loans': existingLoans,
        'employment_years': employmentYears,
        'age': age,
      };
      
      // Make API call
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        // Parse response
        final responseData = jsonDecode(response.body);
        return responseData;
      } else {
        throw Exception('Failed to predict default probability: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error predicting default probability: $e');
      }
      // Return fallback prediction
      return _fallbackDefaultPrediction(
        cibilScore: cibilScore, 
        loanAmount: loanAmount, 
        monthlyIncome: monthlyIncome,
      );
    }
  }
  
  // Get loan scenarios based on user data
  Future<Map<String, dynamic>> getForecastScenarios({
    required double currentCibil,
    required double monthlyIncome,
    double existingEmis = 0,
    double creditCardLimit = 0,
    double creditCardBalance = 0,
    List<double>? loanAmounts,
    List<int>? tenures,
    List<double>? interestRates,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/forecast_scenarios');
      
      // Create request body
      final Map<String, dynamic> requestBody = {
        'current_cibil': currentCibil,
        'monthly_income': monthlyIncome,
        'existing_emis': existingEmis,
        'credit_card_limit': creditCardLimit,
        'credit_card_balance': creditCardBalance,
      };
      
      // Add optional parameters if provided
      if (loanAmounts != null && loanAmounts.isNotEmpty) {
        requestBody['loan_amounts'] = loanAmounts;
      }
      
      if (tenures != null && tenures.isNotEmpty) {
        requestBody['tenures'] = tenures;
      }
      
      if (interestRates != null && interestRates.isNotEmpty) {
        requestBody['interest_rates'] = interestRates;
      }
      
      // Make API call
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        // Parse response
        final responseData = jsonDecode(response.body);
        return responseData;
      } else {
        throw Exception('Failed to get forecast scenarios: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting forecast scenarios: $e');
      }
      // Return fallback forecast
      return _fallbackForecastScenarios(
        currentCibil: currentCibil,
        monthlyIncome: monthlyIncome,
        existingEmis: existingEmis,
      );
    }
  }
  
  // Check server health
  Future<bool> checkServerHealth() async {
    try {
      final url = Uri.parse('$baseUrl/health');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking server health: $e');
      }
      return false;
    }
  }
  
  // Fallback methods for when the server is unavailable
  
  Map<String, dynamic> _fallbackCibilPrediction({
    required double currentCibil,
    required double loanAmount,
    required int tenureMonths,
    required double interestRate,
    required double monthlyIncome,
    required double existingEmis,
  }) {
    // Calculate EMI for the new loan
    final double emi = _calculateEmi(loanAmount, interestRate, tenureMonths);
    
    // Calculate debt-to-income ratio
    final double dti = (existingEmis + emi) / monthlyIncome;
    
    // Apply simple rules for CIBIL impact
    double impact = 0.0;
    
    // Higher DTI means more negative impact
    if (dti > 0.5) {
      impact -= 10.0;
    } else if (dti > 0.3) {
      impact -= 5.0;
    }
    
    // Loan amount relative to income
    final double loanToAnnualIncome = loanAmount / (monthlyIncome * 12);
    if (loanToAnnualIncome > 3) {
      impact -= 15.0;
    } else if (loanToAnnualIncome > 1) {
      impact -= 5.0;
    }
    
    // Generate recovery timeline
    final List<Map<String, dynamic>> recoveryTimeline = [];
    double predictedScore = currentCibil + impact;
    
    for (int month = 3; month <= 24; month += 3) {
      // Assume some recovery over time
      predictedScore += 2.0; // Points recovered per quarter with on-time payments
      predictedScore = predictedScore.clamp(300.0, currentCibil); // Don't exceed original score
      
      recoveryTimeline.add({
        'month': month,
        'score': predictedScore.toDouble(),
      });
    }
    
    return {
      'status': 'success',
      'note': 'Using fallback prediction (server unavailable)',
      'current_cibil': currentCibil,
      'immediate_impact': impact,
      'predicted_cibil': currentCibil + impact,
      'recovery_timeline': recoveryTimeline,
      'monthly_loan_payment': emi,
      'debt_to_income_ratio': dti * 100, // Convert to percentage
    };
  }
  
  Map<String, dynamic> _fallbackDefaultPrediction({
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
    defaultProbability = defaultProbability.clamp(1.0, 95.0);
    
    // Determine risk category
    String riskCategory;
    if (defaultProbability < 10) {
      riskCategory = "Very Low Risk";
    } else if (defaultProbability < 20) {
      riskCategory = "Low Risk";
    } else if (defaultProbability < 40) {
      riskCategory = "Moderate Risk";
    } else if (defaultProbability < 60) {
      riskCategory = "High Risk";
    } else {
      riskCategory = "Very High Risk";
    }
    
    return {
      'status': 'success',
      'note': 'Using fallback prediction (server unavailable)',
      'default_probability': defaultProbability,
      'risk_category': riskCategory,
    };
  }
  
  Map<String, dynamic> _fallbackForecastScenarios({
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
      
      // Calculate EMI
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
    final double emi = (principal * monthlyRate * math.pow((1 + monthlyRate), tenureMonths)) / 
                      (math.pow((1 + monthlyRate), tenureMonths) - 1);
    return emi;
  }
} 