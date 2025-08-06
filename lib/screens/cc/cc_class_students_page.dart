import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:material_symbols_icons/symbols.dart';

class CCClassStudentsPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const CCClassStudentsPage({super.key, this.userData});

  @override
  _CCClassStudentsPageState createState() => _CCClassStudentsPageState();
}

class _CCClassStudentsPageState extends State<CCClassStudentsPage> {
  static const String _baseUrl = 'http://192.168.1.33:5000';
  List<Map<String, dynamic>> students = [];
  bool isLoading = true;
  String searchTerm = '';
  String filterYear = '';
  String filterSection = '';
  String filterStatus = '';
  Map<String, dynamic> stats = {
    'totalStudents': 0,
    'averageAttendance': 0,
    'activeStudents': 0,
    'maleStudents': 0,
    'femaleStudents': 0,
  };
  String? token;

  @override
  void initState() {
    super.initState();
    _fetchCCClassStudents();
  }

  Future<void> _fetchCCClassStudents() async {
    setState(() {
      isLoading = true;
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

      final response = await http.get(
        Uri.parse('$_baseUrl/api/faculty/get-cc-class-students'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('CC Class Students API response status: ${response.statusCode}');
      debugPrint('CC Class Students API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['data'] != null) {
          final studentsData = List<Map<String, dynamic>>.from(data['data']['students'] ?? []);
          setState(() {
            students = studentsData;
            stats = {
              'totalStudents': studentsData.length,
              'averageAttendance': (data['data']['averageAttendance'] ?? 0).toDouble(),
              'activeStudents': studentsData.where((s) => s['status'] == 'active').length,
              'maleStudents': studentsData.where((s) => s['gender'] == 'Male').length,
              'femaleStudents': studentsData.where((s) => s['gender'] == 'Female').length,
            };
          });
          if (studentsData.isEmpty) {
            debugPrint('No students found for CC assignment');
          }
        } else {
          debugPrint('API returned success=false: $data');
        }
      } else {
        if (response.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          debugPrint('Unauthorized: Clearing SharedPreferences and redirecting to login');
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
        throw Exception('Failed to fetch class students: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error fetching CC class students: $error');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredStudents {
    return students.where((student) {
      final matchesSearch = (student['name']?.toString().toLowerCase().contains(searchTerm.toLowerCase()) ?? false) ||
          (student['enrollmentNumber']?.toString().toLowerCase().contains(searchTerm.toLowerCase()) ?? false) ||
          (student['email']?.toString().toLowerCase().contains(searchTerm.toLowerCase()) ?? false);

      final matchesYear = filterYear.isEmpty || student['year']?.toString() == filterYear;
      final matchesSection = filterSection.isEmpty || student['section']?.toString().toUpperCase() == filterSection.toUpperCase();
      final matchesStatus = filterStatus.isEmpty || student['status'] == filterStatus;

      return matchesSearch && matchesYear && matchesSection && matchesStatus;
    }).toList();
  }

  Future<void> _exportToCSV() async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
        return;
      }

      final headers = [
        'Enrollment Number',
        'Name',
        'Email',
        'Phone',
        'Year',
        'Section',
        'Department',
        'Gender',
        'Status',
        'Attendance %',
        'Address',
      ];

      final csvData = filteredStudents.map((student) => [
        student['enrollmentNumber']?.toString() ?? '',
        student['name']?.toString() ?? '',
        student['email']?.toString() ?? '',
        student['phone']?.toString() ?? '',
        student['year']?.toString() ?? '',
        student['section']?.toString() ?? '',
        student['department']?.toString() ?? '',
        student['gender']?.toString() ?? '',
        student['status']?.toString() ?? '',
        student['attendancePercentage']?.toString() ?? '0',
        student['address']?.toString() ?? '',
      ]).toList();

      final csvContent = [headers, ...csvData]
          .map((row) => row.map((field) => '"${field.replaceAll('"', '""')}"').join(','))
          .join('\n');

      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access storage directory')),
        );
        return;
      }

      final file = File(
          '${directory.path}/CC_Class_Students_${DateTime.now().toIso8601String().split('T')[0]}.csv');
      await file.writeAsString(csvContent);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV exported to ${file.path}')),
      );
    } catch (error) {
      debugPrint('Error exporting CSV: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export CSV')),
      );
    }
  }

  Color getAttendanceColor(double percentage) {
    if (percentage >= 75) return const Color(0xFF16A34A);
    if (percentage >= 60) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
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
        final fontSizeXSmall = isMobile ? 10.0 : 14.0; // Ensure this line exists

        if (isLoading) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEEF2FF), Color(0xFFFFFFFF), Color(0xFFECFEFF)],
                ),
              ),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(padding.horizontal),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading Class Students...',
                        style: TextStyle(
                          fontSize: fontSizeMedium,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Class Students',
              style: TextStyle(
                fontSize: fontSizeLarge,
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
            actions: [
              IconButton(
                icon: const Icon(Symbols.refresh),
                onPressed: _fetchCCClassStudents,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Symbols.download),
                onPressed: _exportToCSV,
                tooltip: 'Export CSV',
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEEF2FF), Color(0xFFFFFFFF), Color(0xFFECFEFF)],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(padding.horizontal),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Symbols.school, size: 24, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 8),
                              Text(
                                'My Class Students',
                                style: TextStyle(
                                  fontSize: fontSizeLarge,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Students from your assigned class - ${widget.userData?['department'] ?? 'Unknown'} Department',
                            style: TextStyle(
                              fontSize: fontSizeSmall,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Statistics Cards
                    // Inside the build method's LayoutBuilder
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildStatCard(
                          title: 'Total Students',
                          value: stats['totalStudents'].toString(),
                          icon: Symbols.groups,
                          color: const Color(0xFF3B82F6),
                          description: 'In your class',
                          fontSizeMedium: fontSizeMedium,
                          fontSizeSmall: fontSizeSmall,
                          fontSizeXSmall: fontSizeXSmall, // Add this
                          isMobile: isMobile,
                        ),
                        _buildStatCard(
                          title: 'Active Students',
                          value: stats['activeStudents'].toString(),
                          icon: Symbols.person_check,
                          color: const Color(0xFF16A34A),
                          description: 'Currently enrolled',
                          fontSizeMedium: fontSizeMedium,
                          fontSizeSmall: fontSizeSmall,
                          fontSizeXSmall: fontSizeXSmall, // Add this
                          isMobile: isMobile,
                        ),
                        _buildStatCard(
                          title: 'Avg Attendance',
                          value: '${stats['averageAttendance'].toStringAsFixed(0)}%',
                          icon: Symbols.trending_up,
                          color: const Color(0xFF9333EA),
                          description: 'Class average',
                          fontSizeMedium: fontSizeMedium,
                          fontSizeSmall: fontSizeSmall,
                          fontSizeXSmall: fontSizeXSmall, // Add this
                          isMobile: isMobile,
                        ),
                        _buildStatCard(
                          title: 'Male Students',
                          value: stats['maleStudents'].toString(),
                          icon: Symbols.person,
                          color: const Color(0xFF06B6D4),
                          description: 'Gender distribution',
                          fontSizeMedium: fontSizeMedium,
                          fontSizeSmall: fontSizeSmall,
                          fontSizeXSmall: fontSizeXSmall, // Add this
                          isMobile: isMobile,
                        ),
                        _buildStatCard(
                          title: 'Female Students',
                          value: stats['femaleStudents'].toString(),
                          icon: Symbols.person,
                          color: const Color(0xFFEC4899),
                          description: 'Gender distribution',
                          fontSizeMedium: fontSizeMedium,
                          fontSizeSmall: fontSizeSmall,
                          fontSizeXSmall: fontSizeXSmall, // Add this
                          isMobile: isMobile,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    // Filters
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(padding.horizontal),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: isMobile ? double.infinity : 200,
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Search students...',
                                prefixIcon: const Icon(Symbols.search, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              style: TextStyle(fontSize: fontSizeSmall),
                              onChanged: (value) => setState(() => searchTerm = value),
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? double.infinity : 150,
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Year',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              value: filterYear.isEmpty ? null : filterYear,
                              items: const [
                                DropdownMenuItem(value: '', child: Text('All Years')),
                                DropdownMenuItem(value: '1', child: Text('Year 1')),
                                DropdownMenuItem(value: '2', child: Text('Year 2')),
                                DropdownMenuItem(value: '3', child: Text('Year 3')),
                                DropdownMenuItem(value: '4', child: Text('Year 4')),
                              ],
                              onChanged: (value) => setState(() => filterYear = value ?? ''),
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? double.infinity : 150,
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Section',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              value: filterSection.isEmpty ? null : filterSection,
                              items: const [
                                DropdownMenuItem(value: '', child: Text('All Sections')),
                                DropdownMenuItem(value: 'A', child: Text('Section A')),
                                DropdownMenuItem(value: 'B', child: Text('Section B')),
                                DropdownMenuItem(value: 'C', child: Text('Section C')),
                                DropdownMenuItem(value: 'D', child: Text('Section D')),
                              ],
                              onChanged: (value) => setState(() => filterSection = value ?? ''),
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? double.infinity : 150,
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              value: filterStatus.isEmpty ? null : filterStatus,
                              items: const [
                                DropdownMenuItem(value: '', child: Text('All Status')),
                                DropdownMenuItem(value: 'active', child: Text('Active')),
                                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                                DropdownMenuItem(value: 'graduated', child: Text('Graduated')),
                              ],
                              onChanged: (value) => setState(() => filterStatus = value ?? ''),
                            ),
                          ),
                          SizedBox(
                            width: isMobile ? double.infinity : 150,
                            child: ElevatedButton(
                              onPressed: () => setState(() {
                                searchTerm = '';
                                filterYear = '';
                                filterSection = '';
                                filterStatus = '';
                              }),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF3F4F6),
                                foregroundColor: const Color(0xFF4B5563),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                'Clear Filters',
                                style: TextStyle(fontSize: fontSizeSmall),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Students Table
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(padding.horizontal),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFD1D5DB))),
                            ),
                            child: Row(
                              children: [
                                const Icon(Symbols.school, size: 24, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 8),
                                Text(
                                  'Class Students (${filteredStudents.length})',
                                  style: TextStyle(
                                    fontSize: fontSizeMedium,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (filteredStudents.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const Icon(Symbols.school, size: 48, color: Color(0xFF6B7280)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No students found matching your criteria',
                                    style: TextStyle(
                                      fontSize: fontSizeMedium,
                                      color: const Color(0xFF4B5563),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Try adjusting your filters or search terms',
                                    style: TextStyle(
                                      fontSize: fontSizeXSmall,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0), // Added bottom padding
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: isMobile ? 8 : 16,
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        'Student Info',
                                        style: TextStyle(
                                          fontSize: fontSizeXSmall,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Academic Details',
                                        style: TextStyle(
                                          fontSize: fontSizeXSmall,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Contact',
                                        style: TextStyle(
                                          fontSize: fontSizeXSmall,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Attendance',
                                        style: TextStyle(
                                          fontSize: fontSizeXSmall,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Status',
                                        style: TextStyle(
                                          fontSize: fontSizeXSmall,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: filteredStudents.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final student = entry.value;
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    student['name']?.toString().substring(0, 1).toUpperCase() ?? 'S',
                                                    style: TextStyle(
                                                      fontSize: fontSizeSmall,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student['name']?.toString() ?? 'N/A',
                                                    style: TextStyle(
                                                      fontSize: fontSizeSmall,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF1F2937),
                                                    ),
                                                  ),
                                                  Text(
                                                    student['enrollmentNumber']?.toString() ?? 'N/A',
                                                    style: TextStyle(
                                                      fontSize: fontSizeXSmall,
                                                      color: const Color(0xFF6B7280),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Symbols.book, size: 14, color: Color(0xFF4F46E5)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Year ${student['year']?.toString() ?? 'N/A'} - Section ${student['section']?.toString() ?? 'N/A'}',
                                                    style: TextStyle(
                                                      fontSize: fontSizeXSmall,
                                                      color: const Color(0xFF1F2937),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                student['department']?.toString() ?? 'N/A',
                                                style: TextStyle(
                                                  fontSize: fontSizeXSmall,
                                                  color: const Color(0xFF6B7280),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Symbols.mail, size: 14, color: Color(0xFF6B7280)),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      student['email']?.toString() ?? 'N/A',
                                                      style: TextStyle(
                                                        fontSize: fontSizeXSmall,
                                                        color: const Color(0xFF1F2937),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(Symbols.phone, size: 14, color: Color(0xFF6B7280)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    student['phone']?.toString() ?? 'N/A',
                                                    style: TextStyle(
                                                      fontSize: fontSizeXSmall,
                                                      color: const Color(0xFF1F2937),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: getAttendanceColor(
                                                (student['attendancePercentage'] ?? 0).toDouble(),
                                              ).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              '${student['attendancePercentage']?.toString() ?? '0'}%',
                                              style: TextStyle(
                                                fontSize: fontSizeXSmall,
                                                fontWeight: FontWeight.w600,
                                                color: getAttendanceColor(
                                                  (student['attendancePercentage'] ?? 0).toDouble(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: student['status'] == 'active'
                                                  ? const Color(0xFFD1FAE5)
                                                  : student['status'] == 'inactive'
                                                  ? const Color(0xFFFEE2E2)
                                                  : const Color(0xFFE5E7EB),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              student['status']?.toString() ?? 'unknown',
                                              style: TextStyle(
                                                fontSize: fontSizeXSmall,
                                                fontWeight: FontWeight.w600,
                                                color: student['status'] == 'active'
                                                    ? const Color(0xFF16A34A)
                                                    : student['status'] == 'inactive'
                                                    ? const Color(0xFFB91C1C)
                                                    : const Color(0xFF4B5563),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
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
    required IconData icon,
    required Color color,
    required String description,
    required double fontSizeMedium,
    required double fontSizeSmall,
    required double fontSizeXSmall, // Add this parameter
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? double.infinity : 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  fontSize: fontSizeXSmall,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: fontSizeMedium,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: fontSizeXSmall,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
        ],
      ),
    );
  }
}