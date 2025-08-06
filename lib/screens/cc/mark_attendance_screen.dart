import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:fl_chart/fl_chart.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  List<dynamic> subjects = [];
  String expandedSubject = '';
  List<dynamic> students = [];
  List<String> selectedStudents = [];
  List<dynamic> filteredAttendance = [];
  bool loading = true;
  String? error;
  bool isUpdating = false;
  Map<String, dynamic> attendanceStats = {};
  Map<String, String> studentNotes = {};
  Map<String, dynamic>? subjectDetails;
  bool loadingSubjectDetails = false;
  String queryType = 'day';
  String queryDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String queryFrom = '';
  String queryTo = '';
  int queryMonth = DateTime.now().month;
  int queryYear = DateTime.now().year;
  bool filterLoading = false;
  int filteredPage = 1;
  int filteredTotalPages = 1;
  final int entriesPerPage = 10;
  bool attendanceMarkedToday = false;
  bool checkingTodayAttendance = false;
  int? todayClassAttendance;
  int? monthlyClassAttendance;
  bool monthlyAttendanceLoading = false;
  final GlobalKey logsKey = GlobalKey();
  static const String _baseUrl = 'http://192.168.1.33:5000';

  @override
  void initState() {
    super.initState();
    fetchSubjects();
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

  Future<void> fetchSubjects() async {
    setState(() => loading = true);
    try {
      final token = await _getToken();
      final userData = await _getUserData();
      final employeeId = userData?['employeeId'];
      if (employeeId == null) {
        setState(() => error = 'Employee ID not found. Please log in again.');
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/faculty/subjects/$employeeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() => subjects = data['data'] ?? []);
        } else {
          setState(() => error = 'Failed to load subjects');
        }
      } else {
        setState(() => error = 'Failed to load subjects. Please try again.');
      }
    } catch (e) {
      setState(() => error = 'Failed to load subjects. Please try again.');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> fetchSubjectDetails(String subjectId) async {
    setState(() => loadingSubjectDetails = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/faculty/markattendance/subject-details/$subjectId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() => subjectDetails = data['data']);
        } else {
          setState(() => subjectDetails = null);
        }
      } else {
        setState(() => subjectDetails = null);
      }
    } catch (e) {
      setState(() => subjectDetails = null);
    } finally {
      setState(() => loadingSubjectDetails = false);
    }
  }

  Future<void> fetchStudents(String subjectId) async {
    setState(() {
      loading = true;
      students = [];
      attendanceStats = {};
    });
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/faculty/markattendance/students/$subjectId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() => students = data['data'] ?? []);
          // Initialize attendanceStats for each student
          for (var student in students) {
            attendanceStats[student['_id']] = {
              'monthly': {'percentage': 0, 'total': 0, 'present': 0, 'absent': 0},
              'overall': {'percentage': 0, 'total': 0, 'present': 0, 'absent': 0},
              'error': false,
            };
          }
          fetchAttendanceStats(students, subjectId);
        } else {
          setState(() => error = 'Failed to load students for this subject');
        }
      } else {
        setState(() => error = 'Failed to load students. Please try again.');
      }
    } catch (e) {
      setState(() => error = 'Failed to load students. Please try again.');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> fetchAttendanceStats(List<dynamic> students, String subjectId) async {
    try {
      final token = await _getToken();
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;

      final statsPromises = students.map((student) async {
        try {
          final monthlyResponse = await http.get(
            Uri.parse('$_baseUrl/api/student-attendance/${student['_id']}/$subjectId/monthly?month=$month&year=$year'),
            headers: {'Authorization': 'Bearer $token'},
          );
          final overallResponse = await http.get(
            Uri.parse('$_baseUrl/api/student-attendance/${student['_id']}/$subjectId/overall'),
            headers: {'Authorization': 'Bearer $token'},
          );

          return {
            'studentId': student['_id'],
            'monthly': jsonDecode(monthlyResponse.body),
            'overall': jsonDecode(overallResponse.body),
          };
        } catch (e) {
          return {
            'studentId': student['_id'],
            'monthly': {'percentage': 0, 'total': 0, 'present': 0, 'absent': 0},
            'overall': {'percentage': 0, 'total': 0, 'present': 0, 'absent': 0},
            'error': true,
          };
        }
      }).toList();

      final results = await Future.wait(statsPromises);
      final statsObject = <String, dynamic>{};
      for (var result in results) {
        statsObject[result['studentId']] = {
          'monthly': result['monthly'],
          'overall': result['overall'],
          'error': result['error'] ?? false,
        };
      }

      setState(() => attendanceStats = statsObject);
    } catch (e) {
      setState(() {
        for (var student in students) {
          attendanceStats[student['_id']] = {
            'monthly': {'percentage': 0, 'total': 0, 'present': 0, 'absent': 0},
            'overall': {'percentage': 0, 'total': 0, 'present': 0, 'absent': 0},
            'error': true,
          };
        }
      });
    }
  }

  Future<void> checkTodayAttendance(String subjectId) async {
    setState(() => checkingTodayAttendance = true);
    try {
      final userData = await _getUserData();
      final employeeId = userData?['employeeId'];
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await http.get(
        Uri.parse('$_baseUrl/api/faculty/attendance/query?facultyId=$employeeId&subjectId=$subjectId&type=day&date=$today&page=1&limit=1'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['data'] != null && data['data'].isNotEmpty) {
          final todayRecords = data['data'];
          final presentCount = todayRecords.where((record) => record['status'] == 'present').length;
          final totalCount = todayRecords.length;
          final classPercentage = totalCount > 0 ? ((presentCount / totalCount) * 100).round() : 0;
          setState(() {
            attendanceMarkedToday = true;
            todayClassAttendance = classPercentage;
          });
        } else {
          setState(() {
            attendanceMarkedToday = false;
            todayClassAttendance = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        attendanceMarkedToday = false;
        todayClassAttendance = null;
      });
    } finally {
      setState(() => checkingTodayAttendance = false);
    }
  }

  Future<void> calculateMonthlyClassAttendance(String subjectId) async {
    setState(() => monthlyAttendanceLoading = true);
    try {
      final userData = await _getUserData();
      final employeeId = userData?['employeeId'];
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
      final startDate = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
      final endDate = DateFormat('yyyy-MM-dd').format(lastDayOfMonth);

      final response = await http.get(
        Uri.parse('$_baseUrl/api/faculty/attendance/query?facultyId=$employeeId&subjectId=$subjectId&type=range&from=$startDate&to=$endDate&page=1&limit=1000'),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['data'] != null && data['data'].isNotEmpty) {
          final monthlyRecords = data['data'];
          final presentCount = monthlyRecords.where((record) => record['status'] == 'present').length;
          final totalCount = monthlyRecords.length;
          final monthlyPercentage = totalCount > 0 ? ((presentCount / totalCount) * 100).round() : 0;
          setState(() => monthlyClassAttendance = monthlyPercentage);
        } else {
          setState(() => monthlyClassAttendance = null);
        }
      }
    } catch (e) {
      setState(() => monthlyClassAttendance = null);
    } finally {
      setState(() => monthlyAttendanceLoading = false);
    }
  }

  Future<void> markAttendance(String status) async {
    if (selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student')),
      );
      return;
    }

    setState(() => isUpdating = true);
    try {
      final token = await _getToken();
      final userData = await _getUserData();
      final facultyId = userData?['employeeId'];
      List<String> studentsToMarkPresent = [];

      if (status == 'present') {
        studentsToMarkPresent = selectedStudents;
      } else {
        studentsToMarkPresent = students
            .where((student) => !selectedStudents.contains(student['_id']))
            .map((student) => student['_id'] as String)
            .toList();
      }

      final totalStudents = students.length;
      final presentCount = status == 'present' ? selectedStudents.length : totalStudents - selectedStudents.length;
      final classAttendancePercent = totalStudents > 0 ? ((presentCount / totalStudents) * 100).round() : 0;

      final attendanceData = {
        'subjectId': expandedSubject,
        'facultyId': facultyId,
        'selectedStudents': studentsToMarkPresent,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/faculty/markattendance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(attendanceData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attendance marked successfully! Today\'s Class Attendance: $classAttendancePercent%')),
          );
          setState(() {
            selectedStudents = [];
            attendanceMarkedToday = true;
            todayClassAttendance = classAttendancePercent;
          });
          fetchAttendanceStats(students, expandedSubject);
          calculateMonthlyClassAttendance(expandedSubject);
        } else {
          if (data['alreadyMarked']) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Attendance has already been marked for today for this subject!')),
            );
            setState(() => attendanceMarkedToday = true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? 'Failed to mark attendance')),
            );
          }
        }
      }
    } catch (e) {
      if (e is http.ClientException && e.message.contains('400') && jsonDecode(e.message)['alreadyMarked']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance has already been marked for today for this subject!')),
        );
        setState(() => attendanceMarkedToday = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark attendance. Please try again.')),
        );
      }
    } finally {
      setState(() => isUpdating = false);
    }
  }

  void toggleStudentSelection(String studentId) {
    setState(() {
      if (selectedStudents.contains(studentId)) {
        selectedStudents.remove(studentId);
      } else {
        selectedStudents.add(studentId);
      }
    });
  }

  void selectAllStudents() {
    setState(() {
      if (selectedStudents.length == students.length) {
        selectedStudents = [];
      } else {
        selectedStudents = students.map((s) => s['_id'] as String).toList();
      }
    });
  }

  Future<void> handleFilterClick() async {
    setState(() {
      filterLoading = true;
      filteredPage = 1;
    });

    final userData = await _getUserData();
    final employeeId = userData?['employeeId'];
    final params = <String, dynamic>{
      'facultyId': employeeId,
      'subjectId': expandedSubject,
      'type': queryType,
      'page': 1,
      'limit': entriesPerPage,
    };

    if (queryType == 'day') params['date'] = queryDate;
    if (queryType == 'week') params['from'] = queryFrom;
    if (queryType == 'month') {
      params['month'] = queryMonth;
      params['year'] = queryYear;
    }
    if (queryType == 'range') {
      params['from'] = queryFrom;
      params['to'] = queryTo;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/faculty/attendance/query').replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString()))),
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            filteredAttendance = data['data'] ?? [];
            filteredTotalPages = data['pages'] ?? 1;
          });
        } else {
          setState(() {
            filteredAttendance = [];
            filteredTotalPages = 1;
          });
        }
      }
    } catch (e) {
      setState(() {
        filteredAttendance = [];
        filteredTotalPages = 1;
      });
    } finally {
      setState(() => filterLoading = false);
    }
  }

  Future<void> handlePreviousPage() async {
    if (filteredPage > 1 && !filterLoading) {
      setState(() => filterLoading = true);
      final userData = await _getUserData();
      final employeeId = userData?['employeeId'];
      final params = <String, dynamic>{
        'facultyId': employeeId,
        'subjectId': expandedSubject,
        'type': queryType,
        'page': filteredPage - 1,
        'limit': entriesPerPage,
      };

      if (queryType == 'day') params['date'] = queryDate;
      if (queryType == 'week') params['from'] = queryFrom;
      if (queryType == 'month') {
        params['month'] = queryMonth;
        params['year'] = queryYear;
      }
      if (queryType == 'range') {
        params['from'] = queryFrom;
        params['to'] = queryTo;
      }

      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/api/faculty/attendance/query').replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString()))),
          headers: {'Authorization': 'Bearer ${await _getToken()}'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success']) {
            setState(() {
              filteredAttendance = data['data'] ?? [];
              filteredPage--;
            });
          }
        }
      } catch (e) {
        // Handle error
      } finally {
        setState(() => filterLoading = false);
      }
    }
  }

  Future<void> handleNextPage() async {
    if (filteredPage < filteredTotalPages && !filterLoading) {
      setState(() => filterLoading = true);
      final userData = await _getUserData();
      final employeeId = userData?['employeeId'];
      final params = <String, dynamic>{
        'facultyId': employeeId,
        'subjectId': expandedSubject,
        'type': queryType,
        'page': filteredPage + 1,
        'limit': entriesPerPage,
      };

      if (queryType == 'day') params['date'] = queryDate;
      if (queryType == 'week') params['from'] = queryFrom;
      if (queryType == 'month') {
        params['month'] = queryMonth;
        params['year'] = queryYear;
      }
      if (queryType == 'range') {
        params['from'] = queryFrom;
        params['to'] = queryTo;
      }

      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/api/faculty/attendance/query').replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString()))),
          headers: {'Authorization': 'Bearer ${await _getToken()}'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success']) {
            setState(() {
              filteredAttendance = data['data'] ?? [];
              filteredPage++;
            });
          }
        }
      } catch (e) {
        // Handle error
      } finally {
        setState(() => filterLoading = false);
      }
    }
  }

  Future<void> handleDownloadReport() async {
    final boundary = logsKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();
      final imageProvider = pw.MemoryImage(pngBytes);
      pdf.addPage(pw.Page(
        build: (pw.Context context) => pw.Image(imageProvider),
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report generated as PDF')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  Future<void> handleDownloadStudentData(String studentId, String studentName) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/files/student-attendance/$studentId/$expandedSubject/download'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$studentName attendance report downloaded')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download student data')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error downloading student data')),
      );
    }
  }

  void handleNoteChange(String studentId, String value) {
    setState(() {
      studentNotes[studentId] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = isMobile ? EdgeInsets.all(screenWidth * 0.03) : const EdgeInsets.all(16);
    final textScaleFactor = isMobile ? 0.9 : 1.0;

    if (loading && subjects.isEmpty && students.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Mark Attendance',
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpinKitCircle(color: Colors.blue, size: 50),
              SizedBox(height: padding.vertical),
              Text(
                'Loading data...',
                style: TextStyle(color: Colors.grey, fontSize: 14 * textScaleFactor),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.error, color: Colors.red, size: 48),
                SizedBox(height: padding.vertical),
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 18 * textScaleFactor,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: padding.vertical / 2),
                Text(
                  error!,
                  style: TextStyle(color: Colors.grey, fontSize: 12 * textScaleFactor),
                ),
                SizedBox(height: padding.vertical),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MarkAttendanceScreen()),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text(
                    'Retry',
                    style: TextStyle(color: Colors.white, fontSize: 12 * textScaleFactor),
                  ),
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
            colors: [Color(0xFFE3F2FD), Color(0xFFE8EAF6), Color(0xFFF3E8FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
                    border: Border.all(color: Colors.blue.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Management',
                        style: TextStyle(
                          fontSize: 20 * textScaleFactor,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: padding.vertical / 2),
                      Text(
                        'Mark attendance, view analytics, and manage student records',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12 * textScaleFactor,
                        ),
                      ),
                      SizedBox(height: padding.vertical / 2),
                      Row(
                        children: [
                          const Icon(Symbols.calendar_month, size: 16, color: Colors.grey),
                          SizedBox(width: padding.horizontal / 2),
                          Text(
                            DateFormat.yMMMd().format(DateTime.now()),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12 * textScaleFactor,
                            ),
                          ),
                          SizedBox(width: padding.horizontal),
                          const Icon(Symbols.schedule, size: 16, color: Colors.grey),
                          SizedBox(width: padding.horizontal / 2),
                          Text(
                            DateFormat.Hm().format(DateTime.now()),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12 * textScaleFactor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: padding.vertical),

                // Subjects Grid
                Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
                    border: Border.all(color: Colors.blue.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Symbols.description, color: Colors.blue, size: 24),
                          SizedBox(width: padding.horizontal / 2),
                          Text(
                            'Select Subject',
                            style: TextStyle(
                              fontSize: 18 * textScaleFactor,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: padding.vertical),
                      subjects.isEmpty
                          ? Column(
                        children: [
                          const Icon(Symbols.description, size: 64, color: Colors.grey),
                          SizedBox(height: padding.vertical),
                          Text(
                            'No Subjects Found',
                            style: TextStyle(
                              fontSize: 16 * textScaleFactor,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: padding.vertical / 2),
                          Text(
                            'You are not assigned to teach any subjects.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12 * textScaleFactor,
                            ),
                          ),
                        ],
                      )
                          : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: isMobile ? 4 : 3,
                        ),
                        itemCount: subjects.length,
                        itemBuilder: (context, index) {
                          final subject = subjects[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                expandedSubject = expandedSubject == subject['_id'] ? '' : subject['_id'];
                                selectedStudents = [];
                              });
                              if (expandedSubject.isNotEmpty) {
                                fetchSubjectDetails(expandedSubject);
                                fetchStudents(expandedSubject);
                                checkTodayAttendance(expandedSubject);
                                calculateMonthlyClassAttendance(expandedSubject);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: expandedSubject == subject['_id'] ? Colors.blue : Colors.grey,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: expandedSubject == subject['_id']
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.white,
                                boxShadow: [
                                  if (expandedSubject == subject['_id'])
                                    BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 8),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          subject['name'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                            fontSize: 14 * textScaleFactor,
                                          ),
                                        ),
                                        Text(
                                          '${subject['department']?['name'] ?? 'Department N/A'} | Year ${subject['year']} | Section ${subject['section']}',
                                          style: TextStyle(
                                            fontSize: 12 * textScaleFactor,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: expandedSubject == subject['_id']
                                          ? Colors.blue.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Symbols.groups, size: 20, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: padding.vertical),

                // Students List and Attendance Marking
                if (expandedSubject.isNotEmpty)
                  Container(
                    padding: padding,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Symbols.groups, color: Colors.green, size: 24),
                            SizedBox(width: padding.horizontal / 2),
                            Text(
                              'Students & Attendance',
                              style: TextStyle(
                                fontSize: 18 * textScaleFactor,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: padding.vertical / 2),
                        if (loadingSubjectDetails)
                          Row(
                            children: [
                              const SpinKitCircle(color: Colors.blue, size: 20),
                              SizedBox(width: padding.horizontal / 2),
                              Text(
                                'Loading subject details...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12 * textScaleFactor,
                                ),
                              ),
                            ],
                          )
                        else if (subjectDetails != null)
                          Text(
                            'Department: ${subjectDetails!['department']} | Year: ${subjectDetails!['year']} | Section: ${subjectDetails!['section']} | Total Students: ${subjectDetails!['totalStudents']}',
                            style: TextStyle(
                              fontSize: 12 * textScaleFactor,
                              color: Colors.grey[600],
                            ),
                          ),
                        SizedBox(height: padding.vertical),
                        if (checkingTodayAttendance)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: padding.horizontal,
                              vertical: padding.vertical / 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              border: Border.all(color: Colors.blue.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const SpinKitCircle(color: Colors.blue, size: 20),
                                SizedBox(width: padding.horizontal / 2),
                                Text(
                                  'Checking today\'s attendance...',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12 * textScaleFactor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (attendanceMarkedToday)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: padding.horizontal,
                                  vertical: padding.vertical / 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Symbols.check_circle, color: Colors.green, size: 20),
                                    SizedBox(width: padding.horizontal / 2),
                                    Text(
                                      'Attendance already marked for today',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12 * textScaleFactor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (todayClassAttendance != null)
                                Container(
                                  margin: EdgeInsets.only(top: padding.vertical / 2),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: padding.horizontal,
                                    vertical: padding.vertical / 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Symbols.groups, color: Colors.blue, size: 20),
                                      SizedBox(width: padding.horizontal / 2),
                                      Text(
                                        'Today\'s Class Attendance: $todayClassAttendance%',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12 * textScaleFactor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (monthlyAttendanceLoading)
                                Container(
                                  margin: EdgeInsets.only(top: padding.vertical / 2),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: padding.horizontal,
                                    vertical: padding.vertical / 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const SpinKitCircle(color: Colors.grey, size: 20),
                                      SizedBox(width: padding.horizontal / 2),
                                      Text(
                                        'Calculating monthly attendance...',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12 * textScaleFactor,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (monthlyClassAttendance != null)
                                Container(
                                  margin: EdgeInsets.only(top: padding.vertical / 2),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: padding.horizontal,
                                    vertical: padding.vertical / 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    border: Border.all(color: Colors.purple.withOpacity(0.2)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Symbols.calendar_month, color: Colors.purple, size: 20),
                                      SizedBox(width: padding.horizontal / 2),
                                      Text(
                                        'This Month\'s Class Attendance: $monthlyClassAttendance%',
                                        style: TextStyle(
                                          color: Colors.purple,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12 * textScaleFactor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        else
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: padding.horizontal,
                              vertical: padding.vertical / 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.yellow.withOpacity(0.1),
                              border: Border.all(color: Colors.yellow.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Symbols.schedule, color: Colors.yellow, size: 20),
                                SizedBox(width: padding.horizontal / 2),
                                Text(
                                  'Attendance not marked for today',
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12 * textScaleFactor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (students.isNotEmpty && !attendanceMarkedToday)
                          Padding(
                            padding: EdgeInsets.only(top: padding.vertical),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton(
                                  onPressed: selectAllStudents,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.withOpacity(0.1),
                                    foregroundColor: Colors.grey[800],
                                    textStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                  ),
                                  child: Text(selectedStudents.length == students.length ? 'Deselect All' : 'Select All'),
                                ),
                                if (selectedStudents.isNotEmpty) ...[
                                  ElevatedButton(
                                    onPressed: isUpdating ? null : () => markAttendance('present'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      textStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Symbols.check_circle, size: 16),
                                        SizedBox(width: padding.horizontal / 2),
                                        Text('Mark Present (${selectedStudents.length})'),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: isUpdating ? null : () => markAttendance('absent'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      textStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Symbols.cancel, size: 16),
                                        SizedBox(width: padding.horizontal / 2),
                                        Text('Mark Absent (${selectedStudents.length})'),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        SizedBox(height: padding.vertical),
                        if (students.isEmpty && !loading)
                          Padding(
                            padding: padding,
                            child: Column(
                              children: [
                                const Icon(Symbols.groups, size: 64, color: Colors.grey),
                                SizedBox(height: padding.vertical),
                                Text(
                                  'No Students Found',
                                  style: TextStyle(
                                    fontSize: 16 * textScaleFactor,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: padding.vertical / 2),
                                Text(
                                  'No students are enrolled in this subject.',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12 * textScaleFactor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (loading)
                          Padding(
                            padding: padding,
                            child: Column(
                              children: [
                                const SpinKitCircle(color: Colors.blue, size: 32),
                                SizedBox(height: padding.vertical),
                                Text(
                                  'Loading students...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12 * textScaleFactor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (students.isNotEmpty)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final stats = attendanceStats[student['_id']] ?? {};
                              return Card(
                                margin: EdgeInsets.symmetric(vertical: padding.vertical / 2),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: selectedStudents.contains(student['_id']),
                                            onChanged: (value) => toggleStudentSelection(student['_id']),
                                          ),
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () => handleDownloadStudentData(
                                                student['_id'],
                                                '${student['firstName']} ${student['lastName']}',
                                              ),
                                              child: Text(
                                                '${student['firstName']} ${student['lastName']}',
                                                style: TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 14 * textScaleFactor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: padding.horizontal),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Department: ${student['department']?['name'] ?? 'N/A'}',
                                              style: TextStyle(
                                                fontSize: 12 * textScaleFactor,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              'Year/Section: ${student['year']} / ${student['section']}',
                                              style: TextStyle(
                                                fontSize: 12 * textScaleFactor,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            SizedBox(height: padding.vertical / 2),
                                            Row(
                                              children: [
                                                Text(
                                                  'Monthly: ',
                                                  style: TextStyle(
                                                    fontSize: 12 * textScaleFactor,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                stats['monthly'] != null
                                                    ? Row(
                                                  children: [
                                                    Text(
                                                      '${stats['monthly']['percentage']}%',
                                                      style: TextStyle(
                                                        color: stats['monthly']['percentage'] >= 75
                                                            ? Colors.green
                                                            : Colors.red,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12 * textScaleFactor,
                                                      ),
                                                    ),
                                                    SizedBox(width: padding.horizontal / 2),
                                                    Container(
                                                      width: 64,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: stats['monthly']['percentage'] >= 75
                                                            ? Colors.green.withOpacity(0.2)
                                                            : Colors.red.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: FractionallySizedBox(
                                                        widthFactor:
                                                        (stats['monthly']['percentage'] / 100).clamp(0, 1),
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: stats['monthly']['percentage'] >= 75
                                                                ? Colors.green
                                                                : Colors.red,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                                    : stats['error'] == true
                                                    ? Text(
                                                  'Error',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12 * textScaleFactor,
                                                  ),
                                                )
                                                    : const SpinKitPulse(color: Colors.grey, size: 20),
                                              ],
                                            ),
                                            SizedBox(height: padding.vertical / 2),
                                            Row(
                                              children: [
                                                Text(
                                                  'Overall: ',
                                                  style: TextStyle(
                                                    fontSize: 12 * textScaleFactor,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                stats['overall'] != null
                                                    ? Row(
                                                  children: [
                                                    Text(
                                                      '${stats['overall']['percentage']}%',
                                                      style: TextStyle(
                                                        color: stats['overall']['percentage'] >= 75
                                                            ? Colors.green
                                                            : Colors.red,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12 * textScaleFactor,
                                                      ),
                                                    ),
                                                    SizedBox(width: padding.horizontal / 2),
                                                    Container(
                                                      width: 64,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: stats['overall']['percentage'] >= 75
                                                            ? Colors.green.withOpacity(0.2)
                                                            : Colors.red.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: FractionallySizedBox(
                                                        widthFactor:
                                                        (stats['overall']['percentage'] / 100).clamp(0, 1),
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: stats['overall']['percentage'] >= 75
                                                                ? Colors.green
                                                                : Colors.red,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                                    : stats['error'] == true
                                                    ? Text(
                                                  'Error',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12 * textScaleFactor,
                                                  ),
                                                )
                                                    : const SpinKitPulse(color: Colors.grey, size: 20),
                                              ],
                                            ),
                                            SizedBox(height: padding.vertical / 2),
                                            TextField(
                                              decoration: InputDecoration(
                                                border: const OutlineInputBorder(),
                                                hintText: 'Optional reason/note',
                                                hintStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                              ),
                                              enabled: !attendanceMarkedToday,
                                              onChanged: (value) => handleNoteChange(student['_id'], value),
                                              controller:
                                              TextEditingController(text: studentNotes[student['_id']] ?? ''),
                                              style: TextStyle(fontSize: 12 * textScaleFactor),
                                            ),
                                            SizedBox(height: padding.vertical / 2),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                IconButton(
                                                  onPressed: attendanceMarkedToday || isUpdating
                                                      ? null
                                                      : () {
                                                    setState(() => selectedStudents = [student['_id']]);
                                                    markAttendance('present');
                                                  },
                                                  icon: Icon(
                                                    Symbols.check_circle,
                                                    color: attendanceMarkedToday ? Colors.grey : Colors.green,
                                                    size: 20,
                                                  ),
                                                  tooltip: attendanceMarkedToday ? 'Attendance already marked' : 'Mark Present',
                                                ),
                                                IconButton(
                                                  onPressed: attendanceMarkedToday || isUpdating
                                                      ? null
                                                      : () {
                                                    setState(() => selectedStudents = [student['_id']]);
                                                    markAttendance('absent');
                                                  },
                                                  icon: Icon(
                                                    Symbols.cancel,
                                                    color: attendanceMarkedToday ? Colors.grey : Colors.red,
                                                    size: 20,
                                                  ),
                                                  tooltip: attendanceMarkedToday ? 'Attendance already marked' : 'Mark Absent',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                SizedBox(height: padding.vertical),

                // Attendance Analytics
                if (expandedSubject.isNotEmpty && students.isNotEmpty)
                  Container(
                    padding: padding,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Symbols.bar_chart, color: Colors.purple, size: 24),
                            SizedBox(width: padding.horizontal / 2),
                            Text(
                              'Attendance Analytics',
                              style: TextStyle(
                                fontSize: 18 * textScaleFactor,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: padding.vertical),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 3) / 3,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFDFF0E4), Color(0xFFB2E0C2)]),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'High Attendance',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12 * textScaleFactor,
                                        ),
                                      ),
                                      Text(
                                        '${students.where((s) => (attendanceStats[s['_id']] ?? {})['overall']?['percentage'] >= 75).length}',
                                        style: TextStyle(
                                          fontSize: 20 * textScaleFactor,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(Symbols.check_circle, color: Colors.green, size: 24),
                                ],
                              ),
                            ),
                            Container(
                              width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 3) / 3,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFFFF4DB), Color(0xFFFFE8B2)]),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Low Attendance',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12 * textScaleFactor,
                                        ),
                                      ),
                                      Text(
                                        '${students.where((s) => ((attendanceStats[s['_id']] ?? {})['overall']?['percentage'] ?? 0) < 75 && ((attendanceStats[s['_id']] ?? {})['overall']?['percentage'] ?? 0) >= 0).length}',
                                        style: TextStyle(
                                          fontSize: 20 * textScaleFactor,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(Symbols.cancel, color: Colors.orange, size: 24),
                                ],
                              ),
                            ),
                            Container(
                              width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 3) / 3,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFC7D2FE)]),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Students',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12 * textScaleFactor,
                                        ),
                                      ),
                                      Text(
                                        '${students.length}',
                                        style: TextStyle(
                                          fontSize: 20 * textScaleFactor,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(Symbols.groups, color: Colors.blue, size: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: padding.vertical),
                        if (students.isNotEmpty && attendanceStats.isNotEmpty && students.every((s) => attendanceStats.containsKey(s['_id'])))
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            height: (students.length * 15).clamp(150, isMobile ? 250 : 300).toDouble(),
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceEvenly,
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      interval: 25,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: TextStyle(fontSize: 10 * textScaleFactor, color: Colors.grey[600]),
                                        );
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index >= 0 && index < students.length) {
                                          final student = students[index];
                                          return Transform.rotate(
                                            angle: isMobile ? -45 * 3.14159 / 180 : 0,
                                            child: Text(
                                              '${student['firstName'][0]}${student['lastName'][0]}',
                                              style: TextStyle(fontSize: 10 * textScaleFactor, color: Colors.grey[600]),
                                            ),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawHorizontalLine: true,
                                  horizontalInterval: 25,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: Colors.grey.withOpacity(0.2),
                                    strokeWidth: 1,
                                    dashArray: [3, 3],
                                  ),
                                ),
                                minY: 0,
                                maxY: 100,
                                barGroups: students.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final student = entry.value;
                                  return BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: (attendanceStats[student['_id']] ?? {})['overall']?['percentage']?.toDouble() ?? 0,
                                        color: Colors.blue,
                                        width: isMobile ? 8 : 12,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                    barsSpace: isMobile ? 4 : 8,
                                  );
                                }).toList(),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: padding,
                            child: Column(
                              children: [
                                const SpinKitCircle(color: Colors.blue, size: 32),
                                SizedBox(height: padding.vertical),
                                Text(
                                  'Loading attendance analytics...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12 * textScaleFactor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                SizedBox(height: padding.vertical),

                // Attendance Logs & Reports
                if (expandedSubject.isNotEmpty)
                  Container(
                    padding: padding,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Symbols.search, color: Colors.purple, size: 24),
                            SizedBox(width: padding.horizontal / 2),
                            Text(
                              'Attendance Logs & Reports',
                              style: TextStyle(
                                fontSize: 18 * textScaleFactor,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: padding.vertical),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filter by:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                  fontSize: 12 * textScaleFactor,
                                ),
                              ),
                              SizedBox(height: padding.vertical / 2),
                              DropdownButton<String>(
                                value: queryType,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'day', child: Text('Day')),
                                  DropdownMenuItem(value: 'week', child: Text('Week')),
                                  DropdownMenuItem(value: 'month', child: Text('Month')),
                                  DropdownMenuItem(value: 'range', child: Text('Custom Range')),
                                ],
                                onChanged: (value) => setState(() => queryType = value!),
                              ),
                              SizedBox(height: padding.vertical / 2),
                              if (queryType == 'day')
                                TextField(
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: 'Date',
                                    labelStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                  ),
                                  controller: TextEditingController(text: queryDate),
                                  readOnly: true,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() => queryDate = DateFormat('yyyy-MM-dd').format(picked));
                                    }
                                  },
                                  style: TextStyle(fontSize: 12 * textScaleFactor),
                                ),
                              if (queryType == 'week')
                                TextField(
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: 'Week Start',
                                    labelStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                  ),
                                  controller: TextEditingController(text: queryFrom),
                                  readOnly: true,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() => queryFrom = DateFormat('yyyy-MM-dd').format(picked));
                                    }
                                  },
                                  style: TextStyle(fontSize: 12 * textScaleFactor),
                                ),
                              if (queryType == 'month')
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButton<int>(
                                        value: queryMonth,
                                        isExpanded: true,
                                        items: List.generate(
                                          12,
                                              (index) => DropdownMenuItem(
                                            value: index + 1,
                                            child: Text(
                                              DateFormat.MMMM().format(DateTime(0, index + 1)),
                                              style: TextStyle(fontSize: 12 * textScaleFactor),
                                            ),
                                          ),
                                        ),
                                        onChanged: (value) => setState(() => queryMonth = value!),
                                      ),
                                    ),
                                    SizedBox(width: padding.horizontal / 2),
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        decoration: InputDecoration(
                                          border: const OutlineInputBorder(),
                                          labelText: 'Year',
                                          labelStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                        ),
                                        keyboardType: TextInputType.number,
                                        controller: TextEditingController(text: queryYear.toString()),
                                        onChanged: (value) => setState(
                                              () => queryYear = int.tryParse(value) ?? DateTime.now().year,
                                        ),
                                        style: TextStyle(fontSize: 12 * textScaleFactor),
                                      ),
                                    ),
                                  ],
                                ),
                              if (queryType == 'range')
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        decoration: InputDecoration(
                                          border: const OutlineInputBorder(),
                                          labelText: 'From',
                                          labelStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                        ),
                                        controller: TextEditingController(text: queryFrom),
                                        readOnly: true,
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            setState(() => queryFrom = DateFormat('yyyy-MM-dd').format(picked));
                                          }
                                        },
                                        style: TextStyle(fontSize: 12 * textScaleFactor),
                                      ),
                                    ),
                                    SizedBox(width: padding.horizontal / 2),
                                    Expanded(
                                      child: TextField(
                                        decoration: InputDecoration(
                                          border: const OutlineInputBorder(),
                                          labelText: 'To',
                                          labelStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                        ),
                                        controller: TextEditingController(text: queryTo),
                                        readOnly: true,
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            setState(() => queryTo = DateFormat('yyyy-MM-dd').format(picked));
                                          }
                                        },
                                        style: TextStyle(fontSize: 12 * textScaleFactor),
                                      ),
                                    ),
                                  ],
                                ),
                              SizedBox(height: padding.vertical / 2),
                              ElevatedButton(
                                onPressed: filterLoading ||
                                    expandedSubject.isEmpty ||
                                    (queryType == 'day' && queryDate.isEmpty) ||
                                    (queryType == 'week' && queryFrom.isEmpty) ||
                                    (queryType == 'month' && (queryMonth == 0 || queryYear == 0)) ||
                                    (queryType == 'range' && (queryFrom.isEmpty || queryTo.isEmpty))
                                    ? null
                                    : handleFilterClick,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  textStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Symbols.filter_alt, size: 16),
                                    SizedBox(width: padding.horizontal / 2),
                                    Text(filterLoading ? 'Filtering...' : 'Filter'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: padding.vertical),
                        RepaintBoundary(
                          key: logsKey,
                          child: filteredAttendance.isNotEmpty
                              ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredAttendance.length,
                            itemBuilder: (context, index) {
                              final log = filteredAttendance[index];
                              return Card(
                                margin: EdgeInsets.symmetric(vertical: padding.vertical / 2),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log['student'] != null
                                            ? '${log['student']['firstName']} ${log['student']['middleName'] ?? ''} ${log['student']['lastName']}'.trim()
                                            : log['studentId'] ?? 'Unknown Student',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14 * textScaleFactor,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      SizedBox(height: padding.vertical / 2),
                                      Text(
                                        'Date: ${log['date'] != null ? _formatDate(log['date']) : 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 12 * textScaleFactor,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'Time: ${log['createdAt'] != null ? DateFormat.Hm().format(DateTime.parse(log['createdAt'])) : log['markedAt'] != null ? DateFormat.Hm().format(DateTime.parse(log['markedAt'])) : 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 12 * textScaleFactor,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: padding.vertical / 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: log['status'] == 'present'
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          log['status'],
                                          style: TextStyle(
                                            color: log['status'] == 'present' ? Colors.green : Colors.red,
                                            fontSize: 12 * textScaleFactor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                              : Padding(
                            padding: padding,
                            child: Column(
                              children: [
                                const Icon(Symbols.description, size: 64, color: Colors.grey),
                                SizedBox(height: padding.vertical),
                                Text(
                                  'No Attendance Records Found',
                                  style: TextStyle(
                                    fontSize: 16 * textScaleFactor,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: padding.vertical / 2),
                                if (filterLoading)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SpinKitCircle(color: Colors.grey, size: 20),
                                      SizedBox(width: padding.horizontal / 2),
                                      Text(
                                        'Loading attendance records...',
                                        style: TextStyle(fontSize: 12 * textScaleFactor),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    'No attendance has been marked for the selected criteria. Try marking attendance first or adjusting your filters.',
                                    style: TextStyle(
                                      fontSize: 12 * textScaleFactor,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (filteredAttendance.isNotEmpty && filteredTotalPages > 1)
                          Padding(
                            padding: EdgeInsets.only(top: padding.vertical),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Page $filteredPage of $filteredTotalPages',
                                  style: TextStyle(fontSize: 12 * textScaleFactor),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: filteredPage == 1 || filterLoading ? null : handlePreviousPage,
                                      icon: const Icon(Symbols.chevron_left, size: 20),
                                    ),
                                    IconButton(
                                      onPressed: filteredPage == filteredTotalPages || filterLoading
                                          ? null
                                          : handleNextPage,
                                      icon: const Icon(Symbols.chevron_right, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        SizedBox(height: padding.vertical),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: handleDownloadReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(fontSize: 12 * textScaleFactor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Symbols.download, size: 16),
                                  SizedBox(width: padding.horizontal / 2),
                                  const Text('Download Report'),
                                ],
                              ),
                            ),
                            SizedBox(width: padding.horizontal / 2),
                            ElevatedButton(
                              onPressed: handleDownloadReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(fontSize: 12 * textScaleFactor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Symbols.description, size: 16),
                                  SizedBox(width: padding.horizontal / 2),
                                  const Text('Download PDF'),
                                ],
                              ),
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
  }

  String _formatDate(String date) {
    try {
      return DateFormat.yMMMd().format(DateTime.parse(date));
    } catch (e) {
      final parts = date.split(' ');
      if (parts.length >= 6) {
        final datePart = '${parts[1]} ${parts[2]} ${parts[3]} ${parts[4]}';
        final formatter = DateFormat('MMM dd yyyy HH:mm:ss');
        return DateFormat.yMMMd().format(formatter.parse(datePart));
      }
      return 'N/A';
    }
  }
} 