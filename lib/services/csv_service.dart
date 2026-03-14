import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

class CsvService {
  static final CsvService _instance = CsvService._internal();
  List<Map<String, dynamic>>? _cachedData;

  factory CsvService() {
    return _instance;
  }

  CsvService._internal();

  Future<List<Map<String, dynamic>>> loadCibilData() async {
    if (_cachedData != null) {
      return _cachedData!;
    }

    try {
      // Read directly from backend folder using File
      final file = File('backend/cibil_data.csv');
      if (!await file.exists()) {
        print('Error: CSV file not found at ${file.path}');
        return [];
      }

      String csvData = await file.readAsString();
      print('Successfully read CSV from ${file.path}');

      // Define the column names based on your CSV structure
      final List<String> headers = [
        'Name',
        'PAN',
        'CIBIL',
        'DOB',
        'Loan_Type',
        'Sanctioned_Amount',
        'Current_Amount',
        'Credit_Card',
        'Late_Payment',
        'Loan_Tenure',
        'Interest_Rate',
        'Monthly_Income',
        'Monthly_EMI',
        'Previous_Loans',
        'Defaults',
        'Credit_Cards_Count',
        'Credit_Utilization',
        'Loan_Repayment_History',
        'Employment_Type',
        'Existing_EMIs',
        'Savings_Balance',
        'Total_Annual_Income',
        'Debt_to_Income_Ratio'
      ];

      // Parse CSV with proper settings
      List<List<dynamic>> csvTable = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
        fieldDelimiter: ',',
      ).convert(csvData);
      
      if (csvTable.isEmpty) {
        print('Error: CSV file is empty');
        return [];
      }

      print('Total rows in CSV: ${csvTable.length}');

      // Convert to list of maps
      _cachedData = [];
      
      for (var row in csvTable) {
        if (row.length >= 2) { // At least name and PAN should be present
          Map<String, dynamic> map = {};
          
          // Clean and map the values
          for (int i = 0; i < math.min(headers.length, row.length); i++) {
            String value = row[i].toString().trim();
            // Clean the value by removing quotes and extra spaces
            value = value.replaceAll('"', '').trim();
            map[headers[i]] = value;
          }
          
          // Debug print for PAN numbers
          print('Found record - Name: ${map['Name']}, PAN: ${map['PAN']}, CIBIL: ${map['CIBIL']}');
          _cachedData!.add(map);
        }
      }

      print('Successfully loaded ${_cachedData!.length} records from CSV');
      return _cachedData!;
    } catch (e, stackTrace) {
      print('Error loading CSV data: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCibilDataByPan(String panNumber) async {
    try {
      final allData = await loadCibilData();
      if (allData.isEmpty) {
        print('No data loaded from CSV file');
        return [];
      }
      
      // Clean the search PAN
      final searchPan = panNumber.trim().toUpperCase();
      print('Searching for PAN: $searchPan');
      
      final matches = allData.where((record) {
        String csvPan = record['PAN']?.toString().trim().toUpperCase() ?? '';
        // Clean the PAN by removing quotes and extra spaces
        csvPan = csvPan.replaceAll('"', '').trim();
        print('Comparing PAN: "$csvPan" with search PAN: "$searchPan"');
        return csvPan == searchPan;
      }).toList();
      
      if (matches.isEmpty) {
        print('No matches found for PAN: $searchPan');
        // Print some sample records to debug
        print('Sample records from CSV:');
        for (var i = 0; i < math.min(5, allData.length); i++) {
          print('Record $i: ${allData[i]}');
        }
      } else {
        print('Found ${matches.length} matching records');
        print('Matched record details:');
        print('Name: ${matches.first['Name']}');
        print('PAN: ${matches.first['PAN']}');
        print('CIBIL: ${matches.first['CIBIL']}');
      }
      
      return matches;
    } catch (e, stackTrace) {
      print('Error searching for PAN $panNumber: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<void> clearCache() async {
    _cachedData = null;
  }
}
