import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl = 'https://loanscope.onrender.com';  // Your actual Render URL
  
  static Future<dynamic> getEducationData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/education'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load education data');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> addEducation(Map<String, dynamic> data) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/education'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
    } catch (e) {
      throw Exception('Error adding education: $e');
    }
  }

  static Future<void> updateEducation(String id, Map<String, dynamic> data) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/education/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
    } catch (e) {
      throw Exception('Error updating education: $e');
    }
  }

  static Future<void> deleteEducation(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/education/$id'));
    } catch (e) {
      throw Exception('Error deleting education: $e');
    }
  }

  static Future<Map<String, dynamic>> predictCibil(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict_cibil'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to predict CIBIL score');
      }
    } catch (e) {
      throw Exception('Error predicting CIBIL score: $e');
    }
  }
}