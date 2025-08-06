import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

class PrincipalDashboardPage extends StatefulWidget {
  const PrincipalDashboardPage({super.key});

  @override
  _PrincipalDashboardPageState createState() => _PrincipalDashboardPageState();
}

class _PrincipalDashboardPageState extends State<PrincipalDashboardPage> {
  static const String _baseUrl = 'http://192.168.1.22:5000';
  String graphFilter = 'Faculties';
  Map<String, dynamic> dashboardStats = {
    'totalFaculties': 0,
    'totalStudents': 0,
    'totalDepartments': 0,
    'departmentWiseData': [],
    'pendingApprovals': 0,
    'pendingApprovalsBreakdown': {
      'leaveApprovals': 0,
      'odLeaveApprovals': 0,
      'facultyApprovals': 0,
      'handoverApprovals': 0,
    },
  };
  List<Map<String, dynamic>> todos = [];
  Map<String, dynamic> todoStats = {
    'total': 0,
    'pending': 0,
    'inProgress': 0,
    'completed': 0,
    'overdue': 0,
  };
  Map<String, dynamic> timetables = {
    'summary': {
      'totalTimetables': 0,
      'totalDepartments': 0,
      'departmentBreakdown': [],
    },
    'timetablesByDepartment': {},
    'allTimetables': [],
  };
  bool showTimetables = false;
  bool showAddTodo = false;
  Map<String, dynamic> newTodo = {
    'title': '',
    'description': '',
    'priority': 'Medium',
    'category': 'Administrative',
    'assignedTo': '',
    'assignedToRole': 'faculty',
    'department': '',
    'dueDate': '',
  };
  bool isLoading = true;
  String? error;
  String? token;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user');
      if (userDataString == null) {
        debugPrint('No user data found in SharedPreferences');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      final fetchedToken = userData['token']?.toString() ?? prefs.getString('authToken') ?? '';
      if (fetchedToken.isEmpty) {
        debugPrint('No token found in SharedPreferences or user data');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      setState(() {
        token = fetchedToken;
      });

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/api/superadmin/faculties/all'), headers: headers),
        http.get(Uri.parse('$_baseUrl/api/superadmin/students/all'), headers: headers),
        http.get(Uri.parse('$_baseUrl/api/superadmin/departments/all'), headers: headers),
        http.get(Uri.parse('$_baseUrl/api/dashboard/principal-pending-approvals'), headers: headers),
        http.get(Uri.parse('$_baseUrl/api/dashboard/principal-all-timetables'), headers: headers),
      ]);

      if (!mounted) return;

      final facultiesRes = responses[0];
      final studentsRes = responses[1];
      final departmentsRes = responses[2];
      final pendingApprovalsRes = responses[3];
      final timetablesRes = responses[4];

      debugPrint('Faculties response: ${facultiesRes.statusCode}');
      debugPrint('Students response: ${studentsRes.statusCode}');
      debugPrint('Departments response: ${departmentsRes.statusCode}');
      debugPrint('Pending Approvals response: ${pendingApprovalsRes.statusCode}');
      debugPrint('Timetables response: ${timetablesRes.statusCode}');

      if (facultiesRes.statusCode == 401 ||
          studentsRes.statusCode == 401 ||
          departmentsRes.statusCode == 401 ||
          pendingApprovalsRes.statusCode == 401 ||
          timetablesRes.statusCode == 401) {
        await prefs.clear();
        debugPrint('Unauthorized: Clearing SharedPreferences and redirecting to login');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      if (facultiesRes.statusCode != 200 ||
          studentsRes.statusCode != 200 ||
          departmentsRes.statusCode != 200 ||
          pendingApprovalsRes.statusCode != 200 ||
          timetablesRes.statusCode != 200) {
        throw Exception('Failed to fetch data: One or more requests failed');
      }

      final facultiesData = jsonDecode(facultiesRes.body);
      final studentsData = jsonDecode(studentsRes.body);
      final departmentsData = jsonDecode(departmentsRes.body);
      final pendingApprovalsData = jsonDecode(pendingApprovalsRes.body);
      final timetablesData = jsonDecode(timetablesRes.body);

      try {
        final todosRes = await http.get(
          Uri.parse('$_baseUrl/api/dashboard/principal-todos-demo'),
          headers: headers,
        );
        if (todosRes.statusCode == 200 && mounted) {
          final todosData = jsonDecode(todosRes.body);
          setState(() {
            todos = List<Map<String, dynamic>>.from(todosData['todos'] ?? []);
            todoStats = todosData['stats']?.cast<String, dynamic>() ?? {
              'total': 0,
              'pending': 0,
              'inProgress': 0,
              'completed': 0,
              'overdue': 0,
            };
          });
        } else {
          debugPrint('Todo endpoint not accessible, using empty state');
          setState(() {
            todos = [];
            todoStats = {
              'total': 0,
              'pending': 0,
              'inProgress': 0,
              'completed': 0,
              'overdue': 0,
            };
          });
        }
      } catch (todoError) {
        debugPrint('Todo fetch error: $todoError');
        if (mounted) {
          setState(() {
            todos = [];
            todoStats = {
              'total': 0,
              'pending': 0,
              'inProgress': 0,
              'completed': 0,
              'overdue': 0,
            };
          });
        }
      }

      final allDepartments = List<Map<String, dynamic>>.from(departmentsData['departmentList'] ?? []);
      final departmentWiseData = allDepartments.map((dept) {
        final facultyCount = (facultiesData['departmentWise'] as List<dynamic>?)?.firstWhere(
              (f) => f['name'] == dept['name'],
          orElse: () => {'count': 0},
        )['count'] ?? 0;
        final studentCount = (studentsData['departmentWise'] as List<dynamic>?)?.firstWhere(
              (s) => s['name'] == dept['name'],
          orElse: () => {'count': 0},
        )['count'] ?? 0;
        return {
          'name': dept['name']?.toString() ?? '',
          'Faculties': facultyCount is int ? facultyCount : 0,
          'Students': studentCount is int ? studentCount : 0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          dashboardStats = {
            'totalFaculties': facultiesData['total'] is int ? facultiesData['total'] : 0,
            'totalStudents': studentsData['total'] is int ? studentsData['total'] : 0,
            'totalDepartments': departmentsData['total'] is int ? departmentsData['total'] : 0,
            'departmentWiseData': departmentWiseData,
            'pendingApprovals': pendingApprovalsData['totalPendingApprovals'] is int ? pendingApprovalsData['totalPendingApprovals'] : 0,
            'pendingApprovalsBreakdown': pendingApprovalsData['breakdown']?.cast<String, dynamic>() ?? {
              'leaveApprovals': 0,
              'odLeaveApprovals': 0,
              'facultyApprovals': 0,
              'handoverApprovals': 0,
            },
          };
          timetables = {
            'summary': timetablesData['summary']?.cast<String, dynamic>() ?? {
              'totalTimetables': 0,
              'totalDepartments': 0,
              'departmentBreakdown': [],
            },
            'timetablesByDepartment': timetablesData['timetablesByDepartment']?.cast<String, dynamic>() ?? {},
            'allTimetables': timetablesData['allTimetables'] ?? [],
          };
        });
      }
    } catch (err) {
      debugPrint('Error fetching data: $err');
      if (mounted) {
        setState(() {
          error = err.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAddTodo() async {
    try {
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/api/dashboard/principal-todos-demo'),
        headers: headers,
        body: jsonEncode(newTodo),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          todos = [result['todo'] as Map<String, dynamic>, ...todos];
          todoStats = {
            ...todoStats,
            'total': (todoStats['total'] as int) + 1,
            'pending': (todoStats['pending'] as int) + 1,
          };
          newTodo = {
            'title': '',
            'description': '',
            'priority': 'Medium',
            'category': 'Administrative',
            'assignedTo': '',
            'assignedToRole': 'faculty',
            'department': '',
            'dueDate': '',
          };
          showAddTodo = false;
        });
      } else {
        throw Exception('Failed to add todo: ${response.statusCode}');
      }
    } catch (err) {
      debugPrint('Error adding todo: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add task')),
      );
    }
  }

  Future<void> _handleUpdateTodo(String id, String status) async {
    try {
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = await http.put(
        Uri.parse('$_baseUrl/api/dashboard/principal-todos-demo/$id'),
        headers: headers,
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final updatedTodo = result['todo'] as Map<String, dynamic>;
        setState(() {
          final oldTodo = todos.firstWhere((t) => t['_id'] == id);
          final oldStatus = oldTodo['status'].toString().toLowerCase().replaceAll(' ', '');
          todos = todos.map((todo) => todo['_id'] == id ? updatedTodo : todo).toList();
          todoStats = {
            ...todoStats,
            oldStatus: (todoStats[oldStatus] as int) - 1,
            status.toLowerCase().replaceAll(' ', ''): (todoStats[status.toLowerCase().replaceAll(' ', '')] as int) + 1,
          };
        });
      } else {
        throw Exception('Failed to update todo: ${response.statusCode}');
      }
    } catch (err) {
      debugPrint('Error updating todo: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update task')),
      );
    }
  }

  Future<void> _handleDeleteTodo(String id) async {
    try {
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/dashboard/principal-todos-demo/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        setState(() {
          final deletedTodo = todos.firstWhere((t) => t['_id'] == id);
          final deletedStatus = deletedTodo['status'].toString().toLowerCase().replaceAll(' ', '');
          todos = todos.where((todo) => todo['_id'] != id).toList();
          todoStats = {
            ...todoStats,
            'total': (todoStats['total'] as int) - 1,
            deletedStatus: (todoStats[deletedStatus] as int) - 1,
          };
        });
      } else {
        throw Exception('Failed to delete todo: ${response.statusCode}');
      }
    } catch (err) {
      debugPrint('Error deleting todo: $err');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete task')),
      );
    }
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return const Color(0xFFDC2626);
      case 'High':
        return const Color(0xFFF97316);
      case 'Medium':
        return const Color(0xFFD97706);
      case 'Low':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF4B5563);
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF16A34A);
      case 'In Progress':
        return const Color(0xFF2563EB);
      case 'Pending':
        return const Color(0xFF4B5563);
      case 'Cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF4B5563);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final padding = EdgeInsets.symmetric(
          horizontal: isMobile ? 12.0 : 24.0,
          vertical: isMobile ? 12.0 : 24.0,
        );
        final fontSizeLarge = isMobile ? 18.0 : 24.0;
        final fontSizeMedium = isMobile ? 14.0 : 18.0;
        final fontSizeSmall = isMobile ? 12.0 : 16.0;
        final fontSizeXSmall = isMobile ? 10.0 : 14.0;

        if (isLoading) {
          return Scaffold(
            body: Container(
              color: const Color(0xFFF9FAFB),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Principal Dashboard...',
                      style: TextStyle(
                        fontSize: fontSizeMedium,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (error != null) {
          return Scaffold(
            body: Container(
              color: const Color(0xFFF9FAFB),
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Principal Dashboard',
                    style: TextStyle(
                      fontSize: fontSizeLarge,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      border: const Border(left: BorderSide(color: Color(0xFFEF4444), width: 4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final newHires = 5; // Mock data
        final budgetUtilization = 75; // Mock data

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Principal Dashboard',
              style: TextStyle(
                fontSize: fontSizeLarge,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            foregroundColor: Colors.white,
          ),
          body: Container(
            color: const Color(0xFFF9FAFB),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Counts
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildStatCard(
                          title: 'Total Faculties',
                          value: dashboardStats['totalFaculties'].toString(),
                          color: const Color(0xFF2563EB),
                          description: 'Active faculty members',
                          fontSizeLarge: fontSizeLarge, // Pass fontSizeLarge
                          fontSizeMedium: fontSizeMedium,
                          fontSizeXSmall: fontSizeXSmall, // Pass fontSizeXSmall
                          fontSizeSmall: fontSizeSmall,
                          isMobile: isMobile,
                        ),
                        _buildStatCard(
                          title: 'Total Students',
                          value: dashboardStats['totalStudents'].toString(),
                          color: const Color(0xFF059669),
                          description: 'Enrolled students',
                          fontSizeLarge: fontSizeLarge, // Pass fontSizeLarge
                          fontSizeMedium: fontSizeMedium,
                          fontSizeXSmall: fontSizeXSmall, // Pass fontSizeXSmall
                          fontSizeSmall: fontSizeSmall,
                          isMobile: isMobile,
                        ),
                        _buildStatCard(
                          title: 'New Hires',
                          value: newHires.toString(),
                          color: const Color(0xFFD97706),
                          description: 'Recent additions',
                          fontSizeLarge: fontSizeLarge, // Pass fontSizeLarge
                          fontSizeMedium: fontSizeMedium,
                          fontSizeXSmall: fontSizeXSmall, // Pass fontSizeXSmall
                          fontSizeSmall: fontSizeSmall,
                          isMobile: isMobile,
                        ),
                        _buildStatCard(
                          title: 'Departments',
                          value: dashboardStats['totalDepartments'].toString(),
                          color: const Color(0xFF7C3AED),
                          description: 'Active departments',
                          fontSizeLarge: fontSizeLarge, // Pass fontSizeLarge
                          fontSizeMedium: fontSizeMedium,
                          fontSizeXSmall: fontSizeXSmall, // Pass fontSizeXSmall
                          fontSizeSmall: fontSizeSmall,
                          isMobile: isMobile,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Additional Stats
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        Container(
                          width: isMobile ? double.infinity : 400,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pending Approvals',
                                style: TextStyle(
                                  fontSize: fontSizeMedium,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dashboardStats['pendingApprovals'].toString(),
                                style: TextStyle(
                                  fontSize: fontSizeLarge,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                              Text(
                                'Requires your attention',
                                style: TextStyle(
                                  fontSize: fontSizeXSmall,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildApprovalRow('Leave Applications', dashboardStats['pendingApprovalsBreakdown']['leaveApprovals'] as int),
                              _buildApprovalRow('OD Applications', dashboardStats['pendingApprovalsBreakdown']['odLeaveApprovals'] as int),
                              _buildApprovalRow('Faculty Approvals', dashboardStats['pendingApprovalsBreakdown']['facultyApprovals'] as int),
                              if ((dashboardStats['pendingApprovalsBreakdown']['handoverApprovals'] as int) > 0)
                                _buildApprovalRow('Handover Requests', dashboardStats['pendingApprovalsBreakdown']['handoverApprovals'] as int),
                            ],
                          ),
                        ),
                        Container(
                          width: isMobile ? double.infinity : 400,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Budget Utilization',
                                style: TextStyle(
                                  fontSize: fontSizeMedium,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$budgetUtilization%',
                                style: TextStyle(
                                  fontSize: fontSizeLarge,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4F46E5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: budgetUtilization / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Graph Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Department-wise Distribution',
                                style: TextStyle(
                                  fontSize: fontSizeMedium,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Symbols.filter_alt, size: 16, color: Color(0xFF6B7280)),
                                  const SizedBox(width: 8),
                                  DropdownButton<String>(
                                    value: graphFilter,
                                    items: const [
                                      DropdownMenuItem(value: 'Faculties', child: Text('Faculties')),
                                      DropdownMenuItem(value: 'Students', child: Text('Students')),
                                    ],
                                    onChanged: (value) => setState(() => graphFilter = value!),
                                    style: TextStyle(fontSize: fontSizeSmall, color: const Color(0xFF4B5563)),
                                    dropdownColor: Colors.white,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              // Bar Chart
                              SizedBox(
                                width: isMobile ? double.infinity : 400,
                                height: isMobile ? 200 : 300,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    barGroups: dashboardStats['departmentWiseData'].asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final dept = entry.value as Map<String, dynamic>;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: (dept[graphFilter] as num?)?.toDouble() ?? 0.0,
                                            color: graphFilter == 'Faculties' ? const Color(0xFF2563EB) : const Color(0xFF059669),
                                            width: 20,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, meta) => Text(
                                            value.toInt().toString(),
                                            style: TextStyle(fontSize: fontSizeXSmall, color: const Color(0xFF4B5563)),
                                          ),
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 50,
                                          getTitlesWidget: (value, meta) {
                                            final dept = dashboardStats['departmentWiseData'][value.toInt()] as Map<String, dynamic>;
                                            return Transform.rotate(
                                              angle: -45 * 3.1416 / 180,
                                              child: Text(
                                                dept['name']?.toString() ?? '',
                                                style: TextStyle(fontSize: fontSizeXSmall, color: const Color(0xFF4B5563)),
                                                textAlign: TextAlign.right,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(),
                                      rightTitles: const AxisTitles(),
                                    ),
                                    gridData: const FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: 10,
                                    ),
                                    borderData: FlBorderData(show: false),
                                  ),
                                ),
                              ),
                              // Pie Chart
                              SizedBox(
                                width: isMobile ? double.infinity : 400,
                                height: isMobile ? 200 : 300,
                                child: PieChart(
                                  PieChartData(
                                    sections: dashboardStats['departmentWiseData'].asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final dept = entry.value as Map<String, dynamic>;
                                      return PieChartSectionData(
                                        value: (dept[graphFilter] as num?)?.toDouble() ?? 0.0,
                                        title: dept['name']?.toString() ?? '',
                                        color: [
                                          const Color(0xFF2563EB),
                                          const Color(0xFF059669),
                                          const Color(0xFFD97706),
                                          const Color(0xFFDC2626),
                                          const Color(0xFF7C3AED),
                                        ][index % 5],
                                        radius: isMobile ? 60 : 80,
                                        titleStyle: TextStyle(fontSize: fontSizeXSmall, color: const Color(0xFF4B5563)),
                                      );
                                    }).toList(),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: isMobile ? 30 : 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Todo List Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daily Tasks Management',
                                style: TextStyle(
                                  fontSize: fontSizeMedium,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => setState(() => showAddTodo = true),
                                icon: const Icon(Symbols.add, size: 16),
                                label: Text('Add Task', style: TextStyle(fontSize: fontSizeSmall)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildTodoStatCard('Total', todoStats['total'] as int, Colors.grey, fontSizeMedium, fontSizeSmall),
                              _buildTodoStatCard('Pending', todoStats['pending'] as int, const Color(0xFFD97706), fontSizeMedium, fontSizeSmall),
                              _buildTodoStatCard('In Progress', todoStats['inProgress'] as int, const Color(0xFF2563EB), fontSizeMedium, fontSizeSmall),
                              _buildTodoStatCard('Completed', todoStats['completed'] as int, const Color(0xFF16A34A), fontSizeMedium, fontSizeSmall),
                              _buildTodoStatCard('Overdue', todoStats['overdue'] as int, const Color(0xFFDC2626), fontSizeMedium, fontSizeSmall),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (showAddTodo)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add New Task',
                                    style: TextStyle(
                                      fontSize: fontSizeMedium,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: [
                                      SizedBox(
                                        width: isMobile ? double.infinity : 200,
                                        child: TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Title',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          style: TextStyle(fontSize: fontSizeSmall),
                                          onChanged: (value) => setState(() => newTodo['title'] = value),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 200,
                                        child: DropdownButtonFormField<String>(
                                          decoration: InputDecoration(
                                            labelText: 'Priority',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          value: newTodo['priority'],
                                          items: const [
                                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                                            DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                                            DropdownMenuItem(value: 'High', child: Text('High')),
                                            DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                                          ],
                                          onChanged: (value) => setState(() => newTodo['priority'] = value!),
                                          style: TextStyle(fontSize: fontSizeSmall),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 200,
                                        child: DropdownButtonFormField<String>(
                                          decoration: InputDecoration(
                                            labelText: 'Category',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          value: newTodo['category'],
                                          items: const [
                                            DropdownMenuItem(value: 'Administrative', child: Text('Administrative')),
                                            DropdownMenuItem(value: 'Academic', child: Text('Academic')),
                                            DropdownMenuItem(value: 'Meeting', child: Text('Meeting')),
                                            DropdownMenuItem(value: 'Review', child: Text('Review')),
                                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                                          ],
                                          onChanged: (value) => setState(() => newTodo['category'] = value!),
                                          style: TextStyle(fontSize: fontSizeSmall),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 200,
                                        child: TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Assigned To',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          style: TextStyle(fontSize: fontSizeSmall),
                                          onChanged: (value) => setState(() => newTodo['assignedTo'] = value),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 200,
                                        child: DropdownButtonFormField<String>(
                                          decoration: InputDecoration(
                                            labelText: 'Department',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          value: newTodo['department'].isEmpty ? null : newTodo['department'],
                                          items: dashboardStats['departmentWiseData'].map<DropdownMenuItem<String>>((dept) {
                                            return DropdownMenuItem(value: dept['name'] as String, child: Text(dept['name'] as String));
                                          }).toList(),
                                          onChanged: (value) => setState(() => newTodo['department'] = value!),
                                          style: TextStyle(fontSize: fontSizeSmall),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 200,
                                        child: TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Due Date',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          style: TextStyle(fontSize: fontSizeSmall),
                                          onTap: () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now(),
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now().add(const Duration(days: 365)),
                                            );
                                            if (date != null) {
                                              setState(() {
                                                newTodo['dueDate'] = DateFormat('yyyy-MM-dd').format(date);
                                              });
                                            }
                                          },
                                          readOnly: true,
                                          controller: TextEditingController(text: newTodo['dueDate']),
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : 400,
                                        child: TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Description',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          style: TextStyle(fontSize: fontSizeSmall),
                                          maxLines: 2,
                                          onChanged: (value) => setState(() => newTodo['description'] = value),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => setState(() => showAddTodo = false),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(fontSize: fontSizeSmall, color: const Color(0xFF4B5563)),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: newTodo['title'].isEmpty ||
                                            newTodo['assignedTo'].isEmpty ||
                                            newTodo['department'].isEmpty ||
                                            newTodo['dueDate'].isEmpty
                                            ? null
                                            : _handleAddTodo,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(
                                          'Add Task',
                                          style: TextStyle(fontSize: fontSizeSmall),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          if (todos.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  const Icon(Symbols.schedule, size: 48, color: Color(0xFF6B7280)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No tasks yet. Add your first task to get started!',
                                    style: TextStyle(
                                      fontSize: fontSizeMedium,
                                      color: const Color(0xFF6B7280),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: todos.map((todo) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              todo['title']?.toString() ?? '',
                                              style: TextStyle(
                                                fontSize: fontSizeMedium,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1F2937),
                                              ),
                                            ),
                                            if (todo['description'] != null && (todo['description'] as String).isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  todo['description'] as String,
                                                  style: TextStyle(
                                                    fontSize: fontSizeSmall,
                                                    color: const Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _buildBadge(todo['priority']?.toString() ?? 'Unknown', getPriorityColor(todo['priority']?.toString() ?? 'Medium')),
                                                _buildBadge(todo['status']?.toString() ?? 'Unknown', getStatusColor(todo['status']?.toString() ?? 'Pending')),
                                                _buildBadge(todo['category']?.toString() ?? 'Unknown', const Color(0xFF4B5563)),
                                                _buildBadge(todo['department']?.toString() ?? 'Unknown', const Color(0xFF2563EB)),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 16,
                                              children: [
                                                Text(
                                                  'Assigned to: ${todo['assignedTo']?.toString() ?? 'Unknown'}',
                                                  style: TextStyle(
                                                    fontSize: fontSizeXSmall,
                                                    color: const Color(0xFF6B7280),
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    const Icon(Symbols.calendar_month, size: 12, color: Color(0xFF6B7280)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Due: ${todo['dueDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(todo['dueDate'] as String)) : 'Unknown'}',
                                                      style: TextStyle(
                                                        fontSize: fontSizeXSmall,
                                                        color: const Color(0xFF6B7280),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (todo['status']?.toString() != 'Completed') ...[
                                            IconButton(
                                              icon: const Icon(Symbols.schedule, size: 16, color: Color(0xFF2563EB)),
                                              onPressed: () => _handleUpdateTodo(todo['_id'] as String, 'In Progress'),
                                              tooltip: 'Mark as In Progress',
                                            ),
                                            IconButton(
                                              icon: const Icon(Symbols.check_circle, size: 16, color: Color(0xFF16A34A)),
                                              onPressed: () => _handleUpdateTodo(todo['_id'] as String, 'Completed'),
                                              tooltip: 'Mark as Completed',
                                            ),
                                          ],
                                          IconButton(
                                            icon: const Icon(Symbols.delete, size: 16, color: Color(0xFFDC2626)),
                                            onPressed: () => _handleDeleteTodo(todo['_id'] as String),
                                            tooltip: 'Delete Task',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Timetables Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'All Department Timetables',
                                style: TextStyle(
                                  fontSize: fontSizeMedium,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => setState(() => showTimetables = !showTimetables),
                                icon: const Icon(Symbols.calendar_month, size: 16),
                                label: Text(
                                  showTimetables ? 'Hide Timetables' : 'View Timetables',
                                  style: TextStyle(fontSize: fontSizeSmall),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildTimetableStatCard(
                                'Total Timetables',
                                timetables['summary']['totalTimetables'].toString(),
                                const Color(0xFF4F46E5),
                                fontSizeMedium,
                                fontSizeSmall,
                              ),
                              _buildTimetableStatCard(
                                'Departments',
                                timetables['summary']['totalDepartments'].toString(),
                                const Color(0xFF7C3AED),
                                fontSizeMedium,
                                fontSizeSmall,
                              ),
                              _buildTimetableStatCard(
                                'Total Semesters',
                                (timetables['summary']['departmentBreakdown'] as List<dynamic>).fold<int>(
                                  0,
                                      (sum, dept) => sum + ((dept['semesters'] as num?)?.toInt() ?? 0),
                                ).toString(),
                                const Color(0xFFEC4899),
                                fontSizeMedium,
                                fontSizeSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: (timetables['summary']['departmentBreakdown'] as List<dynamic>).map((dept) {
                              return Container(
                                width: isMobile ? double.infinity : 300,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dept['department']?.toString() ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: fontSizeMedium,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildTimetableDetail('Timetables', dept['count']?.toString() ?? '0', const Color(0xFF4F46E5)),
                                    _buildTimetableDetail('Semesters', dept['semesters']?.toString() ?? '0', const Color(0xFF7C3AED)),
                                    _buildTimetableDetail('Sections', dept['sections']?.toString() ?? '0', const Color(0xFFEC4899)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          if (showTimetables) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Detailed Timetables by Department',
                              style: TextStyle(
                                fontSize: fontSizeMedium,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (timetables['timetablesByDepartment'].isEmpty)
                              Container(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    const Icon(Symbols.calendar_month, size: 48, color: Color(0xFF6B7280)),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No timetables found',
                                      style: TextStyle(
                                        fontSize: fontSizeMedium,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                children: (timetables['timetablesByDepartment'] as Map<String, dynamic>).entries.map((entry) {
                                  final department = entry.key;
                                  final departmentTimetables = entry.value as List<dynamic>;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Symbols.calendar_month, size: 18, color: Color(0xFF4F46E5)),
                                            const SizedBox(width: 8),
                                            Text(
                                              department,
                                              style: TextStyle(
                                                fontSize: fontSizeMedium,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1F2937),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: departmentTimetables.map((timetable) {
                                            return Container(
                                              width: isMobile ? double.infinity : 250,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF9FAFB),
                                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  _buildTimetableDetail('Semester', timetable['semester']?.toString() ?? 'Unknown', null),
                                                  _buildTimetableDetail('Section', timetable['section']?.toString() ?? 'Unknown', null),
                                                  _buildTimetableDetail('Year', timetable['year']?.toString() ?? 'Unknown', null),
                                                  _buildTimetableDetail(
                                                    'Created',
                                                    timetable['createdAt'] != null
                                                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(timetable['createdAt'] as String))
                                                        : 'Unknown',
                                                    null,
                                                  ),
                                                  _buildTimetableDetail(
                                                    'Modified',
                                                    timetable['lastModified'] != null
                                                        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(timetable['lastModified'] as String))
                                                        : 'Unknown',
                                                    null,
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required String description,
    required double fontSizeLarge, // Added
    required double fontSizeMedium,
    required double fontSizeSmall,
    required double fontSizeXSmall, // Added
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? double.infinity : 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: fontSizeMedium,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSizeLarge,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            description,
            style: TextStyle(
              fontSize: fontSizeXSmall,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoStatCard(String title, int value, Color color, double fontSizeMedium, double fontSizeSmall) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: fontSizeMedium,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSizeSmall,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTimetableStatCard(String title, String value, Color color, double fontSizeMedium, double fontSizeSmall) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: fontSizeMedium,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSizeSmall,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableDetail(String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}