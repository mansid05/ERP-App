import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApplyODLeaveScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const ApplyODLeaveScreen({super.key, this.userData});

  @override
  _ApplyODLeaveScreenState createState() => _ApplyODLeaveScreenState();
}

class _ApplyODLeaveScreenState extends State<ApplyODLeaveScreen> {
  static const String _baseUrl = 'http://192.168.1.33:5000';
  final _formKey = GlobalKey<FormState>();
  String leaveType = '';
  String startDate = '';
  String endDate = '';
  String contact = '';
  String reason = '';
  String eventName = '';
  String location = '';
  File? attachment;
  String attachmentName = '';
  File? approvalLetter;
  String approvalLetterName = '';
  String message = '';
  bool isLoading = false;
  Map<String, String> errors = {};
  Map<String, dynamic>? localUserData;

  final odLeaveTypes = [
    {'value': 'Conference', 'label': '🎓 Conference'},
    {'value': 'Workshop', 'label': '🔧 Workshop'},
    {'value': 'Seminar', 'label': '📚 Seminar'},
    {'value': 'Training', 'label': '💼 Training Program'},
    {'value': 'Official Duty', 'label': '🏛️ Official Duty'},
    {'value': 'Research Work', 'label': '🔬 Research Work'},
    {'value': 'Academic Visit', 'label': '🎯 Academic Visit'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user');
    final token = prefs.getString('authToken');

    if (userDataString == null || token == null) {
      setState(() {
        message = 'Please log in to apply for OD leave.';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    final storedUserData = jsonDecode(userDataString);
    setState(() {
      localUserData = {
        ...?widget.userData,
        ...storedUserData,
        'token': token,
      };
    });

    debugPrint('Initialized userData: $localUserData');
  }

  Map<String, String> validateForm() {
    final newErrors = <String, String>{};
    final today = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

    if (leaveType.isEmpty) newErrors['leaveType'] = 'OD leave type is required';
    if (startDate.isEmpty) newErrors['startDate'] = 'Start date is required';
    if (endDate.isEmpty) newErrors['endDate'] = 'End date is required';
    if (contact.isEmpty) newErrors['contact'] = 'Contact information is required';
    if (reason.isEmpty) newErrors['reason'] = 'Detailed reason is required';
    if (eventName.isEmpty) newErrors['eventName'] = 'Event/purpose name is required';
    if (location.isEmpty) newErrors['location'] = 'Location is required';

    if (startDate.isNotEmpty) {
      try {
        final start = DateTime.parse(startDate);
        if (start.isBefore(today)) {
          newErrors['startDate'] = 'Start date cannot be in the past';
        }
      } catch (e) {
        newErrors['startDate'] = 'Invalid start date format';
      }
    }

    if (startDate.isNotEmpty && endDate.isNotEmpty) {
      try {
        final start = DateTime.parse(startDate);
        final end = DateTime.parse(endDate);
        if (start.isAfter(end)) {
          newErrors['date'] = 'Start date must be before or equal to end date';
        }
      } catch (e) {
        newErrors['endDate'] = 'Invalid end date format';
      }
    }

    if (attachment != null && attachment!.lengthSync() > 5 * 1024 * 1024) {
      newErrors['attachment'] = 'Attachment size must be less than 5MB';
    }
    if (approvalLetter != null && approvalLetter!.lengthSync() > 5 * 1024 * 1024) {
      newErrors['approvalLetter'] = 'Approval letter size must be less than 5MB';
    }

    return newErrors;
  }

  Future<void> handleFileChange(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = File(result.files.single.path!);
      setState(() {
        if (type == 'attachment') {
          attachment = file;
          attachmentName = result.files.single.name;
        } else {
          approvalLetter = file;
          approvalLetterName = result.files.single.name;
        }
      });
    }
  }

  void clearFile(String type) {
    setState(() {
      if (type == 'attachment') {
        attachment = null;
        attachmentName = '';
      } else {
        approvalLetter = null;
        approvalLetterName = '';
      }
    });
  }

  void handleCancel() {
    setState(() {
      leaveType = '';
      startDate = '';
      endDate = '';
      contact = '';
      reason = '';
      eventName = '';
      location = '';
      attachment = null;
      attachmentName = '';
      approvalLetter = null;
      approvalLetterName = '';
      errors = {};
      message = '';
    });
  }

  Future<void> handleSubmit() async {
    final formErrors = validateForm();
    if (formErrors.isNotEmpty) {
      setState(() => errors = formErrors);
      return;
    }

    setState(() {
      errors = {};
      message = '';
      isLoading = true;
    });

    try {
      if (localUserData == null || localUserData!['employeeId'] == null || localUserData!['token'] == null) {
        throw Exception('User data or authentication token missing');
      }

      final employeeId = localUserData!['employeeId'];
      final role = (localUserData!['role'] ?? '').toLowerCase();
      String type = 'Faculty';
      if (role == 'hod') type = 'HOD';
      else if (role == 'principal') type = 'Principal';
      else if (role == 'nonteaching') type = 'Staff';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/leave/odleave/apply'),
      );
      request.headers['Authorization'] = 'Bearer ${localUserData!['token']}';
      request.fields['employeeId'] = employeeId;
      request.fields['firstName'] = localUserData!['firstName'] ?? '';
      request.fields['leaveType'] = leaveType;
      request.fields['type'] = type;
      request.fields['startDate'] = startDate;
      request.fields['endDate'] = endDate;
      request.fields['reason'] = reason;
      request.fields['contact'] = contact;
      request.fields['eventName'] = eventName;
      request.fields['location'] = location;

      if (attachment != null) {
        request.files.add(await http.MultipartFile.fromPath('attachment', attachment!.path));
      }
      if (approvalLetter != null) {
        request.files.add(await http.MultipartFile.fromPath('approvalLetter', approvalLetter!.path));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 200 && data['success']) {
        setState(() {
          message = data['message'] ?? '✅ OD Leave application submitted successfully!';
        });
        handleCancel();
      } else {
        throw Exception(data['message'] ?? 'Failed to submit OD leave application');
      }
    } catch (error) {
      debugPrint('Error submitting OD leave: $error');
      final errorMsg = error.toString().replaceFirst('Exception: ', '');
      setState(() => message = '❌ $errorMsg');
      if (error.toString().contains('401') || error.toString().contains('403')) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = EdgeInsets.symmetric(
      horizontal: isMobile ? 12.0 : 24.0,
      vertical: isMobile ? 16.0 : 32.0,
    );
    final fontSizeLarge = isMobile ? 24.0 : 32.0;
    final fontSizeMedium = isMobile ? 14.0 : 16.0;
    final fontSizeSmall = isMobile ? 12.0 : 14.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Apply OD Leave',
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
          // Gradient Background
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
          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: padding,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? screenWidth : 896),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF1F2937), Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            ).createShader(bounds),
                            child: Text(
                              'OD Leave Application',
                              style: TextStyle(
                                fontSize: fontSizeLarge,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Apply for On-Duty leave for conferences, workshops, training, and official duties',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: fontSizeMedium,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Employee Details
                      if (localUserData != null) ...[
                        Container(
                          padding: EdgeInsets.all(padding.horizontal),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
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
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
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
                                    width: isMobile ? screenWidth - padding.horizontal * 4 : (screenWidth - padding.horizontal * 4 - 8) / 2,
                                    padding: EdgeInsets.all(padding.horizontal),
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
                                          localUserData!['employeeId'] ?? 'N/A',
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
                                    width: isMobile ? screenWidth - padding.horizontal * 4 : (screenWidth - padding.horizontal * 4 - 8) / 2,
                                    padding: EdgeInsets.all(padding.horizontal),
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
                                          localUserData!['firstName'] ?? 'N/A',
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
                        const SizedBox(height: 24),
                      ],
                      // Form Card
                      Container(
                        padding: EdgeInsets.all(padding.horizontal),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Form Header
                              Container(
                                padding: EdgeInsets.all(padding.horizontal),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
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
                                      child: const Icon(
                                        Symbols.description,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'OD Leave Application',
                                            style: TextStyle(
                                              fontSize: fontSizeMedium,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            'On-Duty Leave Request Form',
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
                              // Message
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(padding.horizontal),
                                  decoration: BoxDecoration(
                                    color: message.contains('❌')
                                        ? Colors.red[50]?.withOpacity(0.8) ?? Colors.red.shade50.withOpacity(0.8)
                                        : Colors.green[50]?.withOpacity(0.8) ?? Colors.green.shade50.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: message.contains('❌')
                                          ? Colors.red[200] ?? Colors.red.shade200
                                          : Colors.green[200] ?? Colors.green.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        message.contains('❌') ? '❌' : '✅',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          message,
                                          style: TextStyle(
                                            fontSize: fontSizeSmall,
                                            color: message.contains('❌')
                                                ? Colors.red[800] ?? Colors.red.shade800
                                                : Colors.green[800] ?? Colors.green.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // Form Fields
                              const SizedBox(height: 16),
                              // OD Leave Type
                              DropdownButtonFormField<String>(
                                value: leaveType.isEmpty ? null : leaveType,
                                decoration: InputDecoration(
                                  labelText: 'Type of OD Leave',
                                  prefixIcon: const Icon(Symbols.event, color: Color(0xFF6B7280)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: errors.containsKey('leaveType')
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFD1D5DB),
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                  labelStyle: TextStyle(fontSize: fontSizeSmall),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                ),
                                items: odLeaveTypes.map((option) {
                                  return DropdownMenuItem(
                                    value: option['value'],
                                    child: Text(
                                      option['label']!,
                                      style: TextStyle(fontSize: fontSizeSmall),
                                    ),
                                  );
                                }).toList(),
                                onChanged: isLoading
                                    ? null
                                    : (value) => setState(() => leaveType = value!),
                                hint: Text(
                                  'Select the purpose of your OD leave',
                                  style: TextStyle(fontSize: fontSizeSmall),
                                ),
                              ),
                              if (errors.containsKey('leaveType')) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Symbols.warning, color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      errors['leaveType']!,
                                      style: TextStyle(
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeSmall - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Event/Purpose Name
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Event/Purpose Name',
                                  prefixIcon: const Icon(Symbols.event, color: Color(0xFF6B7280)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: errors.containsKey('eventName')
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFD1D5DB),
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                  hintText: 'e.g., International Conference on Technology',
                                  hintStyle: TextStyle(fontSize: fontSizeSmall),
                                  labelStyle: TextStyle(fontSize: fontSizeSmall),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                ),
                                enabled: !isLoading,
                                onChanged: (value) => setState(() => eventName = value),
                                initialValue: eventName,
                                style: TextStyle(fontSize: fontSizeSmall),
                              ),
                              if (errors.containsKey('eventName')) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Symbols.warning, color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      errors['eventName']!,
                                      style: TextStyle(
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeSmall - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Location
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Location',
                                  prefixIcon: const Icon(Symbols.location_on, color: Color(0xFF6B7280)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: errors.containsKey('location')
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFD1D5DB),
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                  hintText: 'e.g., Mumbai, Maharashtra',
                                  hintStyle: TextStyle(fontSize: fontSizeSmall),
                                  labelStyle: TextStyle(fontSize: fontSizeSmall),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                ),
                                enabled: !isLoading,
                                onChanged: (value) => setState(() => location = value),
                                initialValue: location,
                                style: TextStyle(fontSize: fontSizeSmall),
                              ),
                              if (errors.containsKey('location')) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Symbols.warning, color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      errors['location']!,
                                      style: TextStyle(
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeSmall - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Start Date and End Date
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    width: isMobile ? screenWidth - padding.horizontal * 4 : (screenWidth - padding.horizontal * 4 - 8) / 2,
                                    child: TextFormField(
                                      decoration: InputDecoration(
                                        labelText: 'Start Date',
                                        prefixIcon: const Icon(Symbols.calendar_month, color: Color(0xFF6B7280)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: errors.containsKey('startDate') || errors.containsKey('date')
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFFD1D5DB),
                                            width: 2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.7),
                                        hintStyle: TextStyle(fontSize: fontSizeSmall),
                                        labelStyle: TextStyle(fontSize: fontSizeSmall),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                      ),
                                      enabled: !isLoading,
                                      readOnly: true,
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now().add(const Duration(days: 365)),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: const ColorScheme.light(
                                                  primary: Color(0xFF4F46E5),
                                                  onPrimary: Colors.white,
                                                  surface: Colors.white,
                                                ),
                                                textButtonTheme: TextButtonThemeData(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Color(0xFF4F46E5),
                                                  ),
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setState(() => startDate = DateFormat('yyyy-MM-dd').format(picked));
                                        }
                                      },
                                      controller: TextEditingController(
                                        text: startDate.isEmpty ? '' : DateFormat('yyyy-MM-dd').format(DateTime.parse(startDate)),
                                      ),
                                      style: TextStyle(fontSize: fontSizeSmall),
                                    ),
                                  ),
                                  Container(
                                    width: isMobile ? screenWidth - padding.horizontal * 4 : (screenWidth - padding.horizontal * 4 - 8) / 2,
                                    child: TextFormField(
                                      decoration: InputDecoration(
                                        labelText: 'End Date',
                                        prefixIcon: const Icon(Symbols.calendar_month, color: Color(0xFF6B7280)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: errors.containsKey('endDate') || errors.containsKey('date')
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFFD1D5DB),
                                            width: 2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.7),
                                        hintStyle: TextStyle(fontSize: fontSizeSmall),
                                        labelStyle: TextStyle(fontSize: fontSizeSmall),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                      ),
                                      enabled: !isLoading,
                                      readOnly: true,
                                      onTap: () async {
                                        final initialDate = startDate.isNotEmpty
                                            ? DateTime.parse(startDate)
                                            : DateTime.now();
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: initialDate,
                                          firstDate: initialDate,
                                          lastDate: DateTime.now().add(const Duration(days: 365)),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: const ColorScheme.light(
                                                  primary: Color(0xFF4F46E5),
                                                  onPrimary: Colors.white,
                                                  surface: Colors.white,
                                                ),
                                                textButtonTheme: TextButtonThemeData(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Color(0xFF4F46E5),
                                                  ),
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setState(() => endDate = DateFormat('yyyy-MM-dd').format(picked));
                                        }
                                      },
                                      controller: TextEditingController(
                                        text: endDate.isEmpty ? '' : DateFormat('yyyy-MM-dd').format(DateTime.parse(endDate)),
                                      ),
                                      style: TextStyle(fontSize: fontSizeSmall),
                                    ),
                                  ),
                                ],
                              ),
                              if (errors.containsKey('startDate') || errors.containsKey('date')) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Symbols.warning, color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      errors['startDate'] ?? errors['date']!,
                                      style: TextStyle(
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeSmall - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (errors.containsKey('endDate') && !errors.containsKey('date')) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Symbols.warning, color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      errors['endDate']!,
                                      style: TextStyle(
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeSmall - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Contact
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Contact During Leave',
                                  prefixIcon: const Icon(Symbols.phone, color: Color(0xFF6B7280)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: errors.containsKey('contact')
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFD1D5DB),
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                  hintText: 'Phone number or email address',
                                  hintStyle: TextStyle(fontSize: fontSizeSmall),
                                  labelStyle: TextStyle(fontSize: fontSizeSmall),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                ),
                                enabled: !isLoading,
                                onChanged: (value) => setState(() => contact = value),
                                initialValue: contact,
                                style: TextStyle(fontSize: fontSizeSmall),
                              ),
                              if (errors.containsKey('contact')) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Symbols.warning, color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      errors['contact']!,
                                      style: TextStyle(
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeSmall - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Reason
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Detailed Purpose & Justification',
                                  prefixIcon: const Icon(Symbols.description, color: Color(0xFF6B7280)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: errors.containsKey('reason')
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFD1D5DB),
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                  hintText: '''Please provide comprehensive details about your OD leave request including:
• Purpose and objectives of the event/duty
• Expected benefits and learning outcomes
• How it aligns with institutional goals
• Any additional relevant information...''',
                                  hintStyle: TextStyle(fontSize: fontSizeSmall),
                                  labelStyle: TextStyle(fontSize: fontSizeSmall),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                ),
                                enabled: !isLoading,
                                onChanged: (value) => setState(() => reason = value),
                                initialValue: reason,
                                maxLines: 5,
                                style: TextStyle(fontSize: fontSizeSmall),
                              ),
                              if (errors.containsKey('reason')) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Symbols.warning, color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      errors['reason']!,
                                      style: TextStyle(
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeSmall - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Attachment
                              const SizedBox(height: 24),
                              Text(
                                'Attachment (Optional)',
                                style: TextStyle(
                                  fontSize: fontSizeMedium,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 8),
                              attachmentName.isNotEmpty
                                  ? Container(
                                padding: EdgeInsets.all(padding.horizontal),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Symbols.description, color: Color(0xFF1E40AF), size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            attachmentName,
                                            style: TextStyle(
                                              fontSize: fontSizeSmall,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF1E40AF),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'File uploaded successfully',
                                            style: TextStyle(
                                              fontSize: fontSizeSmall - 2,
                                              color: const Color(0xFF1E40AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: isLoading ? null : () => clearFile('attachment'),
                                      icon: const Icon(Symbols.close, color: Color(0xFF1E40AF)),
                                    ),
                                  ],
                                ),
                              )
                                  : InkWell(
                                onTap: isLoading ? null : () => handleFileChange('attachment'),
                                child: Container(
                                  padding: EdgeInsets.all(padding.horizontal),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFD1D5DB),
                                      width: 2,
                                      style: BorderStyle.solid,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Symbols.upload,
                                        color: Color(0xFF6B7280),
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Choose file to upload',
                                        style: TextStyle(
                                          fontSize: fontSizeSmall,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF374151),
                                        ),
                                      ),
                                      Text(
                                        'or drag and drop here',
                                        style: TextStyle(
                                          fontSize: fontSizeSmall - 2,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (errors.containsKey('attachment')) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Symbols.warning, color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      errors['attachment']!,
                                      style: TextStyle(
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeSmall - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Symbols.info, color: Color(0xFF6B7280), size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Upload supporting documents if required (max 5MB)',
                                      style: TextStyle(
                                        fontSize: fontSizeSmall - 2,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Approval Letter
                              const SizedBox(height: 24),
                              Text(
                                'Event Approval/Invitation Letter (Recommended)',
                                style: TextStyle(
                                  fontSize: fontSizeMedium,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 8),
                              approvalLetterName.isNotEmpty
                                  ? Container(
                                padding: EdgeInsets.all(padding.horizontal),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF0FDF4), Color(0xFFD1FAE5)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Symbols.description, color: Color(0xFF15803D), size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            approvalLetterName,
                                            style: TextStyle(
                                              fontSize: fontSizeSmall,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF15803D),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Approval letter uploaded',
                                            style: TextStyle(
                                              fontSize: fontSizeSmall - 2,
                                              color: const Color(0xFF15803D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: isLoading ? null : () => clearFile('approvalLetter'),
                                      icon: const Icon(Symbols.close, color: Color(0xFF15803D)),
                                    ),
                                  ],
                                ),
                              )
                                  : InkWell(
                                onTap: isLoading ? null : () => handleFileChange('approvalLetter'),
                                child: Container(
                                  padding: EdgeInsets.all(padding.horizontal),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFD1D5DB),
                                      width: 2,
                                      style: BorderStyle.solid,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Symbols.upload,
                                        color: Color(0xFF6B7280),
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Upload approval/invitation letter',
                                        style: TextStyle(
                                          fontSize: fontSizeSmall,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF374151),
                                        ),
                                      ),
                                      Text(
                                        'if available',
                                        style: TextStyle(
                                          fontSize: fontSizeSmall - 2,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (errors.containsKey('approvalLetter')) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Symbols.warning, color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      errors['approvalLetter']!,
                                      style: TextStyle(
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeSmall - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Symbols.info, color: Color(0xFF6B7280), size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Upload invitation letter, approval document, or event brochure (max 5MB)',
                                      style: TextStyle(
                                        fontSize: fontSizeSmall - 2,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Action Buttons
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    width: isMobile ? screenWidth - padding.horizontal * 4 : (screenWidth - padding.horizontal * 4 - 8) / 2,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : handleCancel,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF374151),
                                        padding: EdgeInsets.symmetric(vertical: fontSizeSmall),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                                        ),
                                        textStyle: TextStyle(
                                          fontSize: fontSizeSmall,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        elevation: 2,
                                        minimumSize: Size(double.infinity, isMobile ? 48 : 56),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Symbols.refresh, size: 16),
                                          SizedBox(width: 8),
                                          Text('Cancel & Reset'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: isMobile ? screenWidth - padding.horizontal * 4 : (screenWidth - padding.horizontal * 4 - 8) / 2,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : handleSubmit,
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(vertical: fontSizeSmall),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        textStyle: TextStyle(
                                          fontSize: fontSizeSmall,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        elevation: 4,
                                        minimumSize: Size(double.infinity, isMobile ? 48 : 56),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isLoading
                                                ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
                                                : [
                                              const Color(0xFF4F46E5),
                                              const Color(0xFF7C3AED),
                                              const Color(0xFF4F46E5),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: fontSizeSmall),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (isLoading)
                                              const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 3,
                                                ),
                                              )
                                            else
                                              const Icon(Symbols.send, color: Colors.white, size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              isLoading ? 'Submitting...' : 'Submit OD Leave',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: fontSizeSmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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
                ),
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}