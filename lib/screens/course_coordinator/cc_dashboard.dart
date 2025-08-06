import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class CCDashboard extends StatefulWidget {
  const CCDashboard({super.key});

  @override
  State<CCDashboard> createState() => _CCDashboardState();
}

class _CCDashboardState extends State<CCDashboard> {
  static const String _baseUrl = 'http://192.168.1.33:5000';
  bool loading = true;
  String? error;
  Map<String, dynamic>? userData;
  List<dynamic> facultySubjects = [];
  String timeRange = 'week';
  String todoFilter = 'all';
  String newTodo = '';
  String newTodoPriority = 'medium';
  String newTodoDueDate = '';
  String newTodoCategory = 'assignments';
  int? editingTodo;
  String editText = '';

  // Sample data with explicit types
  final List<Map<String, dynamic>> courseData = [
    {'course': 'CS101', 'enrolled': 45, 'attendance': 92, 'assignments': 15, 'completed': 12},
    {'course': 'CS201', 'enrolled': 38, 'attendance': 88, 'assignments': 18, 'completed': 16},
    {'course': 'CS301', 'enrolled': 42, 'attendance': 95, 'assignments': 12, 'completed': 11},
    {'course': 'CS401', 'enrolled': 35, 'attendance': 85, 'assignments': 20, 'completed': 17},
  ];

  final List<Map<String, dynamic>> attendanceTrends = [
    {'week': 'Week 1', 'CS101': 88.0, 'CS201': 92.0, 'CS301': 85.0, 'CS401': 90.0},
    {'week': 'Week 2', 'CS101': 92.0, 'CS201': 88.0, 'CS301': 93.0, 'CS401': 87.0},
    {'week': 'Week 3', 'CS101': 85.0, 'CS201': 94.0, 'CS301': 90.0, 'CS401': 89.0},
    {'week': 'Week 4', 'CS101': 95.0, 'CS201': 89.0, 'CS301': 88.0, 'CS401': 92.0},
  ];

  final List<Map<String, dynamic>> assignmentStats = [
    {'name': 'Submitted', 'value': 68, 'color': const Color(0xFF10B981)},
    {'name': 'Pending', 'value': 15, 'color': const Color(0xFFF59E0B)},
    {'name': 'Late', 'value': 8, 'color': const Color(0xFFEF4444)},
    {'name': 'Missing', 'value': 9, 'color': const Color(0xFF6B7280)},
  ];

  final List<Color> colors = const [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
  ];

  final Map<String, dynamic> stats = {
    'totalCourses': 4,
    'totalStudents': 160,
    'averageAttendance': 90,
    'pendingAssignments': 32,
    'activeProjects': 8,
    'completionRate': 85,
  };

  final List<Map<String, dynamic>> todos = [
    {'id': 1, 'text': 'Review CS101 assignments', 'completed': false, 'priority': 'high', 'dueDate': '2025-07-10', 'category': 'assignments'},
    {'id': 2, 'text': 'Update course materials for CS201', 'completed': false, 'priority': 'medium', 'dueDate': '2025-07-12', 'category': 'materials'},
    {'id': 3, 'text': 'Prepare midterm exam questions', 'completed': true, 'priority': 'high', 'dueDate': '2025-07-09', 'category': 'exams'},
    {'id': 4, 'text': 'Meet with struggling students', 'completed': false, 'priority': 'low', 'dueDate': '2025-07-15', 'category': 'meetings'},
    {'id': 5, 'text': 'Submit semester planning report', 'completed': false, 'priority': 'high', 'dueDate': '2025-07-11', 'category': 'reports'},
  ];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString('user');
    if (userDataStr != null) {
      return jsonDecode(userDataStr);
    }
    return null;
  }

  Future<void> fetchData() async {
    setState(() => loading = true);
    try {
      final token = await _getToken();
      if (token == null) {
        setState(() => error = 'No auth token found. Please log in again.');
        return;
      }

      final userDataResponse = await _getUserData();
      if (userDataResponse == null) {
        setState(() => error = 'User data not found. Please log in again.');
        return;
      }

      setState(() => userData = userDataResponse);

      if (userData?['employeeId'] != null) {
        await fetchFacultySubjects(userData!['employeeId'], token);
      }
    } catch (e) {
      setState(() => error = 'Error fetching data: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> fetchFacultySubjects(String employeeId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/faculty/subjects/$employeeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            facultySubjects = data['data'] ?? [];
            stats['totalCourses'] = facultySubjects.length;
            stats['totalStudents'] = getTotalStudentsEstimate();
          });
        } else {
          setState(() => error = 'Failed to load subjects');
        }
      } else if (response.statusCode == 401) {
        setState(() => error = 'Token expired or invalid. Please log in again.');
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() => error = 'Failed to load subjects. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => error = 'Error fetching subjects: $e');
    }
  }

  int getTotalStudentsEstimate() {
    final uniqueYearSections = <String>{};
    for (var subject in facultySubjects) {
      uniqueYearSections.add('${subject['year']}-${subject['section']}');
    }
    return uniqueYearSections.length * 45;
  }

  void addTodo() {
    if (newTodo.trim().isNotEmpty) {
      setState(() {
        todos.add({
          'id': DateTime.now().millisecondsSinceEpoch,
          'text': newTodo.trim(),
          'completed': false,
          'priority': newTodoPriority,
          'dueDate': newTodoDueDate,
          'category': newTodoCategory,
          'createdAt': DateTime.now().toIso8601String(),
        });
        newTodo = '';
        newTodoPriority = 'medium';
        newTodoDueDate = '';
        newTodoCategory = 'assignments';
      });
    }
  }

  void toggleTodo(int id) {
    setState(() {
      final index = todos.indexWhere((todo) => todo['id'] == id);
      if (index != -1) {
        todos[index]['completed'] = !todos[index]['completed'];
      }
    });
  }

  void deleteTodo(int id) {
    setState(() {
      todos.removeWhere((todo) => todo['id'] == id);
    });
  }

  void startEditTodo(Map<String, dynamic> todo) {
    setState(() {
      editingTodo = todo['id'];
      editText = todo['text'];
    });
  }

  void saveEditTodo() {
    setState(() {
      final index = todos.indexWhere((todo) => todo['id'] == editingTodo);
      if (index != -1) {
        todos[index]['text'] = editText.trim();
      }
      editingTodo = null;
      editText = '';
    });
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.yellow;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> getFilteredTodos() {
    return todos.where((todo) {
      if (todoFilter == 'completed') return todo['completed'];
      if (todoFilter == 'pending') return !todo['completed'];
      if (todoFilter == 'high') return todo['priority'] == 'high';
      return true;
    }).toList();
  }

  Widget buildStatCard(String title, dynamic value, IconData icon, Color color, double? trend, String? description, double scale) {
    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6 * scale,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 6 * scale),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (description != null) ...[
                SizedBox(height: 4 * scale),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10 * scale,
                  ),
                ),
              ],
              if (trend != null) ...[
                SizedBox(height: 4 * scale),
                Row(
                  children: [
                    Icon(
                      trend >= 0 ? Symbols.trending_up : Symbols.trending_down,
                      size: 14 * scale,
                      color: trend >= 0 ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 4 * scale),
                    Text(
                      '${trend.abs()}%',
                      style: TextStyle(
                        color: trend >= 0 ? Colors.green : Colors.red,
                        fontSize: 10 * scale,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          Container(
            padding: EdgeInsets.all(6 * scale),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Icon(
              icon,
              size: 24 * scale,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.of(context).size.width < 600 ? 0.9 : 1.0; // Scale down for mobile
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'CC Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2553A1), Color(0xFF2B7169)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFEEF2FF),
                Colors.white,
                Color(0xFFE0F7FA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SpinKitCircle(color: Colors.blue, size: 50 * scale),
                SizedBox(height: 12 * scale),
                Text(
                  'Loading data...',
                  style: TextStyle(color: Colors.grey, fontSize: 14 * scale),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Container(
            padding: EdgeInsets.all(24 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12 * scale),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6 * scale)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.error, color: Colors.red, size: 40 * scale),
                SizedBox(height: 12 * scale),
                Text(
                  'Error',
                  style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                SizedBox(height: 6 * scale),
                Text(error!, style: TextStyle(color: Colors.grey, fontSize: 12 * scale)),
                SizedBox(height: 12 * scale),
                ElevatedButton(
                  onPressed: fetchData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8 * scale)),
                  ),
                  child: Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12 * scale)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFEEF2FF),
              Colors.white,
              Color(0xFFE0F7FA),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(12 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(12 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12 * scale),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6 * scale),
                    ],
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('🎯', style: TextStyle(fontSize: 20 * scale)),
                          SizedBox(width: 6 * scale),
                          Expanded(
                            child: Text(
                              'Course Coordinator Dashboard',
                              style: TextStyle(
                                fontSize: 20 * scale,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6 * scale),
                      Text(
                        'Welcome back, ${userData?['name'] ?? 'Course Coordinator'}! Manage your courses and track student progress.',
                        style: TextStyle(
                          fontSize: 14 * scale,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: DropdownButton<String>(
                              value: timeRange,
                              items: const [
                                DropdownMenuItem(value: 'week', child: Text('This Week')),
                                DropdownMenuItem(value: 'month', child: Text('This Month')),
                                DropdownMenuItem(value: 'semester', child: Text('This Semester')),
                              ],
                              onChanged: (value) {
                                setState(() => timeRange = value!);
                              },
                              style: TextStyle(color: Colors.black87, fontSize: 12 * scale),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(8 * scale),
                            ),
                          ),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: fetchData,
                                icon: Icon(Symbols.refresh, size: 14 * scale),
                                label: Text('Refresh', style: TextStyle(fontSize: 12 * scale)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8 * scale),
                                  ),
                                ),
                              ),
                              SizedBox(width: 6 * scale),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.clear();
                                  Navigator.pushReplacementNamed(context, '/login');
                                },
                                icon: Icon(Symbols.logout, size: 14 * scale),
                                label: Text('Logout', style: TextStyle(fontSize: 12 * scale)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8 * scale),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12 * scale),

                // Statistics Cards
                GridView.count(
                  crossAxisCount: isMobile ? 1 : MediaQuery.of(context).size.width > 1200 ? 6 : MediaQuery.of(context).size.width > 800 ? 3 : 2,
                  crossAxisSpacing: 12 * scale,
                  mainAxisSpacing: 12 * scale,
                  childAspectRatio: isMobile ? 3.5 : 2.5, // Adjusted for better mobile fit
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    buildStatCard(
                      'Total Courses',
                      facultySubjects.length,
                      Symbols.book,
                      Colors.blue,
                      5,
                      'Subjects teaching',
                      scale,
                    ),
                    buildStatCard(
                      'Total Students',
                      getTotalStudentsEstimate(),
                      Symbols.groups,
                      Colors.green,
                      8,
                      'Across all subjects',
                      scale,
                    ),
                    buildStatCard(
                      'Avg Attendance',
                      '${stats['averageAttendance']}%',
                      Symbols.person_check,
                      Colors.purple,
                      3,
                      'Across all courses',
                      scale,
                    ),
                    buildStatCard(
                      'Pending Tasks',
                      todos.where((t) => !t['completed']).length,
                      Symbols.list_alt,
                      Colors.orange,
                      -12,
                      'Todo items remaining',
                      scale,
                    ),
                    buildStatCard(
                      'Active Projects',
                      stats['activeProjects'],
                      Symbols.target,
                      Colors.cyan,
                      15,
                      'Ongoing projects',
                      scale,
                    ),
                    buildStatCard(
                      'Completion Rate',
                      '${stats['completionRate']}%',
                      Symbols.book_ribbon,
                      Colors.pink,
                      7,
                      'Overall progress',
                      scale,
                    ),
                  ],
                ),
                SizedBox(height: 12 * scale),

                // Todo List Section
                Container(
                  padding: EdgeInsets.all(12 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12 * scale),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6 * scale),
                    ],
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Symbols.list_alt, color: Colors.indigo, size: 20 * scale),
                          SizedBox(width: 6 * scale),
                          Text(
                            '📝 Faculty Todo List',
                            style: TextStyle(
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12 * scale),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          DropdownButton<String>(
                            value: todoFilter,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Tasks')),
                              DropdownMenuItem(value: 'pending', child: Text('Pending')),
                              DropdownMenuItem(value: 'completed', child: Text('Completed')),
                              DropdownMenuItem(value: 'high', child: Text('High Priority')),
                            ],
                            onChanged: (value) {
                              setState(() => todoFilter = value!);
                            },
                            style: TextStyle(color: Colors.black87, fontSize: 12 * scale),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(8 * scale),
                          ),
                        ],
                      ),
                      SizedBox(height: 8 * scale),
                      Container(
                        padding: EdgeInsets.all(12 * scale),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10 * scale),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8 * scale)),
                                labelText: 'Enter new task...',
                                labelStyle: TextStyle(fontSize: 12 * scale),
                              ),
                              style: TextStyle(fontSize: 12 * scale),
                              onChanged: (value) => setState(() => newTodo = value),
                              onSubmitted: (_) => addTodo(),
                            ),
                            SizedBox(height: 8 * scale),
                            DropdownButtonFormField<String>(
                              value: newTodoPriority,
                              items: const [
                                DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                                DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
                                DropdownMenuItem(value: 'high', child: Text('High Priority')),
                              ],
                              onChanged: (value) {
                                setState(() => newTodoPriority = value!);
                              },
                              style: TextStyle(fontSize: 12 * scale),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8 * scale)),
                                labelText: 'Priority',
                                labelStyle: TextStyle(fontSize: 12 * scale),
                              ),
                            ),
                            SizedBox(height: 8 * scale),
                            TextField(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8 * scale)),
                                labelText: 'Due Date',
                                labelStyle: TextStyle(fontSize: 12 * scale),
                              ),
                              style: TextStyle(fontSize: 12 * scale),
                              controller: TextEditingController(text: newTodoDueDate),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => newTodoDueDate = DateFormat('yyyy-MM-dd').format(picked));
                                }
                              },
                            ),
                            SizedBox(height: 8 * scale),
                            ElevatedButton.icon(
                              onPressed: newTodo.trim().isEmpty ? null : addTodo,
                              icon: Icon(Symbols.add, size: 14 * scale),
                              label: Text('Add Task', style: TextStyle(fontSize: 12 * scale)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8 * scale),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                      getFilteredTodos().isEmpty
                          ? Padding(
                        padding: EdgeInsets.all(24 * scale),
                        child: Column(
                          children: [
                            Icon(Symbols.list_alt, size: 40 * scale, color: Colors.grey),
                            SizedBox(height: 12 * scale),
                            Text(
                              'No tasks found',
                              style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                            SizedBox(height: 6 * scale),
                            Text(
                              'Add your first task above!',
                              style: TextStyle(fontSize: 12 * scale, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: getFilteredTodos().length,
                        itemBuilder: (context, index) {
                          final todo = getFilteredTodos()[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 8 * scale),
                            padding: EdgeInsets.all(12 * scale),
                            decoration: BoxDecoration(
                              color: todo['completed'] ? Colors.green.withOpacity(0.1) : Colors.white,
                              border: Border.all(
                                color: todo['completed'] ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(10 * scale),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: todo['completed'],
                                  onChanged: (value) => toggleTodo(todo['id']),
                                  activeColor: Colors.indigo,
                                  visualDensity: VisualDensity.compact,
                                ),
                                Expanded(
                                  child: editingTodo == todo['id']
                                      ? Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: TextEditingController(text: editText),
                                          onChanged: (value) => setState(() => editText = value),
                                          onSubmitted: (_) => saveEditTodo(),
                                          style: TextStyle(fontSize: 12 * scale),
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8 * scale)),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: saveEditTodo,
                                        icon: Icon(Symbols.save, color: Colors.green, size: 16 * scale),
                                        padding: EdgeInsets.all(4 * scale),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(() {
                                          editingTodo = null;
                                          editText = '';
                                        }),
                                        icon: Icon(Symbols.close, color: Colors.red, size: 16 * scale),
                                        padding: EdgeInsets.all(4 * scale),
                                      ),
                                    ],
                                  )
                                      : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        todo['text'],
                                        style: TextStyle(
                                          fontSize: 14 * scale,
                                          fontWeight: FontWeight.w500,
                                          decoration: todo['completed']
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                          color: todo['completed'] ? Colors.grey : Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4 * scale),
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 6 * scale, vertical: 3 * scale),
                                            decoration: BoxDecoration(
                                              color: getPriorityColor(todo['priority']).withOpacity(0.1),
                                              border: Border.all(
                                                color: getPriorityColor(todo['priority']).withOpacity(0.2),
                                              ),
                                              borderRadius: BorderRadius.circular(6 * scale),
                                            ),
                                            child: Text(
                                              '${todo['priority']} priority',
                                              style: TextStyle(
                                                color: getPriorityColor(todo['priority']),
                                                fontSize: 10 * scale,
                                              ),
                                            ),
                                          ),
                                          if (todo['dueDate'] != null && todo['dueDate'].isNotEmpty) ...[
                                            SizedBox(width: 6 * scale),
                                            Row(
                                              children: [
                                                Icon(Symbols.calendar_month,
                                                    size: 10 * scale, color: Colors.grey),
                                                SizedBox(width: 3 * scale),
                                                Text(
                                                  DateFormat.yMMMd().format(DateTime.parse(todo['dueDate'])),
                                                  style: TextStyle(fontSize: 10 * scale, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (editingTodo != todo['id']) ...[
                                  IconButton(
                                    onPressed: () => startEditTodo(todo),
                                    icon: Icon(Symbols.edit, color: Colors.grey, size: 16 * scale),
                                    padding: EdgeInsets.all(4 * scale),
                                  ),
                                  IconButton(
                                    onPressed: () => deleteTodo(todo['id']),
                                    icon: Icon(Symbols.delete, color: Colors.red, size: 16 * scale),
                                    padding: EdgeInsets.all(4 * scale),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 12 * scale),
                      Container(
                        padding: EdgeInsets.only(top: 12 * scale),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  todos.where((t) => !t['completed']).length.toString(),
                                  style: TextStyle(
                                    fontSize: 20 * scale,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                ),
                                Text(
                                  'Pending',
                                  style: TextStyle(color: Colors.grey, fontSize: 12 * scale),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  todos.where((t) => t['completed']).length.toString(),
                                  style: TextStyle(
                                    fontSize: 20 * scale,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Completed',
                                  style: TextStyle(color: Colors.grey, fontSize: 12 * scale),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  todos.where((t) => t['priority'] == 'high' && !t['completed']).length.toString(),
                                  style: TextStyle(
                                    fontSize: 20 * scale,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                Text(
                                  'High Priority',
                                  style: TextStyle(color: Colors.grey, fontSize: 12 * scale),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12 * scale),

                // Charts Section
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                  crossAxisSpacing: 12 * scale,
                  mainAxisSpacing: 12 * scale,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Attendance Trends Chart
                    Container(
                      padding: EdgeInsets.all(12 * scale),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12 * scale),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6 * scale),
                        ],
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('📈', style: TextStyle(fontSize: 18 * scale)),
                              SizedBox(width: 6 * scale),
                              Text(
                                'Attendance Trends',
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6 * scale),
                          Wrap(
                            spacing: 6 * scale,
                            children: ['CS101', 'CS201', 'CS301', 'CS401'].asMap().entries.map((entry) {
                              final index = entry.key;
                              final course = entry.value;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10 * scale,
                                    height: 10 * scale,
                                    decoration: BoxDecoration(
                                      color: colors[index],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 3 * scale),
                                  Text(
                                    course,
                                    style: TextStyle(fontSize: 10 * scale, color: Colors.grey),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 6 * scale),
                          Text(
                            'Data Points: ${attendanceTrends.length} weeks',
                            style: TextStyle(fontSize: 10 * scale, color: Colors.grey),
                          ),
                          SizedBox(height: 12 * scale),
                          SizedBox(
                            height: 300,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  horizontalInterval: 5,
                                  verticalInterval: 1,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: Colors.grey.withOpacity(0.3),
                                    strokeWidth: 1,
                                    dashArray: [3, 3],
                                  ),
                                  getDrawingVerticalLine: (value) => FlLine(
                                    color: Colors.grey.withOpacity(0.3),
                                    strokeWidth: 1,
                                    dashArray: [3, 3],
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) => Text(
                                        value.toInt().toString(),
                                        style: TextStyle(fontSize: 12 * scale),
                                      ),
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index >= 0 && index < attendanceTrends.length) {
                                          return Text(
                                            attendanceTrends[index]['week'] as String,
                                            style: TextStyle(fontSize: 12 * scale),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                minY: 70,
                                maxY: 100,
                                lineBarsData: ['CS101', 'CS201', 'CS301', 'CS401'].asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final course = entry.value;
                                  return LineChartBarData(
                                    spots: attendanceTrends.asMap().entries.map((e) {
                                      return FlSpot(e.key.toDouble(), (e.value[course] as num).toDouble());
                                    }).toList(),
                                    isCurved: true,
                                    color: colors[index],
                                    barWidth: 3,
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                        radius: 4,
                                        color: colors[index],
                                        strokeWidth: 0,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Assignment Status Chart
                    Container(
                      padding: EdgeInsets.all(12 * scale),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12 * scale),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6 * scale),
                        ],
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text('📝', style: TextStyle(fontSize: 18 * scale)),
                                  SizedBox(width: 6 * scale),
                                  Text(
                                    'Assignment Status',
                                    style: TextStyle(
                                      fontSize: 18 * scale,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: Icon(Symbols.visibility, color: Colors.grey, size: 16 * scale),
                                padding: EdgeInsets.all(4 * scale),
                              ),
                            ],
                          ),
                          SizedBox(height: 12 * scale),
                          SizedBox(
                            height: 300,
                            child: PieChart(
                              PieChartData(
                                sections: assignmentStats.asMap().entries.map((entry) {
                                  final data = entry.value;
                                  final total = assignmentStats.fold<int>(0, (sum, item) => sum + (item['value'] as int));
                                  final percentage = total > 0 ? ((data['value'] as int) / total * 100).toStringAsFixed(0) : '0';
                                  return PieChartSectionData(
                                    color: data['color'] as Color,
                                    value: (data['value'] as int).toDouble(),
                                    title: '${data['name']} $percentage%',
                                    radius: 100,
                                    titleStyle: TextStyle(
                                      fontSize: 12 * scale,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }).toList(),
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}