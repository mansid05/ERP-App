import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_data.dart';
import '../models/status_data.dart';
import '../models/employee_profile.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api/faculty';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<DashboardData> fetchDashboardData(String financialYear) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/data?financialYear=$financialYear'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      throw Exception('Unauthorized. Please login again.');
    }

    if (response.statusCode == 200) {
      return DashboardData.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('HTTP error! status: ${response.statusCode}');
    }
  }

  Future<StatusData> fetchStatusData(String financialYear) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/status?financialYear=$financialYear'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      throw Exception('Unauthorized. Please login again.');
    }

    if (response.statusCode == 200) {
      return StatusData.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('HTTP error! status: ${response.statusCode}');
    }
  }

  Future<EmployeeProfile> fetchEmployeeProfile(
      String employeeName, String financialYear) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse(
          '$baseUrl/employee/${Uri.encodeComponent(employeeName)}/profile?financialYear=$financialYear'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return EmployeeProfile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('HTTP error! status: ${response.statusCode}');
    }
  }

  Future<void> autoGeneratePF(String employeeName, String financialYear) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.post(
      Uri.parse(
          '$baseUrl/employee/${Uri.encodeComponent(employeeName)}/auto-generate-pf'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'financialYear': financialYear,
        'ptState': 'Karnataka',
      }),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to generate PF');
    }
  }

  Future<Map<String, dynamic>> bulkGeneratePF(String financialYear) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/bulk-operations'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'operation': 'generate-all-pf',
        'financialYear': financialYear,
        'ptState': 'Karnataka',
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to perform bulk operation');
    }
  }
}