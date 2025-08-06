import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TimetableSimple extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const TimetableSimple({super.key, required this.userData});

  @override
  _TimetableSimpleState createState() => _TimetableSimpleState();
}

class _TimetableSimpleState extends State<TimetableSimple> {
  static const String _baseUrl = 'http://192.168.1.33:5000';
  static const List<String> defaultDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  static const List<Map<String, dynamic>> defaultTimeSlots = [
    {'timeSlot': '09:00-10:00', 'isBreak': false},
    {'timeSlot': '10:00-11:00', 'isBreak': false},
    {'timeSlot': '11:15-12:15', 'isBreak': true},
    {'timeSlot': '12:15-13:15', 'isBreak': false},
    {'timeSlot': '14:00-15:00', 'isBreak': false},
    {'timeSlot': '15:00-16:00', 'isBreak': false},
  ];

  Map<String, dynamic> timetable = {
    'department': '',
    'semester': '',
    'section': '',
    'schedule': [],
  };
  List<Map<String, dynamic>> faculties = [];
  List<Map<String, dynamic>> subjects = [];
  Map<String, List<Map<String, dynamic>>> subjectFacultyMap = {};
  Map<String, List<String>> conflictingFaculties = {};
  Map<String, List<Map<String, dynamic>>> facultySchedules = {};
  Map<String, dynamic>? ccAssignment;
  String? currentTimetableId;
  bool isLoading = false;
  bool isEditing = false;
  bool isEditingTimeSlots = false;
  String message = '';
  String loadingStatus = '';
  bool showDeleteConfirmation = false;
  List<Map<String, dynamic>> timeSlots = [];
  Map<String, dynamic> newTimeSlot = {'start': '', 'end': '', 'isBreak': false};

  @override
  void initState() {
    super.initState();
    timeSlots = defaultTimeSlots;
    if (widget.userData == null || widget.userData!['token'] == null) {
      setState(() => message = 'Please log in to access the timetable.');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
    } else {
      fetchCCAssignment();
    }
  }

  Future<void> fetchCCAssignment() async {
    setState(() {
      isLoading = true;
      message = '';
    });
    try {
      final token = widget.userData!['token'];
      final response = await http.get(
        Uri.parse('$_baseUrl/api/cc/my-cc-assignments'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] && data['data']?['ccAssignments']?.isNotEmpty) {
        final assignment = data['data']['ccAssignments'][0];
        setState(() {
          ccAssignment = assignment;
          timetable = {
            ...timetable,
            'department': assignment['department'],
            'semester': assignment['semester'],
            'section': assignment['section'],
          };
        });
        await loadDepartmentData(assignment['department']);
        setState(() => message = 'CC Assignment loaded: ${assignment['department']} - Sem ${assignment['semester']} - Sec ${assignment['section']}');
        loadTimetable();
      } else {
        setState(() => message = 'No CC assignment found. You may not have permission to create timetables.');
      }
    } catch (error) {
      final errorMsg = error.toString();
      setState(() => message = errorMsg.contains('401') ? 'Authentication failed. Please log in again.' : 'Failed to fetch CC assignment: $errorMsg');
      if (errorMsg.contains('401') || errorMsg.contains('403')) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadDepartmentData(String department) async {
    if (department.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final token = widget.userData!['token'];
      final headers = {'Authorization': 'Bearer $token'};

      // Load subjects
      try {
        final subjectsRes = await http.get(
          Uri.parse('$_baseUrl/api/subjects/department/$department'),
          headers: headers,
        );
        final subjectsData = jsonDecode(subjectsRes.body);
        if (subjectsData['success']) {
          setState(() => subjects = List<Map<String, dynamic>>.from(subjectsData['data'] ?? []));
        } else {
          final altSubjectsRes = await http.get(
            Uri.parse('$_baseUrl/api/superadmin/subjects?department=$department'),
            headers: headers,
          );
          final altSubjectsData = jsonDecode(altSubjectsRes.body);
          setState(() => subjects = List<Map<String, dynamic>>.from(altSubjectsData['data'] ?? []));
        }
      } catch (_) {
        final fdsRes = await http.get(
          Uri.parse('$_baseUrl/api/faculty-dept-subject/department-faculty-subjects/$department'),
          headers: headers,
        );
        final fdsData = jsonDecode(fdsRes.body);
        if (fdsData['success'] && fdsData['data']?['subjectFacultyMap'] != null) {
          final subjectNames = fdsData['data']['subjectFacultyMap'].keys.toList();
          setState(() => subjects = subjectNames.map((name) => {
            'name': name,
            'code': name.substring(0, 6).toUpperCase(),
            '_id': name.replaceAll(' ', '_').toLowerCase(),
          }).toList());
        }
      }

      // Load faculties
      try {
        final facultiesRes = await http.get(
          Uri.parse('$_baseUrl/api/faculty/faculties?department=$department&teachingOnly=true'),
          headers: headers,
        );
        final facultiesData = jsonDecode(facultiesRes.body);
        setState(() => faculties = List<Map<String, dynamic>>.from(facultiesData['data']?['faculties'] ?? facultiesData['faculties'] ?? []).map((f) => {
          'id': f['employeeId'] ?? f['_id'],
          'name': '${f['firstName']} ${f['lastName'] ?? ''}'.trim(),
          'employeeId': f['employeeId'],
        }).toList());
      } catch (_) {
        final altFacultiesRes = await http.get(
          Uri.parse('$_baseUrl/api/faculty'),
          headers: headers,
        );
        final altFacultiesData = jsonDecode(altFacultiesRes.body);
        final allFaculties = List<Map<String, dynamic>>.from(altFacultiesData['data'] ?? altFacultiesData);
        setState(() => faculties = allFaculties.where((f) => f['department'] == department).map((f) => {
          'id': f['employeeId'] ?? f['_id'],
          'name': '${f['firstName']} ${f['lastName'] ?? ''}'.trim(),
          'employeeId': f['employeeId'],
        }).toList());
      }

      // Build subject-faculty mapping
      await buildSubjectFacultyMap(department, headers);
      await loadConflictingFaculties();
    } catch (error) {
      final errorMsg = error.toString();
      setState(() => message = errorMsg.contains('401') || errorMsg.contains('403') ? 'Authentication failed. Please log in again.' : 'Failed to load department data: $errorMsg');
      if (errorMsg.contains('401') || errorMsg.contains('403')) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> buildSubjectFacultyMap(String department, Map<String, String> headers) async {
    try {
      final subjectsRes = await http.get(
        Uri.parse('$_baseUrl/api/subjects/department/$department'),
        headers: headers,
      );
      final subjectsData = jsonDecode(subjectsRes.body);
      if (subjectsData['success']) {
        final adminSubjects = List<Map<String, dynamic>>.from(subjectsData['data'] ?? []);
        final mapping = <String, List<Map<String, dynamic>>>{};
        for (var subject in adminSubjects) {
          try {
            final facultiesRes = await http.get(
              Uri.parse('$_baseUrl/api/faculty/faculties/subject/${subject['_id']}'),
              headers: headers,
            );
            final facultiesData = jsonDecode(facultiesRes.body);
            mapping[subject['name']] = facultiesData['success']
                ? List<Map<String, dynamic>>.from(facultiesData['data']?['faculties'] ?? []).map((f) => {
              'name': '${f['firstName']} ${f['lastName'] ?? ''}'.trim(),
              'employeeId': f['employeeId'] ?? f['_id'],
              'id': f['_id'],
            }).toList()
                : [];
          } catch (_) {
            mapping[subject['name']] = [];
          }
        }
        setState(() {
          subjectFacultyMap = mapping;
          message = 'Loaded ${adminSubjects.length} subjects with ${mapping.values.fold(0, (sum, faculties) => sum + faculties.length)} faculty assignments';
        });
      } else {
        await buildSubjectFacultyMapFallback(department, headers);
      }
    } catch (_) {
      await buildSubjectFacultyMapFallback(department, headers);
    }
  }

  Future<void> buildSubjectFacultyMapFallback(String department, Map<String, String> headers) async {
    try {
      final facultiesRes = await http.get(
        Uri.parse('$_baseUrl/api/faculty/faculties?department=$department&teachingOnly=true'),
        headers: headers,
      );
      var facultyList = jsonDecode(facultiesRes.body)['data']?['faculties'] ?? [];
      if (facultyList.isEmpty) {
        final altFacultiesRes = await http.get(
          Uri.parse('$_baseUrl/api/faculty'),
          headers: headers,
        );
        final allFaculties = jsonDecode(altFacultiesRes.body)['data'] ?? [];
        facultyList = allFaculties.where((f) => f['department'] == department).toList();
      }

      final mapping = <String, List<Map<String, dynamic>>>{};
      final uniqueSubjects = <String>{};
      for (var faculty in facultyList) {
        final facultyName = '${faculty['firstName']} ${faculty['lastName'] ?? ''}'.trim();
        final subjectsTaught = List.from(faculty['subjectsTaught'] ?? []);
        for (var subject in subjectsTaught) {
          final subjectName = subject is String ? subject : subject['name'] ?? '';
          if (subjectName.isNotEmpty) {
            uniqueSubjects.add(subjectName);
            mapping.putIfAbsent(subjectName, () => []);
            if (!mapping[subjectName]!.any((f) => f['name'] == facultyName)) {
              mapping[subjectName]!.add({
                'name': facultyName,
                'employeeId': faculty['employeeId'] ?? faculty['_id'],
                'id': faculty['_id'],
              });
            }
          }
        }
      }

      if (subjects.isEmpty && uniqueSubjects.isNotEmpty) {
        setState(() => subjects = uniqueSubjects.map((name) => {
          'name': name,
          'code': name.substring(0, 6).toUpperCase(),
          '_id': name.replaceAll(' ', '_').toLowerCase(),
        }).toList());
      }
      setState(() {
        subjectFacultyMap = mapping;
        message = 'Loaded ${mapping.length} subjects with ${mapping.values.fold(0, (sum, faculties) => sum + faculties.length)} faculty assignments (fallback)';
      });
    } catch (error) {
      setState(() => message = 'Failed to load subject-faculty assignments: $error');
    }
  }

  Future<void> loadConflictingFaculties() async {
    try {
      final token = widget.userData!['token'];
      final response = await http.get(
        Uri.parse('$_baseUrl/api/timetable'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final allTimetables = jsonDecode(response.body) ?? [];
      final conflicts = <String, List<String>>{};
      final schedules = <String, List<Map<String, dynamic>>>{};

      for (var timetable in allTimetables) {
        final ttInfo = '${timetable['collegeInfo']?['department'] ?? 'Unknown'} - ${timetable['collegeInfo']?['semester'] ?? 'Unknown'} - ${timetable['collegeInfo']?['section'] ?? 'Unknown'}';
        final isCurrentTimetable = ccAssignment != null &&
            timetable['collegeInfo']?['department'] == ccAssignment!['department'] &&
            timetable['collegeInfo']?['semester'] == ccAssignment!['semester'] &&
            timetable['collegeInfo']?['section'] == ccAssignment!['section'];

        for (var day in timetable['timetableData'] ?? []) {
          for (var cls in day['classes'] ?? []) {
            if (cls['faculty'] != null && cls['timeSlot'] != null) {
              final conflictKey = '${day['day']}_${cls['timeSlot']}';
              final facultyKey = cls['faculty'];
              conflicts.putIfAbsent(conflictKey, () => []);
              schedules.putIfAbsent(facultyKey, () => []);
              final conflictInfo = {
                'faculty': cls['faculty'],
                'subject': cls['subject'] ?? 'Unknown Subject',
                'timetableInfo': ttInfo,
                'isCurrentTimetable': isCurrentTimetable,
                'day': day['day'],
                'timeSlot': cls['timeSlot'],
              };
              if (!isCurrentTimetable) {
                conflicts[conflictKey]!.add(cls['faculty']);
              }
              schedules[facultyKey]!.add(conflictInfo);
            }
          }
        }
      }
      setState(() {
        conflictingFaculties = conflicts;
        facultySchedules = schedules;
      });
    } catch (error) {
      setState(() => message = 'Failed to load faculty conflicts: $error');
    }
  }

  void initializeTimetable() {
    final schedule = defaultDays.map((day) => {
      'day': day,
      'periods': timeSlots.map((slot) => {
        'timeSlot': slot['timeSlot'],
        'subject': '',
        'faculty': '',
        'type': slot['isBreak'] ? 'Break' : 'Theory',
      }).toList(),
    }).toList();
    setState(() {
      timetable = {...timetable, 'schedule': schedule};
      currentTimetableId = null;
      isEditing = true;
    });
  }

  void addTimeSlot() {
    if (newTimeSlot['start'].isEmpty || newTimeSlot['end'].isEmpty) {
      setState(() => message = 'Please enter both start and end times');
      return;
    }
    final timeSlotString = '${newTimeSlot['start']}-${newTimeSlot['end']}';
    if (timeSlots.any((slot) => slot['timeSlot'] == timeSlotString)) {
      setState(() => message = 'This time slot already exists');
      return;
    }
    final newSlot = {'timeSlot': timeSlotString, 'isBreak': newTimeSlot['isBreak']};
    setState(() {
      timeSlots = [...timeSlots, newSlot];
      newTimeSlot = {'start': '', 'end': '', 'isBreak': false};
      message = 'Time slot added successfully!';
      if (timetable['schedule'].isNotEmpty) {
        timetable['schedule'] = timetable['schedule'].map((day) => {
          ...day,
          'periods': [
            ...day['periods'],
            {
              'timeSlot': timeSlotString,
              'subject': '',
              'faculty': '',
              'type': newSlot['isBreak'] ? 'Break' : 'Theory',
            }
          ],
        }).toList();
      }
    });
  }

  void removeTimeSlot(String timeSlotToRemove) {
    setState(() {
      timeSlots = timeSlots.where((slot) => slot['timeSlot'] != timeSlotToRemove).toList();
      if (timetable['schedule'].isNotEmpty) {
        timetable['schedule'] = timetable['schedule'].map((day) => {
          ...day,
          'periods': day['periods'].where((period) => period['timeSlot'] != timeSlotToRemove).toList(),
        }).toList();
      }
      message = 'Time slot removed successfully!';
    });
  }

  void toggleBreakStatus(String timeSlotToToggle) {
    setState(() {
      timeSlots = timeSlots.map((slot) => slot['timeSlot'] == timeSlotToToggle
          ? {...slot, 'isBreak': !slot['isBreak']}
          : slot).toList();
      if (timetable['schedule'].isNotEmpty) {
        timetable['schedule'] = timetable['schedule'].map((day) => {
          ...day,
          'periods': day['periods'].map((period) => period['timeSlot'] == timeSlotToToggle
              ? {
            ...period,
            'type': period['type'] == 'Break' ? 'Theory' : 'Break',
            'subject': '',
            'faculty': '',
          }
              : period).toList(),
        }).toList();
      }
      message = 'Time slot updated successfully!';
    });
  }

  Future<void> updateCell(int dayIndex, int periodIndex, String field, String value) async {
    setState(() {
      final newSchedule = List<Map<String, dynamic>>.from(timetable['schedule']);
      final currentPeriod = newSchedule[dayIndex]['periods'][periodIndex];
      if (field == 'subject') {
        currentPeriod['subject'] = value;
        currentPeriod['faculty'] = '';
        final availableFaculties = getAvailableFacultiesForSubject(
            value, newSchedule[dayIndex]['day'], currentPeriod['timeSlot']);
        if (availableFaculties.length == 1) {
          currentPeriod['faculty'] = availableFaculties[0]['name'];
          message = 'Auto-selected faculty: ${availableFaculties[0]['name']} for $value';
        } else if (availableFaculties.length == 0 && value.isNotEmpty) {
          getFacultiesForSubject(value).then((apiFaculties) {
            if (apiFaculties.length == 1) {
              setState(() {
                newSchedule[dayIndex]['periods'][periodIndex]['faculty'] = apiFaculties[0]['name'];
                message = 'Auto-selected faculty: ${apiFaculties[0]['name']} for $value';
              });
            } else if (apiFaculties.length > 1) {
              setState(() => message = '${apiFaculties.length} faculties available for $value. Please select one.');
            } else {
              setState(() => message = 'No faculty assigned to teach $value. Please contact admin.');
            }
          }).catchError((error) {
            setState(() => message = 'Unable to load faculty for $value. Please try again.');
          });
        } else if (availableFaculties.length > 1) {
          message = '${availableFaculties.length} faculties available for $value. Please select one.';
        }
      } else {
        currentPeriod[field] = value;
      }
      timetable = {...timetable, 'schedule': newSchedule};
    });
  }

  List<Map<String, dynamic>> getAvailableFacultiesForSubject(String subjectName, String day, String timeSlot) {
    if (subjectName.isEmpty) return [];
    var assignedFaculties = subjectFacultyMap[subjectName] ?? [];
    if (assignedFaculties.isEmpty) {
      final subjectKey = subjectFacultyMap.keys.firstWhere(
            (key) => key.toLowerCase() == subjectName.toLowerCase(),
        orElse: () => '',
      );
      if (subjectKey.isNotEmpty) assignedFaculties = subjectFacultyMap[subjectKey] ?? [];
      if (assignedFaculties.isEmpty) {
        final partialKey = subjectFacultyMap.keys.firstWhere(
              (key) => key.toLowerCase().contains(subjectName.toLowerCase()) || subjectName.toLowerCase().contains(key.toLowerCase()),
          orElse: () => '',
        );
        if (partialKey.isNotEmpty) assignedFaculties = subjectFacultyMap[partialKey] ?? [];
      }
    }
    final conflictKey = '${day}_$timeSlot';
    final conflictedFaculties = conflictingFaculties[conflictKey] ?? [];
    final availableFaculties = assignedFaculties.where((faculty) => !conflictedFaculties.contains(faculty['name'])).toList();
    return availableFaculties.map((faculty) {
      final facultySchedule = facultySchedules[faculty['name']] ?? [];
      final conflictsAtThisTime = facultySchedule.where((s) => s['day'] == day && s['timeSlot'] == timeSlot).toList();
      return {
        ...faculty,
        'scheduleInfo': {
          'totalClasses': facultySchedule.length,
          'conflictsAtThisTime': conflictsAtThisTime,
          'hasConflict': conflictsAtThisTime.isNotEmpty,
        },
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getFacultiesForSubject(String subjectName) async {
    if (subjectName.isEmpty || ccAssignment == null) return [];
    try {
      final token = widget.userData!['token'];
      final response = await http.get(
        Uri.parse('$_baseUrl/api/faculty-subject/subject-faculty-by-name/$subjectName'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success']) {
        return List<Map<String, dynamic>>.from(data['data']?['faculties'] ?? []);
      }
    } catch (error) {
      setState(() => message = 'Error fetching faculties for subject: $error');
    }
    return [];
  }

  Future<void> handleRefreshData() async {
    setState(() {
      isLoading = true;
      loadingStatus = 'Refreshing data...';
    });
    try {
      setState(() {
        subjects = [];
        faculties = [];
        subjectFacultyMap = {};
      });
      if (ccAssignment?['department'] != null) {
        await loadDepartmentData(ccAssignment!['department']);
        setState(() => loadingStatus = 'Data refreshed successfully!');
      } else {
        setState(() => loadingStatus = 'No CC assignment found - cannot reload data');
      }
      await Future.delayed(const Duration(seconds: 3));
      setState(() => loadingStatus = '');
    } catch (error) {
      setState(() {
        loadingStatus = 'Failed to refresh data';
        Future.delayed(const Duration(seconds: 3), () => setState(() => loadingStatus = ''));
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> saveTimetable() async {
    if (ccAssignment == null) {
      setState(() => message = 'No CC assignment found. Cannot save timetable.');
      return;
    }
    if (timetable['department'].isEmpty || timetable['semester'].isEmpty || timetable['section'].isEmpty) {
      setState(() => message = 'Please ensure all basic information is filled');
      return;
    }
    if (timetable['schedule'].isEmpty) {
      setState(() => message = 'Please create a timetable schedule first.');
      return;
    }
    setState(() => isLoading = true);
    try {
      final token = widget.userData!['token'];
      final payload = {
        'collegeInfo': {
          'name': 'College Name',
          'status': 'Active',
          'department': timetable['department'],
          'semester': timetable['semester'],
          'section': timetable['section'],
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        },
        'subjects': subjects.map((subject) => {
          'code': subject['code'] ?? '',
          'name': subject['name'],
          'faculty': subject['faculty'] ?? '',
        }).toList(),
        'timetableData': timetable['schedule'].map((day) => {
          'day': day['day'],
          'classes': day['periods']
              .where((period) => period['subject'].isNotEmpty && period['type'] != 'Break')
              .map((period) => {
            'subject': period['subject'],
            'faculty': period['faculty'],
            'type': period['type'] ?? 'Theory',
            'timeSlot': period['timeSlot'],
            'colSpan': 1,
          }).toList(),
        }).toList(),
        'timeSlots': timeSlots.map((slot) => slot['timeSlot']).toList(),
      };
      final response = await http.post(
        Uri.parse('$_baseUrl/api/timetable'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success']) {
        setState(() {
          message = 'Timetable saved successfully!';
          isEditing = false;
          currentTimetableId = data['data']?['_id'];
        });
        await loadConflictingFaculties();
      } else {
        throw Exception(data['message'] ?? data['error'] ?? 'Failed to save timetable');
      }
    } catch (error) {
      final errorMsg = error.toString();
      setState(() => message = errorMsg.contains('403')
          ? 'Access denied. You can only create timetables for your assigned class.'
          : errorMsg.contains('409')
          ? 'A timetable already exists for this department, semester, and section.'
          : 'Failed to save timetable: $errorMsg');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadTimetable() async {
    if (ccAssignment == null) return;
    setState(() => isLoading = true);
    try {
      final token = widget.userData!['token'];
      final response = await http.get(
        Uri.parse('$_baseUrl/api/timetable?department=${ccAssignment!['department']}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      final timetableData = data is List
          ? data.firstWhere(
            (tt) =>
        tt['collegeInfo']?['department'] == ccAssignment!['department'] &&
            tt['collegeInfo']?['semester'] == ccAssignment!['semester'] &&
            tt['collegeInfo']?['section'] == ccAssignment!['section'],
        orElse: () => null,
      )
          : data['collegeInfo'] != null ? data : null;

      if (timetableData != null) {
        setState(() => currentTimetableId = timetableData['_id']);
        if (timetableData['timeSlots']?.isNotEmpty) {
          setState(() => timeSlots = List.from(timetableData['timeSlots']).map((slot) => {
            'timeSlot': slot,
            'isBreak': slot.contains('11:15') || slot.contains('Break'),
          }).toList());
        }
        final schedule = defaultDays.map((day) {
          final dayData = timetableData['timetableData']?.firstWhere(
                (d) => d['day'] == day,
            orElse: () => null,
          );
          return {
            'day': day,
            'periods': timeSlots.map((timeSlot) {
              final classData = dayData?['classes']?.firstWhere(
                    (c) => c['timeSlot'] == timeSlot['timeSlot'],
                orElse: () => null,
              );
              return {
                'timeSlot': timeSlot['timeSlot'],
                'subject': classData?['subject'] ?? '',
                'faculty': classData?['faculty'] ?? '',
                'type': classData?['type'] ?? (timeSlot['isBreak'] ? 'Break' : 'Theory'),
              };
            }).toList(),
          };
        }).toList();
        setState(() {
          timetable = {...timetable, 'schedule': schedule};
          message = 'Timetable loaded successfully!';
        });
      } else {
        setState(() => message = 'No existing timetable found.');
      }
    } catch (error) {
      setState(() => message = error.toString().contains('404')
          ? 'No existing timetable found.'
          : 'Failed to load timetable: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteTimetable() async {
    if (currentTimetableId == null) {
      setState(() => message = 'No timetable found to delete.');
      return;
    }
    setState(() => isLoading = true);
    try {
      final token = widget.userData!['token'];
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/timetable/$currentTimetableId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success']) {
        setState(() {
          message = 'Timetable deleted successfully!';
          timetable = {...timetable, 'schedule': []};
          currentTimetableId = null;
          isEditing = false;
          showDeleteConfirmation = false;
        });
        await loadConflictingFaculties();
      } else {
        throw Exception(data['message'] ?? data['error'] ?? 'Failed to delete timetable');
      }
    } catch (error) {
      final errorMsg = error.toString();
      setState(() => message = errorMsg.contains('403')
          ? 'Access denied. You can only delete timetables for your assigned class.'
          : errorMsg.contains('404')
          ? 'Timetable not found. It may have been already deleted.'
          : 'Failed to delete timetable: $errorMsg');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = EdgeInsets.symmetric(
      horizontal: isMobile ? 16.0 : 32.0,
      vertical: isMobile ? 24.0 : 48.0,
    );
    final textScaleFactor = isMobile ? 0.9 : 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Timetable',
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEFF6FF),
                  Color(0xFFF0F5FF),
                  Color(0xFFF5F3FF),
                ],
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x33A78BFA),
                boxShadow: [BoxShadow(blurRadius: 48, color: Colors.black.withOpacity(0.1))],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 384,
              height: 384,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x33BFDBFE),
                boxShadow: [BoxShadow(blurRadius: 48, color: Colors.black.withOpacity(0.1))],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5,
            left: MediaQuery.of(context).size.width * 0.5,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x33C7D2FE),
                boxShadow: [BoxShadow(blurRadius: 32, color: Colors.black.withOpacity(0.1))],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: padding,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Symbols.calendar_month, color: Color(0xFF2563EB), size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'Course Timetable',
                              style: TextStyle(
                                fontSize: 24 * textScaleFactor,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: message.contains('success')
                                ? const Color(0xFFF0FDF4)
                                : message.contains('Failed')
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: message.contains('success')
                                  ? const Color(0xFFBBF7D0)
                                  : message.contains('Failed')
                                  ? const Color(0xFFFECACA)
                                  : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Text(
                            message,
                            style: TextStyle(
                              color: message.contains('success')
                                  ? const Color(0xFF15803D)
                                  : message.contains('Failed')
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF1E40AF),
                              fontSize: 14 * textScaleFactor,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Basic Information
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Symbols.book, color: Color(0xFF2563EB), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Basic Information',
                                  style: TextStyle(
                                    fontSize: 18 * textScaleFactor,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Department',
                                        style: TextStyle(
                                          fontSize: 14 * textScaleFactor,
                                          color: const Color(0xFF4B5563),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                          borderRadius: BorderRadius.circular(12),
                                          color: const Color(0xFFDBEAFE),
                                        ),
                                        child: Text(
                                          timetable['department'].isNotEmpty
                                              ? timetable['department']
                                              : ccAssignment != null
                                              ? 'Loading...'
                                              : 'No CC Assignment',
                                          style: TextStyle(
                                            fontSize: 14 * textScaleFactor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Semester',
                                        style: TextStyle(
                                          fontSize: 14 * textScaleFactor,
                                          color: const Color(0xFF4B5563),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                          borderRadius: BorderRadius.circular(12),
                                          color: const Color(0xFFDBEAFE),
                                        ),
                                        child: Text(
                                          timetable['semester'].isNotEmpty
                                              ? timetable['semester']
                                              : ccAssignment != null
                                              ? 'Loading...'
                                              : 'No CC Assignment',
                                          style: TextStyle(
                                            fontSize: 14 * textScaleFactor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Section',
                                        style: TextStyle(
                                          fontSize: 14 * textScaleFactor,
                                          color: const Color(0xFF4B5563),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                          borderRadius: BorderRadius.circular(12),
                                          color: const Color(0xFFDBEAFE),
                                        ),
                                        child: Text(
                                          timetable['section'].isNotEmpty
                                              ? timetable['section']
                                              : ccAssignment != null
                                              ? 'Loading...'
                                              : 'No CC Assignment',
                                          style: TextStyle(
                                            fontSize: 14 * textScaleFactor,
                                            fontWeight: FontWeight.w500,
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
                      const SizedBox(height: 24),
                      // Action Buttons
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16)],
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (isLoading) ...[
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Loading...',
                                    style: TextStyle(
                                      fontSize: 14 * textScaleFactor,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (!isLoading && ccAssignment == null)
                              Text(
                                'Please wait while we load your CC assignment...',
                                style: TextStyle(
                                  fontSize: 14 * textScaleFactor,
                                  color: const Color(0xFFF97316),
                                ),
                              ),
                            if (loadingStatus.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: loadingStatus.contains('success')
                                      ? const Color(0xFFD1FAE5)
                                      : loadingStatus.contains('Failed')
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  loadingStatus,
                                  style: TextStyle(
                                    fontSize: 12 * textScaleFactor,
                                    color: loadingStatus.contains('success')
                                        ? const Color(0xFF15803D)
                                        : loadingStatus.contains('Failed')
                                        ? const Color(0xFFB91C1C)
                                        : const Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                            if (!isLoading && ccAssignment != null && !isEditing) ...[
                              ElevatedButton(
                                onPressed: () => setState(() => isEditing = true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Symbols.edit, color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Edit Timetable',
                                      style: TextStyle(
                                        fontSize: 14 * textScaleFactor,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: handleRefreshData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Symbols.refresh,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isLoading ? 'Reloading...' : 'Reload Subjects & Faculties',
                                      style: TextStyle(
                                        fontSize: 14 * textScaleFactor,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: initializeTimetable,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Symbols.add, color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Create New',
                                      style: TextStyle(
                                        fontSize: 14 * textScaleFactor,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => setState(() => isEditingTimeSlots = !isEditingTimeSlots),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9333EA),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Symbols.schedule, color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      isEditingTimeSlots ? 'Done' : 'Manage Time Slots',
                                      style: TextStyle(
                                        fontSize: 14 * textScaleFactor,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (currentTimetableId != null)
                                ElevatedButton(
                                  onPressed: () => setState(() => showDeleteConfirmation = true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Symbols.delete, color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Delete Timetable',
                                        style: TextStyle(
                                          fontSize: 14 * textScaleFactor,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            if (!isLoading && ccAssignment != null && isEditing) ...[
                              ElevatedButton(
                                onPressed: saveTimetable,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Symbols.save, color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      isLoading ? 'Saving...' : 'Save Timetable',
                                      style: TextStyle(
                                        fontSize: 14 * textScaleFactor,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => setState(() => isEditing = false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4B5563),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Symbols.close, color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 14 * textScaleFactor,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Debug Panel
                      if (ccAssignment != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFED7AA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🔧 Debug Information',
                                style: TextStyle(
                                  fontSize: 14 * textScaleFactor,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF9A3412),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'CC Assignment',
                                            style: TextStyle(
                                              fontSize: 12 * textScaleFactor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            ccAssignment != null
                                                ? '${ccAssignment!['department']} - Sem ${ccAssignment!['semester']} - Sec ${ccAssignment!['section']}'
                                                : 'Not loaded',
                                            style: TextStyle(
                                              fontSize: 12 * textScaleFactor,
                                              color: const Color(0xFF4B5563),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Subjects (${subjects.length})',
                                            style: TextStyle(
                                              fontSize: 12 * textScaleFactor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            subjects.isNotEmpty
                                                ? subjects.take(3).map((s) => s['name']).join(', ') + (subjects.length > 3 ? '...' : '')
                                                : 'No subjects loaded - Click "Reload" button!',
                                            style: TextStyle(
                                              fontSize: 12 * textScaleFactor,
                                              color: subjects.isEmpty ? const Color(0xFFDC2626) : const Color(0xFF4B5563),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Faculties (${faculties.length})',
                                            style: TextStyle(
                                              fontSize: 12 * textScaleFactor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            faculties.isNotEmpty
                                                ? faculties.take(2).map((f) => f['name']).join(', ') + (faculties.length > 2 ? '...' : '')
                                                : 'No faculties loaded',
                                            style: TextStyle(
                                              fontSize: 12 * textScaleFactor,
                                              color: faculties.isEmpty ? const Color(0xFFDC2626) : const Color(0xFF4B5563),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Subject-Faculty Assignments (${subjectFacultyMap.length})',
                                      style: TextStyle(
                                        fontSize: 12 * textScaleFactor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subjectFacultyMap.isNotEmpty
                                          ? subjectFacultyMap.keys.take(3).join(', ') + (subjectFacultyMap.length > 3 ? '...' : '')
                                          : 'No subject-faculty assignments loaded - Data may be missing in database!',
                                      style: TextStyle(
                                        fontSize: 12 * textScaleFactor,
                                        color: subjectFacultyMap.isEmpty ? const Color(0xFFDC2626) : const Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (subjects.isEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFED7AA)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '⚠️ No subjects found! This could mean:',
                                        style: TextStyle(
                                          fontSize: 12 * textScaleFactor,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF9A3412),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '• Faculty-Department-Subject relationships not set up in database\n'
                                            '• No subjects assigned to faculties in your department\n'
                                            '• API endpoint not responding correctly',
                                        style: TextStyle(
                                          fontSize: 12 * textScaleFactor,
                                          color: const Color(0xFF9A3412),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '💡 Try clicking the "Reload Subjects & Faculties" button above to retry loading.',
                                        style: TextStyle(
                                          fontSize: 12 * textScaleFactor,
                                          color: const Color(0xFFEA580C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      // Subject-Faculty Assignments
                      if (ccAssignment != null && isEditing && subjectFacultyMap.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📋 Subject-Faculty Assignments (Debug)',
                                style: TextStyle(
                                  fontSize: 14 * textScaleFactor,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: subjectFacultyMap.entries.map((entry) {
                                  final subject = entry.key;
                                  final faculties = entry.value;
                                  return Container(
                                    width: isMobile ? double.infinity : 300,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subject,
                                          style: TextStyle(
                                            fontSize: 12 * textScaleFactor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          faculties.isNotEmpty
                                              ? faculties.map((f) => f['name']).join(', ')
                                              : 'No faculty assigned',
                                          style: TextStyle(
                                            fontSize: 12 * textScaleFactor,
                                            color: faculties.isEmpty ? const Color(0xFFF97316) : const Color(0xFF4B5563),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Faculty Schedules
                      if (ccAssignment != null && isEditing && facultySchedules.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFF5F3FF), Color(0xFFE0E7FF)]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD8B4FE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🕒 Real-time Faculty Schedules (Cross-Class View)',
                                style: TextStyle(
                                  fontSize: 14 * textScaleFactor,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6D28D9),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: facultySchedules.entries.take(6).map((entry) {
                                  final facultyName = entry.key;
                                  final schedules = entry.value.where((s) => !s['isCurrentTimetable']).toList();
                                  return Container(
                                    width: isMobile ? double.infinity : 300,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFEDE9FE)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '👩‍🏫 $facultyName',
                                          style: TextStyle(
                                            fontSize: 12 * textScaleFactor,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF6D28D9),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...schedules.take(3).map((schedule) => Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '📚 ${schedule['subject']}',
                                              style: TextStyle(
                                                fontSize: 12 * textScaleFactor,
                                                color: const Color(0xFF6D28D9),
                                              ),
                                            ),
                                            Text(
                                              '🕐 ${schedule['day']} ${schedule['timeSlot']}',
                                              style: TextStyle(
                                                fontSize: 12 * textScaleFactor,
                                                color: const Color(0xFF6D28D9),
                                              ),
                                            ),
                                            Text(
                                              '🏫 ${schedule['timetableInfo']}',
                                              style: TextStyle(
                                                fontSize: 12 * textScaleFactor,
                                                color: const Color(0xFF6D28D9),
                                              ),
                                            ),
                                            const Divider(color: Color(0xFFEDE9FE)),
                                          ],
                                        )),
                                        if (schedules.isEmpty)
                                          Text(
                                            '✅ No other classes assigned',
                                            style: TextStyle(
                                              fontSize: 12 * textScaleFactor,
                                              color: const Color(0xFF15803D),
                                            ),
                                          ),
                                        if (schedules.length > 3)
                                          Text(
                                            '... and ${schedules.length - 3} more classes',
                                            style: TextStyle(
                                              fontSize: 12 * textScaleFactor,
                                              color: const Color(0xFF6D28D9),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (facultySchedules.length > 6)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Center(
                                    child: Text(
                                      'Showing 6 of ${facultySchedules.length} faculty schedules',
                                      style: TextStyle(
                                        fontSize: 12 * textScaleFactor,
                                        color: const Color(0xFF6D28D9),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      // Time Slot Management
                      if (isEditingTimeSlots) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Symbols.schedule, color: Color(0xFF9333EA), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Manage Time Slots',
                                    style: TextStyle(
                                      fontSize: 18 * textScaleFactor,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFD8B4FE)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add New Time Slot',
                                      style: TextStyle(
                                        fontSize: 16 * textScaleFactor,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6D28D9),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            decoration: InputDecoration(
                                              labelText: 'Start Time',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Color(0xFF9333EA), width: 2),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                              ),
                                              filled: true,
                                              fillColor: Colors.white.withOpacity(0.7),
                                              labelStyle: TextStyle(fontSize: 14 * textScaleFactor),
                                            ),
                                            onChanged: (value) => setState(() => newTimeSlot['start'] = value),
                                            initialValue: newTimeSlot['start'],
                                            keyboardType: TextInputType.datetime,
                                            enabled: !isLoading,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            decoration: InputDecoration(
                                              labelText: 'End Time',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Color(0xFF9333EA), width: 2),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                              ),
                                              filled: true,
                                              fillColor: Colors.white.withOpacity(0.7),
                                              labelStyle: TextStyle(fontSize: 14 * textScaleFactor),
                                            ),
                                            onChanged: (value) => setState(() => newTimeSlot['end'] = value),
                                            initialValue: newTimeSlot['end'],
                                            keyboardType: TextInputType.datetime,
                                            enabled: !isLoading,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          children: [
                                            Checkbox(
                                              value: newTimeSlot['isBreak'],
                                              onChanged: isLoading
                                                  ? null
                                                  : (value) => setState(() => newTimeSlot['isBreak'] = value!),
                                              activeColor: const Color(0xFF9333EA),
                                            ),
                                            Text(
                                              'Break Period',
                                              style: TextStyle(
                                                fontSize: 12 * textScaleFactor,
                                                color: const Color(0xFF4B5563),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton(
                                          onPressed: isLoading ? null : addTimeSlot,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF9333EA),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Symbols.add, color: Colors.white, size: 16),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Add Slot',
                                                style: TextStyle(
                                                  fontSize: 14 * textScaleFactor,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
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
                              const SizedBox(height: 16),
                              Text(
                                'Current Time Slots',
                                style: TextStyle(
                                  fontSize: 16 * textScaleFactor,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...timeSlots.map((slot) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            slot['timeSlot'],
                                            style: TextStyle(
                                              fontSize: 14 * textScaleFactor,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF1F2937),
                                            ),
                                          ),
                                          if (slot['isBreak']) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF7ED),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Break',
                                                style: TextStyle(
                                                  fontSize: 12 * textScaleFactor,
                                                  color: const Color(0xFF9A3412),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          TextButton(
                                            onPressed: isLoading ? null : () => toggleBreakStatus(slot['timeSlot']),
                                            style: TextButton.styleFrom(
                                              backgroundColor: slot['isBreak']
                                                  ? const Color(0xFFDBEAFE)
                                                  : const Color(0xFFFFF7ED),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: Text(
                                              slot['isBreak'] ? 'Make Class' : 'Make Break',
                                              style: TextStyle(
                                                fontSize: 12 * textScaleFactor,
                                                color: slot['isBreak'] ? const Color(0xFF1E40AF) : const Color(0xFF9A3412),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: isLoading ? null : () => removeTimeSlot(slot['timeSlot']),
                                            style: TextButton.styleFrom(
                                              backgroundColor: const Color(0xFFFEE2E2),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Symbols.delete, color: Color(0xFFB91C1C), size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Remove',
                                                  style: TextStyle(
                                                    fontSize: 12 * textScaleFactor,
                                                    color: const Color(0xFFB91C1C),
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
                              )),
                            ],
                          ),
                        ),
                      ],
                      // Timetable Grid
                      if (timetable['schedule'].isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Symbols.schedule, color: Color(0xFF2563EB), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Weekly Schedule',
                                    style: TextStyle(
                                      fontSize: 18 * textScaleFactor,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Table(
                                  border: TableBorder.all(color: const Color(0xFFD1D5DB)),
                                  defaultColumnWidth: const IntrinsicColumnWidth(),
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          child: Text(
                                            'Day',
                                            style: TextStyle(
                                              fontSize: 14 * textScaleFactor,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF4B5563),
                                            ),
                                          ),
                                        ),
                                        ...timeSlots.map((slot) => Container(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            children: [
                                              Text(
                                                slot['timeSlot'] ?? 'N/A',
                                                style: TextStyle(
                                                  fontSize: 14 * textScaleFactor,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF4B5563),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              if (slot['isBreak'] == true)
                                                Text(
                                                  'Break',
                                                  style: TextStyle(
                                                    fontSize: 12 * textScaleFactor,
                                                    color: const Color(0xFFD97706),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        )),
                                      ],
                                    ),
                                    ...timetable['schedule'].asMap().entries.map((dayEntry) {
                                      final dayIndex = dayEntry.key;
                                      final day = dayEntry.value as Map<String, dynamic>;
                                      return TableRow(
                                        decoration: BoxDecoration(
                                          color: dayIndex % 2 == 0 ? Colors.white : const Color(0xFFF9FAFB),
                                        ),
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(
                                              day['day']?.toString() ?? 'N/A',
                                              style: TextStyle(
                                                fontSize: 14 * textScaleFactor,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1F2937),
                                              ),
                                            ),
                                          ),
                                          ...day['periods'].asMap().entries.map((periodEntry) {
                                            final periodIndex = periodEntry.key;
                                            final period = periodEntry.value as Map<String, dynamic>;
                                            final isBreak = period['type'] == 'Break';
                                            final availableFaculties = isEditing && period['subject']?.isNotEmpty == true
                                                ? getAvailableFacultiesForSubject(
                                              period['subject'] as String,
                                              day['day'] as String,
                                              period['timeSlot'] as String,
                                            )
                                                : <Map<String, dynamic>>[];
                                            final conflictKey = '${day['day']}_${period['timeSlot']}';
                                            final conflicts = conflictingFaculties[conflictKey] ?? [];
                                            final hasConflict = availableFaculties.any((f) =>
                                            f['scheduleInfo'] != null && f['scheduleInfo']['hasConflict'] == true) ||
                                                (period['faculty']?.isNotEmpty == true && conflicts.contains(period['faculty']));

                                            return Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                border: hasConflict
                                                    ? Border.all(color: const Color(0xFFF97316), width: 2)
                                                    : null,
                                              ),
                                              child: isEditing && !isBreak
                                                  ? Column(
                                                children: [
                                                  DropdownButtonFormField<String>(
                                                    decoration: InputDecoration(
                                                      labelText: 'Subject',
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: const BorderSide(
                                                          color: Color(0xFF2563EB),
                                                          width: 2,
                                                        ),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: const BorderSide(
                                                          color: Color(0xFFD1D5DB),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white.withOpacity(0.7),
                                                      labelStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                                    ),
                                                    value: period['subject']?.isNotEmpty == true ? period['subject'] as String : null,
                                                    items: subjects.isNotEmpty
                                                        ? subjects.map((subject) {
                                                      // Ensure subject is a Map and has a 'name' key
                                                      if (subject is Map<String, dynamic> && subject['name'] is String) {
                                                        return DropdownMenuItem<String>(
                                                          value: subject['name'] as String,
                                                          child: Text(
                                                            subject['name'] as String,
                                                            style: TextStyle(fontSize: 12 * textScaleFactor),
                                                          ),
                                                        );
                                                      }
                                                      return null;
                                                    }).whereType<DropdownMenuItem<String>>().toList()
                                                        : [
                                                      DropdownMenuItem<String>(
                                                        value: null,
                                                        child: Text(
                                                          'No subjects available',
                                                          style: TextStyle(
                                                            fontSize: 12 * textScaleFactor,
                                                            color: const Color(0xFFF97316),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    onChanged: isLoading
                                                        ? null
                                                        : (value) => updateCell(dayIndex, periodIndex, 'subject', value ?? ''),
                                                    isExpanded: true,
                                                    dropdownColor: Colors.white,
                                                    menuMaxHeight: 200,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  DropdownButtonFormField<String>(
                                                    decoration: InputDecoration(
                                                      labelText: 'Faculty',
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: const BorderSide(
                                                          color: Color(0xFF2563EB),
                                                          width: 2,
                                                        ),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: const BorderSide(
                                                          color: Color(0xFFD1D5DB),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      filled: true,
                                                      fillColor: Colors.white.withOpacity(0.7),
                                                      labelStyle: TextStyle(fontSize: 12 * textScaleFactor),
                                                    ),
                                                    value: period['faculty']?.isNotEmpty == true ? period['faculty'] as String : null,
                                                    items: availableFaculties.isNotEmpty
                                                        ? availableFaculties.map((faculty) {
                                                      // Ensure faculty is a Map and has required keys
                                                      if (faculty is Map<String, dynamic> &&
                                                          faculty['name'] is String &&
                                                          faculty['scheduleInfo'] is Map) {
                                                        return DropdownMenuItem<String>(
                                                          value: faculty['name'] as String,
                                                          child: Text(
                                                            '${faculty['name']} ${faculty['scheduleInfo']['hasConflict'] == true ? '⚠️' : ''}',
                                                            style: TextStyle(
                                                              fontSize: 12 * textScaleFactor,
                                                              color: faculty['scheduleInfo']['hasConflict'] == true
                                                                  ? const Color(0xFFF97316)
                                                                  : const Color(0xFF1F2937),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      return null;
                                                    }).whereType<DropdownMenuItem<String>>().toList()
                                                        : [
                                                      DropdownMenuItem<String>(
                                                        value: null,
                                                        child: Text(
                                                          'No faculties available',
                                                          style: TextStyle(
                                                            fontSize: 12 * textScaleFactor,
                                                            color: const Color(0xFFF97316),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    onChanged: isLoading
                                                        ? null
                                                        : (value) => updateCell(dayIndex, periodIndex, 'faculty', value ?? ''),
                                                    isExpanded: true,
                                                    dropdownColor: Colors.white,
                                                    menuMaxHeight: 200,
                                                  ),
                                                  if (hasConflict) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      '⚠️ Conflict detected!',
                                                      style: TextStyle(
                                                        fontSize: 12 * textScaleFactor,
                                                        color: const Color(0xFFF97316),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              )
                                                  : Column(
                                                children: [
                                                  Text(
                                                    isBreak ? 'Break' : period['subject']?.isNotEmpty == true ? period['subject'] as String : '-',
                                                    style: TextStyle(
                                                      fontSize: 12 * textScaleFactor,
                                                      fontWeight: FontWeight.w500,
                                                      color: isBreak ? const Color(0xFFD97706) : const Color(0xFF1F2937),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    isBreak ? '' : period['faculty']?.isNotEmpty == true ? period['faculty'] as String : '-',
                                                    style: TextStyle(
                                                      fontSize: 12 * textScaleFactor,
                                                      color: hasConflict ? const Color(0xFFF97316) : const Color(0xFF4B5563),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  if (hasConflict) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '⚠️ Conflict',
                                                      style: TextStyle(
                                                        fontSize: 12 * textScaleFactor,
                                                        color: const Color(0xFFF97316),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Delete Confirmation Dialog
          if (showDeleteConfirmation)
            Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16)],
                ),
                constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.warning, color: Color(0xFFDC2626), size: 40),
                    const SizedBox(height: 16),
                    Text(
                      'Confirm Delete',
                      style: TextStyle(
                        fontSize: 18 * textScaleFactor,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Are you sure you want to delete this timetable? This action cannot be undone.',
                      style: TextStyle(
                        fontSize: 14 * textScaleFactor,
                        color: const Color(0xFF4B5563),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => showDeleteConfirmation = false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14 * textScaleFactor,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isLoading ? null : deleteTimetable,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.delete, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                isLoading ? 'Deleting...' : 'Delete',
                                style: TextStyle(
                                  fontSize: 14 * textScaleFactor,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }
}