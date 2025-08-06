import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ApplyLeave extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const ApplyLeave({super.key, this.userData});

  @override
  _ApplyLeaveState createState() => _ApplyLeaveState();
}

class _ApplyLeaveState extends State<ApplyLeave> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> formData = {
    'employeeId': '',
    'firstName': '',
    'leaveType': 'Sick Leave',
    'type': 'Faculty',
    'department': '',
    'startDate': '',
    'endDate': '',
    'reason': '',
    'leaveDuration': 'Full Day',
  };
  Map<String, String> errors = {};
  String message = '';
  bool isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  static const String _baseUrl = 'http://192.168.1.33:5000';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _fadeController.forward();

    // Initialize formData with userData or SharedPreferences
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user');
    Map<String, dynamic>? storedUserData;
    if (userDataString != null) {
      storedUserData = jsonDecode(userDataString);
    }

    final userData = widget.userData ?? storedUserData ?? {};
    final role = userData['role']?.toString().toLowerCase() ?? '';

    setState(() {
      formData = {
        ...formData,
        'employeeId': userData['employeeId']?.toString() ?? '',
        'firstName': userData['firstName']?.toString() ?? '',
        'type': role == 'hod'
            ? 'HOD'
            : role == 'principal'
            ? 'Principal'
            : role == 'nonteaching'
            ? 'Staff'
            : 'Faculty',
        'department': userData['department']?.toString() ?? '',
      };
    });

    debugPrint('Initialized formData: $formData');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  bool validateForm() {
    final newErrors = <String, String>{};
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    if (formData['startDate'].isEmpty) {
      newErrors['startDate'] = 'Start date is required';
    } else {
      try {
        final startDate = DateFormat('yyyy-MM-dd').parse(formData['startDate']);
        if (startDate.isBefore(todayStart)) {
          newErrors['startDate'] = 'Start date cannot be in the past';
        }
      } catch (e) {
        newErrors['startDate'] = 'Invalid start date format';
      }
    }

    if (formData['endDate'].isEmpty) {
      newErrors['endDate'] = 'End date is required';
    } else if (formData['startDate'].isNotEmpty) {
      try {
        final startDate = DateFormat('yyyy-MM-dd').parse(formData['startDate']);
        final endDate = DateFormat('yyyy-MM-dd').parse(formData['endDate']);
        if (endDate.isBefore(startDate)) {
          newErrors['endDate'] = 'End date cannot be before start date';
        }
      } catch (e) {
        newErrors['endDate'] = 'Invalid end date format';
      }
    }

    if (formData['reason'].trim().isEmpty) {
      newErrors['reason'] = 'Reason is required';
    } else if (formData['reason'].trim().length < 10) {
      newErrors['reason'] = 'Reason must be at least 10 characters long';
    }

    setState(() {
      errors = newErrors;
    });
    return newErrors.isEmpty;
  }

  Future<void> handleSubmit() async {
    if (!validateForm()) return;

    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token == null) {
        setState(() {
          message = '❌ No authentication token found. Please log in.';
          isLoading = false;
        });
        return;
      }

      final payload = {
        ...formData,
        'employeeId': formData['employeeId'],
        'firstName': formData['firstName'],
        'department': formData['department'],
      };
      debugPrint('Submitting payload: $payload');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/leave/apply'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        setState(() {
          message = '✅ Leave application submitted successfully!';
          formData = {
            ...formData,
            'startDate': '',
            'endDate': '',
            'reason': '',
            'leaveType': 'Sick Leave',
            'leaveDuration': 'Full Day',
          };
          errors = {};
        });
      } else {
        throw Exception(data['message'] ?? 'Failed to submit leave application');
      }
    } catch (error) {
      debugPrint('Error submitting leave: $error');
      setState(() {
        message = '❌ ${error.toString().replaceFirst('Exception: ', '')}';
        isLoading = false;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = isMobile ? 12.0 : 16.0;
    final fontSizeLarge = isMobile ? 18.0 : 22.0;
    final fontSizeMedium = isMobile ? 14.0 : 16.0;
    final fontSizeSmall = isMobile ? 12.0 : 14.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Apply Leave',
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
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[50] ?? Colors.blue.shade50,
                  Colors.indigo[50] ?? Colors.indigo.shade50,
                  Colors.purple[50] ?? Colors.purple.shade50,
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: EdgeInsets.all(padding),
                      padding: EdgeInsets.all(padding),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue[800] ?? Colors.blue.shade800,
                            Colors.purple[800] ?? Colors.purple.shade800,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '📝 Leave Application',
                            style: TextStyle(
                              fontSize: fontSizeLarge,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Submit your leave request with ease and track your application status',
                            style: TextStyle(
                              fontSize: fontSizeSmall,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Main Card
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: padding),
                    padding: EdgeInsets.all(padding),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Form Header
                        Container(
                          padding: EdgeInsets.all(padding),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple[600] ?? Colors.purple.shade600,
                                Colors.blue[500] ?? Colors.blue.shade500,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: isMobile ? 40 : 48,
                                height: isMobile ? 40 : 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.description,
                                  color: Colors.white,
                                  size: isMobile ? 20 : 24,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Leave Application',
                                      style: TextStyle(
                                        fontSize: fontSizeMedium,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Submit Your Leave Request',
                                      style: TextStyle(
                                        fontSize: fontSizeSmall,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Employee Details
                        Container(
                          padding: EdgeInsets.all(padding),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[100] ?? Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue[500] ?? Colors.blue.shade500,
                                          Colors.purple[600] ?? Colors.purple.shade600,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '👤',
                                        style: TextStyle(fontSize: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Employee Details',
                                    style: TextStyle(
                                      fontSize: fontSizeMedium,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800] ?? Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    width: isMobile ? screenWidth - padding * 4 : (screenWidth - padding * 4 - 8) / 2,
                                    padding: EdgeInsets.all(padding),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[100] ?? Colors.grey.shade100),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Employee ID',
                                          style: TextStyle(
                                            fontSize: fontSizeSmall,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700] ?? Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formData['employeeId'] ?? 'N/A',
                                          style: TextStyle(
                                            fontSize: fontSizeSmall,
                                            color: Colors.grey[800] ?? Colors.grey.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: isMobile ? screenWidth - padding * 4 : (screenWidth - padding * 4 - 8) / 2,
                                    padding: EdgeInsets.all(padding),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[100] ?? Colors.grey.shade100),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Name',
                                          style: TextStyle(
                                            fontSize: fontSizeSmall,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700] ?? Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formData['firstName'] ?? 'N/A',
                                          style: TextStyle(
                                            fontSize: fontSizeSmall,
                                            color: Colors.grey[800] ?? Colors.grey.shade800,
                                            fontWeight: FontWeight.w500,
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
                        const SizedBox(height: 12),
                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Leave Type and Duration
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    width: isMobile ? screenWidth - padding * 4 : (screenWidth - padding * 4 - 8) / 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📋 Leave Type',
                                          style: TextStyle(
                                            fontSize: fontSizeSmall,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700] ?? Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          value: formData['leaveType'],
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.grey[200] ?? Colors.grey.shade200),
                                            ),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                            filled: true,
                                            fillColor: Colors.white.withOpacity(0.7),
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 'Sick Leave', child: Text('🤒 Sick Leave')),
                                            DropdownMenuItem(value: 'Casual Leave', child: Text('🏖️ Casual Leave')),
                                            DropdownMenuItem(value: 'Earned Leave', child: Text('💼 Earned Leave')),
                                            DropdownMenuItem(value: 'CompOff Leave', child: Text('⏰ CompOff Leave')),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              formData['leaveType'] = value ?? 'Sick Leave';
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: isMobile ? screenWidth - padding * 4 : (screenWidth - padding * 4 - 8) / 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '⏱️ Leave Duration',
                                          style: TextStyle(
                                            fontSize: fontSizeSmall,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700] ?? Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          value: formData['leaveDuration'],
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.grey[200] ?? Colors.grey.shade200),
                                            ),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                            filled: true,
                                            fillColor: Colors.white.withOpacity(0.7),
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 'Full Day', child: Text('🌅 Full Day')),
                                            DropdownMenuItem(value: 'Half Day', child: Text('🌗 Half Day')),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              formData['leaveDuration'] = value ?? 'Full Day';
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Employee Type
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '👤 Employee Type',
                                    style: TextStyle(
                                      fontSize: fontSizeSmall,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700] ?? Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: formData['type'],
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[200] ?? Colors.grey.shade200),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                      filled: true,
                                      fillColor: Colors.grey[100]?.withOpacity(0.7) ?? Colors.grey.shade100.withOpacity(0.7),
                                    ),
                                    style: TextStyle(
                                      fontSize: fontSizeSmall,
                                      color: Colors.grey[600] ?? Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (errors['type'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '⚠️ ${errors['type']}',
                                      style: TextStyle(fontSize: fontSizeSmall - 2, color: Colors.red[500] ?? Colors.red.shade500),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Start and End Date
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    width: isMobile ? screenWidth - padding * 4 : (screenWidth - padding * 4 - 8) / 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📅 Start Date',
                                          style: TextStyle(
                                            fontSize: fontSizeSmall,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700] ?? Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.grey[200] ?? Colors.grey.shade200),
                                            ),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                            filled: true,
                                            fillColor: Colors.white.withOpacity(0.7),
                                          ),
                                          onTap: () async {
                                            final selectedDate = await showDatePicker(
                                              context: context,
                                              initialDate: DateTime.now(),
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now().add(const Duration(days: 365)),
                                              builder: (context, child) {
                                                return Theme(
                                                  data: Theme.of(context).copyWith(
                                                    colorScheme: ColorScheme.light(
                                                      primary: Colors.blue[600] ?? Colors.blue.shade600,
                                                      onPrimary: Colors.white,
                                                      surface: Colors.white,
                                                    ),
                                                    textButtonTheme: TextButtonThemeData(
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: Colors.blue[600] ?? Colors.blue.shade600,
                                                      ),
                                                    ),
                                                  ),
                                                  child: child!,
                                                );
                                              },
                                            );
                                            if (selectedDate != null) {
                                              setState(() {
                                                formData['startDate'] = DateFormat('yyyy-MM-dd').format(selectedDate);
                                              });
                                            }
                                          },
                                          readOnly: true,
                                          controller: TextEditingController(text: formData['startDate']),
                                        ),
                                        if (errors['startDate'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '⚠️ ${errors['startDate']}',
                                            style: TextStyle(fontSize: fontSizeSmall - 2, color: Colors.red[500] ?? Colors.red.shade500),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: isMobile ? screenWidth - padding * 4 : (screenWidth - padding * 4 - 8) / 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '📅 End Date',
                                          style: TextStyle(
                                            fontSize: fontSizeSmall,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700] ?? Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: BorderSide(color: Colors.grey[200] ?? Colors.grey.shade200),
                                            ),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                            filled: true,
                                            fillColor: Colors.white.withOpacity(0.7),
                                          ),
                                          onTap: () async {
                                            final initialDate = formData['startDate'].isNotEmpty
                                                ? DateFormat('yyyy-MM-dd').parse(formData['startDate'])
                                                : DateTime.now();
                                            final selectedDate = await showDatePicker(
                                              context: context,
                                              initialDate: initialDate,
                                              firstDate: initialDate,
                                              lastDate: DateTime.now().add(const Duration(days: 365)),
                                              builder: (context, child) {
                                                return Theme(
                                                  data: Theme.of(context).copyWith(
                                                    colorScheme: ColorScheme.light(
                                                      primary: Colors.blue[600] ?? Colors.blue.shade600,
                                                      onPrimary: Colors.white,
                                                      surface: Colors.white,
                                                    ),
                                                    textButtonTheme: TextButtonThemeData(
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: Colors.blue[600] ?? Colors.blue.shade600,
                                                      ),
                                                    ),
                                                  ),
                                                  child: child!,
                                                );
                                              },
                                            );
                                            if (selectedDate != null) {
                                              setState(() {
                                                formData['endDate'] = DateFormat('yyyy-MM-dd').format(selectedDate);
                                              });
                                            }
                                          },
                                          readOnly: true,
                                          controller: TextEditingController(text: formData['endDate']),
                                        ),
                                        if (errors['endDate'] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '⚠️ ${errors['endDate']}',
                                            style: TextStyle(fontSize: fontSizeSmall - 2, color: Colors.red[500] ?? Colors.red.shade500),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Reason
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '📝 Reason',
                                    style: TextStyle(
                                      fontSize: fontSizeSmall,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700] ?? Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: formData['reason'],
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      hintText: 'Please provide a detailed reason for your leave request...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: Colors.grey[200] ?? Colors.grey.shade200),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.7),
                                    ),
                                    style: TextStyle(fontSize: fontSizeSmall),
                                    onChanged: (value) {
                                      setState(() {
                                        formData['reason'] = value;
                                      });
                                    },
                                  ),
                                  if (errors['reason'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '⚠️ ${errors['reason']}',
                                      style: TextStyle(fontSize: fontSizeSmall - 2, color: Colors.red[500] ?? Colors.red.shade500),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Submit Button
                              MouseRegion(
                                onEnter: (_) => _scaleController.forward(),
                                onExit: (_) => _scaleController.reverse(),
                                child: ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : handleSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600] ?? Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: fontSizeSmall),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      minimumSize: Size(double.infinity, isMobile ? 48 : 56),
                                    ),
                                    child: isLoading
                                        ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Submitting...',
                                          style: TextStyle(fontSize: fontSizeSmall, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    )
                                        : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.send, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Submit Application',
                                          style: TextStyle(fontSize: fontSizeSmall, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: EdgeInsets.all(padding),
                                  decoration: BoxDecoration(
                                    color: message.contains('Error') || message.contains('❌')
                                        ? (Colors.red[50]?.withOpacity(0.8) ?? Colors.red.shade50.withOpacity(0.8))
                                        : (Colors.green[50]?.withOpacity(0.8) ?? Colors.green.shade50.withOpacity(0.8)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: message.contains('Error') || message.contains('❌')
                                          ? (Colors.red[200] ?? Colors.red.shade200)
                                          : (Colors.green[200] ?? Colors.green.shade200),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        message.contains('Error') || message.contains('❌') ? '❌' : '✅',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          message,
                                          style: TextStyle(
                                            fontSize: fontSizeSmall,
                                            color: message.contains('Error') || message.contains('❌')
                                                ? (Colors.red[800] ?? Colors.red.shade800)
                                                : (Colors.green[800] ?? Colors.green.shade800),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Sent Leave Requests
                        Container(
                          padding: EdgeInsets.all(padding),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.indigo[50]?.withOpacity(0.5) ?? Colors.indigo.shade50.withOpacity(0.5),
                                Colors.purple[100]?.withOpacity(0.5) ?? Colors.purple.shade100.withOpacity(0.5),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(padding),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[500] ?? Colors.teal.shade500,
                                      Colors.teal[600] ?? Colors.teal.shade600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: isMobile ? 40 : 48,
                                      height: isMobile ? 40 : 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.list_alt,
                                        color: Colors.white,
                                        size: isMobile ? 20 : 24,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '📋 Your Leave Requests',
                                            style: TextStyle(
                                              fontSize: fontSizeMedium,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            'Track Application Status',
                                            style: TextStyle(
                                              fontSize: fontSizeSmall,
                                              color: Colors.white.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.all(padding),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'SentLeaveRequests Widget Placeholder\n'
                                      'Pass employeeId: ${formData['employeeId'] ?? 'N/A'} to fetch leave requests',
                                  style: TextStyle(
                                    fontSize: fontSizeSmall,
                                    color: Colors.grey[600] ?? Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600] ?? Colors.blue.shade600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}