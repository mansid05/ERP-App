import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_stats.dart';
import '../models/todo.dart';
import '../models/timetable.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  Future<Map<String, dynamic>> fetchDashboardData() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final [
    facultiesRes,
    studentsRes,
    departmentsRes,
    pendingApprovalsRes,
    ] = await Future.wait([
      http.get(Uri.parse('$baseUrl/superadmin/faculties/all'), headers: headers),
      http.get(Uri.parse('$baseUrl/superadmin/students/all'), headers: headers),
      http.get(Uri.parse('$baseUrl/superadmin/departments/all'), headers: headers),
      http.get(Uri.parse('$baseUrl/dashboard/principal-pending-approvals'), headers: headers),
    ]);

    if (facultiesRes.statusCode == 401 ||
        studentsRes.statusCode == 401 ||
        departmentsRes.statusCode == 401 ||
        pendingApprovalsRes.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      throw Exception('Unauthorized. Please login again.');
    }

    if (facultiesRes.statusCode == 200 &&
        studentsRes.statusCode == 200 &&
        departmentsRes.statusCode == 200 &&
        pendingApprovalsRes.statusCode == 200) {
      final facultiesData = jsonDecode(facultiesRes.body);
      final studentsData = jsonDecode(studentsRes.body);
      final departmentsData = jsonDecode(departmentsRes.body);
      final pendingApprovalsData = jsonDecode(pendingApprovalsRes.body);

      final allDepartments = (departmentsData['departmentList'] as List<dynamic>?)?.map((e) => e['name'] as String).toList() ?? [];
      final departmentWiseData = allDepartments.map((dept) {
        final facultyCount = (facultiesData['departmentWise'] as List<dynamic>?)?.firstWhere(
              (f) => f['name'] == dept,
          orElse: () => {'count': 0},
        )['count'] ?? 0;
        final studentCount = (studentsData['departmentWise'] as List<dynamic>?)?.firstWhere(
              (s) => s['name'] == dept,
          orElse: () => {'count': 0},
        )['count'] ?? 0;
        return {
          'name': dept,
          'Faculties': facultyCount,
          'Students': studentCount,
        };
      }).toList();

      return {
        'total': facultiesData['total'] ?? 0,
        'totalStudents': studentsData['total'] ?? 0,
        'totalDepartments': departmentsData['total'] ?? 0,
        'departmentWiseData': departmentWiseData,
        'totalPendingApprovals': pendingApprovalsData['totalPendingApprovals'] ?? 0,
        'breakdown': pendingApprovalsData['breakdown'] ?? {},
      };
    } else {
      throw Exception('Failed to fetch dashboard data');
    }
  }

  Future<Map<String, dynamic>> fetchTimetablesData() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/principal-all-timetables'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      throw Exception('Unauthorized. Please login again.');
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch timetables data');
    }
  }

  Future<Map<String, dynamic>> fetchTodosData() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/principal-todos-demo'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      throw Exception('Unauthorized. Please login again.');
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {'todos': [], 'stats': {}};
    }
  }

  Future<Todo> addTodo(Todo todo) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/dashboard/principal-todos-demo'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(todo.toJson()),
    );

    if (response.statusCode == 200) {
      return Todo.fromJson(jsonDecode(response.body)['todo']);
    } else {
      throw Exception('Failed to add todo');
    }
  }

  Future<Todo> updateTodo(String id, String status) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/dashboard/principal-todos-demo/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode == 200) {
      return Todo.fromJson(jsonDecode(response.body)['todo']);
    } else {
      throw Exception('Failed to update todo');
    }
  }

  Future<void> deleteTodo(String id) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/dashboard/principal-todos-demo/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete todo');
    }
  }
}