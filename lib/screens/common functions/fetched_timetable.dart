
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class FetchedTimetable extends StatefulWidget {
  const FetchedTimetable({Key? key}) : super(key: key);

  @override
  _FetchedTimetableState createState() => _FetchedTimetableState();
}

class _FetchedTimetableState extends State<FetchedTimetable>
    with TickerProviderStateMixin {
  List<dynamic> timetable = [];
  bool loading = true;
  String? error;
  String? userDepartment;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const String _baseUrl = 'http://192.168.1.33:5000';

  @override
  void initState() {
    super.initState();
// Initialize animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

// Fetch timetable
    fetchTimetable();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> fetchTimetable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final userData = prefs.getString('user');

      debugPrint('FetchedTimetable - Token exists: ${token != null}');
      debugPrint('FetchedTimetable - Token length: ${token?.length ?? 0}');

      if (token == null) {
        throw Exception('No authentication token found. Please log in.');
      }

      if (userData == null) {
        throw Exception('User data not found. Please log in.');
      }

      final user = jsonDecode(userData);
      debugPrint('FetchedTimetable - User data: $user');

      if (user['department'] == null) {
        throw Exception('User department not found. Please log in.');
      }

      setState(() {
        userDepartment = user['department'];
      });

      final apiUrl =
          '$_baseUrl/api/timetable?department=${Uri.encodeComponent(user['department'])}';
      debugPrint('Fetching from: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP error: ${response.statusCode} ${response.reasonPhrase}');
      }

      final contentType = response.headers['content-type'];
      if (contentType == null || !contentType.contains('application/json')) {
        debugPrint('Non-JSON response: ${response.body}');
        throw Exception('Expected JSON, but received ${contentType ?? "no content-type"}');
      }

      final timetableData = jsonDecode(response.body);
      debugPrint('Received data: ${jsonEncode(timetableData)}');

// Validate timetable data
      if (timetableData is List) {
        for (var entry in timetableData) {
          if (entry['timetableData'] is List && entry['timeSlots'] is List) {
            for (var dayData in entry['timetableData']) {
              if (dayData['classes'] is List &&
                  dayData['classes'].length < entry['timeSlots'].length) {
// Pad classes with null to match timeSlots length
                debugPrint(
                    'Padding classes for ${dayData['day']}: ${dayData['classes'].length} < ${entry['timeSlots'].length}');
                dayData['classes'] = List<dynamic>.from(dayData['classes'])
                  ..addAll(List.filled(
                      entry['timeSlots'].length - dayData['classes'].length, null));
              }
            }
          }
        }
      }

      setState(() {
        timetable = timetableData;
      });
    } catch (err) {
      debugPrint('Fetch error: $err');
      setState(() {
        error = 'Failed to fetch timetable: $err';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final textScaleFactor = isMobile ? 0.9 : 1.0;

// Get current day for highlighting
    final today = DateFormat('EEEE').format(DateTime.now());

    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Fetched Timetable',
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
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 18 * textScaleFactor,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Error: $error',
            style: TextStyle(
              fontSize: 18 * textScaleFactor,
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (timetable.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            'No timetable available for ${userDepartment ?? "your department"}',
            style: TextStyle(
              fontSize: 18 * textScaleFactor,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.indigo[50]!,
              Colors.purple[50]!,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Timetable for $userDepartment',
                    style: TextStyle(
                      fontSize: 24 * textScaleFactor,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ...timetable.asMap().entries.map((entry) {
                  final index = entry.key;
                  final timetableEntry = entry.value;
                  return FadeTransition(
                    opacity: Tween<double>(
                      begin: 0,
                      end: 1,
                    ).animate(
                      CurvedAnimation(
                        parent: _fadeController,
                        curve: Interval(
                          index * 0.1,
                          (index + 1) * 0.1,
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                    child: Card(
                      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${timetableEntry['collegeInfo']['name'] ?? 'Unknown'} - ${timetableEntry['collegeInfo']['department'] ?? 'Unknown'} - ${timetableEntry['collegeInfo']['semester'] ?? 'Unknown'}',
                              style: TextStyle(
                                fontSize: 18 * textScaleFactor,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Room: ${timetableEntry['collegeInfo']['room'] ?? 'N/A'} | Section: ${timetableEntry['collegeInfo']['section'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 14 * textScaleFactor,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: isMobile ? 8 : 16,
                                dataRowHeight: isMobile ? 60 : 72,
                                headingRowHeight: isMobile ? 48 : 56,
                                border: TableBorder.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'Day',
                                      style: TextStyle(
                                        fontSize: 12 * textScaleFactor,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  ...(timetableEntry['timeSlots'] ?? []).map((slot) => DataColumn(
                                    label: Text(
                                      slot ?? '',
                                      style: TextStyle(
                                        fontSize: 12 * textScaleFactor,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )),
                                ],
                                rows: (timetableEntry['timetableData'] ?? []).map<DataRow>((dayData) {
                                  return DataRow(
                                    color: MaterialStateProperty.resolveWith((states) {
                                      if (dayData['day'] == today) {
                                        return Colors.blue[50];
                                      }
                                      if (states.contains(MaterialState.hovered)) {
                                        return Colors.grey[50];
                                      }
                                      return null;
                                    }),
                                    cells: [
                                      DataCell(
                                        Text(
                                          dayData['day'] ?? '',
                                          style: TextStyle(
                                            fontSize: 12 * textScaleFactor,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      ...(timetableEntry['timeSlots'] ?? []).asMap().entries.map((slotEntry) {
                                        final slotIndex = slotEntry.key;
                                        final classItem = slotIndex < (dayData['classes']?.length ?? 0)
                                            ? dayData['classes'][slotIndex] ?? {}
                                            : {};
                                        return DataCell(
                                          Container(
                                            padding: EdgeInsets.all(isMobile ? 4 : 8),
                                            color: classItem['type'] == 'Lecture'
                                                ? Colors.green[100]
                                                : classItem['type'] == 'Lab'
                                                ? Colors.yellow[100]
                                                : classItem['type'] != null
                                                ? Colors.blue[100]
                                                : Colors.grey[100],
                                            child: classItem['subject'] != null
                                                ? Column(
                                              mainAxisAlignment:
                                              MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  classItem['subject'] ?? '',
                                                  style: TextStyle(
                                                    fontSize: 12 * textScaleFactor,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '(${classItem['type'] ?? ''}) - ${classItem['faculty'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 10 * textScaleFactor,
                                                    color: Colors.grey[600],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            )
                                                : Text(
                                              'Free',
                                              style: TextStyle(
                                                fontSize: 12 * textScaleFactor,
                                                color: Colors.grey[400],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          showEditIcon: false,
                                        );
                                      }),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}