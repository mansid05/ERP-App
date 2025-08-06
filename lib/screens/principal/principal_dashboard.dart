import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
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
      final token = userData['token']?.toString() ?? prefs.getString('authToken') ?? '';
      if (token.isEmpty) {
        debugPrint('No token found in SharedPreferences or user data');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

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

      final facultiesData = jsonDecode(responses[0].body);
      final studentsData = jsonDecode(responses[1].body);
      final departmentsData = jsonDecode(responses[2].body);
      final pendingApprovalsData = jsonDecode(responses[3].body);
      final timetablesData = jsonDecode(responses[4].body);

      debugPrint('Faculty data: $facultiesData');
      debugPrint('Student data: $studentsData');
      debugPrint('Department data: $departmentsData');
      debugPrint('Pending approvals data: $pendingApprovalsData');
      debugPrint('Timetables data: $timetablesData');

      if (responses.every((res) => res.statusCode == 200)) {
        final allDepartments = List<Map<String, dynamic>>.from(departmentsData['departmentList'] ?? []);
        final departmentWiseData = allDepartments.map((dept) {
          final facultyCount = (facultiesData['departmentWise'] ?? []).firstWhere(
                (f) => f['name'] == dept['name'],
            orElse: () => {'count': 0},
          )['count'] ?? 0;
          final studentCount = (studentsData['departmentWise'] ?? []).firstWhere(
                (s) => s['name'] == dept['name'],
            orElse: () => {'count': 0},
          )['count'] ?? 0;
          return {
            'name': dept['name'],
            'Faculties': facultyCount,
            'Students': studentCount,
          };
        }).toList();

        setState(() {
          dashboardStats = {
            'totalFaculties': facultiesData['total'] ?? 0,
            'totalStudents': studentsData['total'] ?? 0,
            'totalDepartments': departmentsData['total'] ?? 0,
            'departmentWiseData': departmentWiseData,
            'pendingApprovals': pendingApprovalsData['totalPendingApprovals'] ?? 0,
            'pendingApprovalsBreakdown': pendingApprovalsData['breakdown'] ?? {
              'leaveApprovals': 0,
              'odLeaveApprovals': 0,
              'facultyApprovals': 0,
              'handoverApprovals': 0,
            },
          };
          timetables = {
            'summary': timetablesData['summary'] ?? {
              'totalTimetables': 0,
              'totalDepartments': 0,
              'departmentBreakdown': [],
            },
            'timetablesByDepartment': timetablesData['timetablesByDepartment'] ?? {},
            'allTimetables': timetablesData['allTimetables'] ?? [],
          };
        });

        try {
          final todosRes = await http.get(
            Uri.parse('$_baseUrl/api/dashboard/principal-todos-demo'),
            headers: headers,
          );
          if (todosRes.statusCode == 200 && mounted) {
            final todosData = jsonDecode(todosRes.body);
            debugPrint('Todos data: $todosData');
            setState(() {
              todos = List<Map<String, dynamic>>.from(todosData['todos'] ?? []);
              todoStats = todosData['stats'] ?? {
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
      } else {
        if (responses.any((res) => res.statusCode == 401)) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          debugPrint('Unauthorized: Clearing SharedPreferences and redirecting to login');
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
        throw Exception('Failed to fetch data: ${responses.map((r) => r.statusCode).join(', ')}');
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? '';
      final response = await http.post(
        Uri.parse('$_baseUrl/api/dashboard/principal-todos-demo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(newTodo),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          todos = [Map<String, dynamic>.from(result['todo'] ?? {}), ...todos];
          todoStats = {
            ...todoStats,
            'total': todoStats['total'] + 1,
            'pending': todoStats['pending'] + 1,
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? '';
      final response = await http.put(
        Uri.parse('$_baseUrl/api/dashboard/principal-todos-demo/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final updatedTodo = Map<String, dynamic>.from(result['todo'] ?? {});
        if (updatedTodo.isEmpty) {
          throw Exception('Invalid todo data returned');
        }
        final oldTodo = todos.firstWhere((t) => t['_id'] == id, orElse: () => {});
        if (oldTodo.isEmpty) {
          throw Exception('Todo not found');
        }
        setState(() {
          todos = todos.map((todo) {
            return todo['_id'] == id ? updatedTodo : todo;
          }).toList();
          todoStats = {
            ...todoStats,
            oldTodo['status'].toLowerCase().replaceAll(' ', ''): (todoStats[oldTodo['status'].toLowerCase().replaceAll(' ', '')] as int) - 1,
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? '';
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/dashboard/principal-todos-demo/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final deletedTodo = todos.firstWhere((t) => t['_id'] == id, orElse: () => {});
        if (deletedTodo.isEmpty) {
          throw Exception('Todo not found');
        }
        setState(() {
          todos = todos.where((todo) => todo['_id'] != id).toList();
          todoStats = {
            ...todoStats,
            'total': (todoStats['total'] as int) - 1,
            deletedTodo['status'].toLowerCase().replaceAll(' ', ''): (todoStats[deletedTodo['status'].toLowerCase().replaceAll(' ', '')] as int) - 1,
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
        return const Color(0xFF6B7280);
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF16A34A);
      case 'In Progress':
        return const Color(0xFF2563EB);
      case 'Pending':
        return const Color(0xFF6B7280);
      case 'Cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  final List<Color> chartColors = [
    const Color(0xFF2563EB),
    const Color(0xFF059669),
    const Color(0xFFD97706),
    const Color(0xFFDC2626),
    const Color(0xFF7C3AED),
  ];

  @override
  Widget build(BuildContext context) {
    final newHires = 5; // Mock data
    final budgetUtilization = 75; // Mock data

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
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            height: 16,
                            width: constraints.maxWidth * 0.25,
                            color: const Color(0xFFE5E7EB),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: List.generate(
                              4,
                                  (_) => Container(
                                width: isMobile ? double.infinity : constraints.maxWidth * 0.22,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      height: 24,
                                      width: double.infinity,
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 32,
                                      width: double.infinity,
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: isMobile ? 240 : 320,
                            color: const Color(0xFFE5E7EB),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                      style: TextStyle(
                        fontSize: fontSizeSmall,
                        color: const Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

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
                          fontSizeMedium: fontSizeMedium,
                          fontSizeSmall: fontSizeSmall,
                          fontSizeXSmall: fontSizeXSmall,
                          isMobile: isMobile,
                        ),
                        _buildStatCard(
                          title: 'Total Students',
                          value: dashboardStats['totalStudents'].toString(),
                          color: const Color(0xFF059669),
                          description: 'Enrolled students',
                          fontSizeMedium: fontSizeMedium,
                          fontSizeSmall: fontSizeSmall,
                          fontSizeXSmall: fontSizeXSmall,
                          isMobile: isMobile,
                        ),
                        _buildStatCard(
                          title: 'New Hires',
                          value: newHires.toString(),
                          color: const Color(0xFFF97316),
                          description: 'Recent additions',
                          fontSizeMedium: fontSizeMedium,
                          fontSizeSmall: fontSizeSmall,
                          fontSizeXSmall: fontSizeXSmall,
                          isMobile: isMobile,
                        ),
                        _buildStatCard(
                          title: 'Departments',
                          value: dashboardStats['totalDepartments'].toString(),
                          color: const Color(0xFF7C3AED),
                          description: 'Active departments',
                          fontSizeMedium: fontSizeMedium,
                          fontSizeSmall: fontSizeSmall,
                          fontSizeXSmall: fontSizeXSmall,
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
                          width: isMobile ? double.infinity : constraints.maxWidth * 0.48,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                  color: const Color(0xFFF97316),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Requires your attention',
                                style: TextStyle(
                                  fontSize: fontSizeXSmall,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: [
                                  _buildApprovalRow(
                                    label: 'Leave Applications',
                                    value: dashboardStats['pendingApprovalsBreakdown']['leaveApprovals'] ?? 0,
                                    fontSizeXSmall: fontSizeXSmall,
                                  ),
                                  _buildApprovalRow(
                                    label: 'OD Applications',
                                    value: dashboardStats['pendingApprovalsBreakdown']['odLeaveApprovals'] ?? 0,
                                    fontSizeXSmall: fontSizeXSmall,
                                  ),
                                  _buildApprovalRow(
                                    label: 'Faculty Approvals',
                                    value: dashboardStats['pendingApprovalsBreakdown']['facultyApprovals'] ?? 0,
                                    fontSizeXSmall: fontSizeXSmall,
                                  ),
                                  if ((dashboardStats['pendingApprovalsBreakdown']['handoverApprovals'] ?? 0) > 0)
                                    _buildApprovalRow(
                                      label: 'Handover Requests',
                                      value: dashboardStats['pendingApprovalsBreakdown']['handoverApprovals'] ?? 0,
                                      fontSizeXSmall: fontSizeXSmall,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: isMobile ? double.infinity : constraints.maxWidth * 0.48,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
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
                              LinearProgressIndicator(
                                value: budgetUtilization / 100,
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
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
                        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                    style: TextStyle(fontSize: fontSizeSmall, color: const Color(0xFF1F2937)),
                                    dropdownColor: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
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
                              Container(
                                height: isMobile ? 240 : 320,
                                width: isMobile ? double.infinity : constraints.maxWidth * 0.48,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipColor: (group) => const Color(0xFF1F2937).withOpacity(0.8),
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          final dept = dashboardStats['departmentWiseData'][groupIndex]['name'] ?? 'Unknown';
                                          final value = rod.toY;
                                          return BarTooltipItem(
                                            '$dept\n${graphFilter}: $value',
                                            TextStyle(
                                              color: Colors.white,
                                              fontSize: fontSizeXSmall,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          );
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) => Text(
                                            value.toInt().toString(),
                                            style: TextStyle(fontSize: fontSizeXSmall, color: const Color(0xFF6B7280)),
                                          ),
                                          reservedSize: 30,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index < dashboardStats['departmentWiseData'].length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8),
                                                child: Transform.rotate(
                                                  angle: -45 * 3.14159 / 180,
                                                  child: Text(
                                                    dashboardStats['departmentWiseData'][index]['name'] ?? '',
                                                    style: TextStyle(fontSize: fontSizeXSmall, color: const Color(0xFF6B7280)),
                                                  ),
                                                ),
                                              );
                                            }
                                            return const Text('');
                                          },
                                          reservedSize: 50,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(),
                                      rightTitles: const AxisTitles(),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: 10,
                                      getDrawingHorizontalLine: (value) => FlLine(
                                        color: const Color(0xFFE5E7EB),
                                        strokeWidth: 1,
                                        dashArray: [3, 3],
                                      ),
                                    ),
                                    barGroups: dashboardStats['departmentWiseData'].asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final dept = entry.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: (dept[graphFilter] ?? 0).toDouble(),
                                            color: graphFilter == 'Faculties' ? const Color(0xFF2563EB) : const Color(0xFF059669),
                                            width: 20,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              Container(
                                height: isMobile ? 240 : 320,
                                width: isMobile ? double.infinity : constraints.maxWidth * 0.48,
                                child: PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                        if (pieTouchResponse != null && pieTouchResponse.touchedSection != null) {
                                          // Handle touch if needed
                                        }
                                      },
                                    ),
                                    sections: dashboardStats['departmentWiseData'].asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final dept = entry.value;
                                      return PieChartSectionData(
                                        value: (dept[graphFilter] ?? 0).toDouble(),
                                        title: (dept[graphFilter] ?? 0).toString(),
                                        color: chartColors[index % chartColors.length],
                                        radius: isMobile ? 60 : 80,
                                        titleStyle: TextStyle(
                                          fontSize: fontSizeXSmall,
                                          color: const Color(0xFF4B5563),
                                        ),
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
                        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                              _buildTodoStatCard('Total', todoStats['total'] ?? 0, Colors.grey.shade50, const Color(0xFF1F2937), fontSizeMedium, fontSizeSmall, isMobile),
                              _buildTodoStatCard('Pending', todoStats['pending'] ?? 0, const Color(0xFFFFF7ED), const Color(0xFFD97706), fontSizeMedium, fontSizeSmall, isMobile),
                              _buildTodoStatCard('In Progress', todoStats['inProgress'] ?? 0, const Color(0xFFDBEAFE), const Color(0xFF2563EB), fontSizeMedium, fontSizeSmall, isMobile),
                              _buildTodoStatCard('Completed', todoStats['completed'] ?? 0, const Color(0xFFD1FAE5), const Color(0xFF16A34A), fontSizeMedium, fontSizeSmall, isMobile),
                              _buildTodoStatCard('Overdue', todoStats['overdue'] ?? 0, const Color(0xFFFEE2E2), const Color(0xFFDC2626), fontSizeMedium, fontSizeSmall, isMobile),
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
                                          items: ['Low', 'Medium', 'High', 'Urgent']
                                              .map((priority) => DropdownMenuItem(value: priority, child: Text(priority)))
                                              .toList(),
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
                                          items: ['Administrative', 'Academic', 'Meeting', 'Review', 'Other']
                                              .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                                              .toList(),
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
                                          items: dashboardStats['departmentWiseData']
                                              .map<DropdownMenuItem<String>>((dept) => DropdownMenuItem(
                                            value: dept['name'],
                                            child: Text(dept['name'] ?? ''),
                                          ))
                                              .toList(),
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
                                            suffixIcon: IconButton(
                                              icon: const Icon(Symbols.calendar_today),
                                              onPressed: () async {
                                                final date = await showDatePicker(
                                                  context: context,
                                                  initialDate: DateTime.now(),
                                                  firstDate: DateTime.now(),
                                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                                );
                                                if (date != null) {
                                                  setState(() => newTodo['dueDate'] = date.toIso8601String().split('T')[0]);
                                                }
                                              },
                                            ),
                                          ),
                                          style: TextStyle(fontSize: fontSizeSmall),
                                          controller: TextEditingController(text: newTodo['dueDate']),
                                          readOnly: true,
                                        ),
                                      ),
                                      SizedBox(
                                        width: isMobile ? double.infinity : constraints.maxWidth - 32,
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
                                        child: Text('Cancel', style: TextStyle(fontSize: fontSizeSmall, color: const Color(0xFF6B7280))),
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
                                        child: Text('Add Task', style: TextStyle(fontSize: fontSizeSmall)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          if (todos.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const Icon(Symbols.schedule, size: 48, color: Color(0xFF9CA3AF)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No tasks yet. Add your first task to get started!',
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
                              children: todos.map((todo) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            todo['title'] ?? '',
                                            style: TextStyle(
                                              fontSize: fontSizeMedium,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF1F2937),
                                            ),
                                          ),
                                          if (todo['description']?.isNotEmpty ?? false)
                                            Text(
                                              todo['description'],
                                              style: TextStyle(
                                                fontSize: fontSizeSmall,
                                                color: const Color(0xFF6B7280),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: getPriorityColor(todo['priority'] ?? 'Medium').withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  todo['priority'] ?? 'Medium',
                                                  style: TextStyle(
                                                    fontSize: fontSizeXSmall,
                                                    fontWeight: FontWeight.w600,
                                                    color: getPriorityColor(todo['priority'] ?? 'Medium'),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: getStatusColor(todo['status'] ?? 'Pending').withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  todo['status'] ?? 'Pending',
                                                  style: TextStyle(
                                                    fontSize: fontSizeXSmall,
                                                    fontWeight: FontWeight.w600,
                                                    color: getStatusColor(todo['status'] ?? 'Pending'),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE5E7EB),
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  todo['category'] ?? 'Administrative',
                                                  style: TextStyle(
                                                    fontSize: fontSizeXSmall,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDBEAFE),
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  todo['department'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: fontSizeXSmall,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF2563EB),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 16,
                                            children: [
                                              Text(
                                                'Assigned to: ${todo['assignedTo'] ?? ''}',
                                                style: TextStyle(
                                                  fontSize: fontSizeXSmall,
                                                  color: const Color(0xFF6B7280),
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Symbols.calendar_today, size: 12, color: Color(0xFF6B7280)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Due: ${todo['dueDate'] != null ? DateTime.parse(todo['dueDate']).toLocal().toIso8601String().split('T')[0] : ''}',
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
                                    const SizedBox(width: 8),
                                    if (todo['status'] != 'Completed')
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Symbols.schedule, size: 16, color: Color(0xFF2563EB)),
                                            onPressed: () => _handleUpdateTodo(todo['_id'] ?? '', 'In Progress'),
                                            tooltip: 'Mark as In Progress',
                                          ),
                                          IconButton(
                                            icon: const Icon(Symbols.check_circle, size: 16, color: Color(0xFF16A34A)),
                                            onPressed: () => _handleUpdateTodo(todo['_id'] ?? '', 'Completed'),
                                            tooltip: 'Mark as Completed',
                                          ),
                                        ],
                                      ),
                                    IconButton(
                                      icon: const Icon(Symbols.delete, size: 16, color: Color(0xFFDC2626)),
                                      onPressed: () => _handleDeleteTodo(todo['_id'] ?? ''),
                                      tooltip: 'Delete Task',
                                    ),
                                  ],
                                ),
                              )).toList(),
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
                        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                icon: const Icon(Symbols.calendar_today, size: 16),
                                label: Text(showTimetables ? 'Hide Timetables' : 'View Timetables', style: TextStyle(fontSize: fontSizeSmall)),
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
                                title: 'Total Timetables',
                                value: timetables['summary']['totalTimetables']?.toString() ?? '0',
                                color: const Color(0xFF4F46E5),
                                fontSizeMedium: fontSizeMedium,
                                fontSizeSmall: fontSizeSmall,
                                isMobile: isMobile,
                              ),
                              _buildTimetableStatCard(
                                title: 'Departments',
                                value: timetables['summary']['totalDepartments']?.toString() ?? '0',
                                color: const Color(0xFF7C3AED),
                                fontSizeMedium: fontSizeMedium,
                                fontSizeSmall: fontSizeSmall,
                                isMobile: isMobile,
                              ),
                              _buildTimetableStatCard(
                                title: 'Total Semesters',
                                value: (timetables['summary']['departmentBreakdown'] as List? ?? [])
                                    .fold<int>(0, (sum, dept) => sum + (dept['semesters'] as int? ?? 0))
                                    .toString(),
                                color: const Color(0xFFEC4899),
                                fontSizeMedium: fontSizeMedium,
                                fontSizeSmall: fontSizeSmall,
                                isMobile: isMobile,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: (timetables['summary']['departmentBreakdown'] as List? ?? []).map((dept) => Container(
                              width: isMobile ? double.infinity : constraints.maxWidth * 0.3,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dept['department'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: fontSizeMedium,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildTimetableRow('Timetables', dept['count'] ?? 0, const Color(0xFF4F46E5), fontSizeXSmall),
                                  _buildTimetableRow('Semesters', dept['semesters'] ?? 0, const Color(0xFF7C3AED), fontSizeXSmall),
                                  _buildTimetableRow('Sections', dept['sections'] ?? 0, const Color(0xFFEC4899), fontSizeXSmall),
                                ],
                              ),
                            )).toList(),
                          ),
                          if (showTimetables)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                if ((timetables['timetablesByDepartment'] as Map).isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      children: [
                                        const Icon(Symbols.calendar_today, size: 48, color: Color(0xFF9CA3AF)),
                                        const SizedBox(height: 8),
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
                                    children: (timetables['timetablesByDepartment'] as Map).entries.map((entry) {
                                      final department = entry.key;
                                      final departmentTimetables = entry.value as List;
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFE5E7EB)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Symbols.calendar_today, size: 18, color: Color(0xFF4F46E5)),
                                                const SizedBox(width: 8),
                                                Text(
                                                  department ?? 'Unknown',
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
                                              children: departmentTimetables.map((timetable) => Container(
                                                width: isMobile ? double.infinity : constraints.maxWidth * 0.3,
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF9FAFB),
                                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _buildTimetableRow('Semester', timetable['semester'] ?? '', null, fontSizeXSmall),
                                                    _buildTimetableRow('Section', timetable['section'] ?? '', null, fontSizeXSmall),
                                                    _buildTimetableRow('Year', timetable['year'] ?? '', null, fontSizeXSmall),
                                                    _buildTimetableRow(
                                                      'Created',
                                                      timetable['createdAt'] != null
                                                          ? DateTime.parse(timetable['createdAt']).toLocal().toIso8601String().split('T')[0]
                                                          : '',
                                                      null,
                                                      fontSizeXSmall,
                                                    ),
                                                    _buildTimetableRow(
                                                      'Modified',
                                                      timetable['lastModified'] != null
                                                          ? DateTime.parse(timetable['lastModified']).toLocal().toIso8601String().split('T')[0]
                                                          : '',
                                                      null,
                                                      fontSizeXSmall,
                                                    ),
                                                  ],
                                                ),
                                              )).toList(),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
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
    required double fontSizeMedium,
    required double fontSizeSmall,
    required double fontSizeXSmall,
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? double.infinity : 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
              fontSize: isMobile ? 18.0 : 24.0, // Use fontSizeLarge equivalent
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
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

  Widget _buildApprovalRow({
    required String label,
    required int value,
    required double fontSizeXSmall,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSizeXSmall,
              color: const Color(0xFF6B7280),
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: fontSizeXSmall,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoStatCard(
      String title,
      int value,
      Color bgColor,
      Color textColor,
      double fontSizeMedium,
      double fontSizeSmall,
      bool isMobile,
      ) {
    return Container(
      width: isMobile ? double.infinity : 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: fontSizeMedium,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSizeSmall,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableStatCard({
    required String title,
    required String value,
    required Color color,
    required double fontSizeMedium,
    required double fontSizeSmall,
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? double.infinity : 120,
      padding: const EdgeInsets.all(12),
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

  Widget _buildTimetableRow(String label, dynamic value, Color? color, double fontSizeXSmall) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSizeXSmall,
              color: const Color(0xFF6B7280),
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: fontSizeXSmall,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}