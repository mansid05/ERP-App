import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

class ApplyChargeHandoverScreen extends StatefulWidget {
  const ApplyChargeHandoverScreen({super.key});

  @override
  _ApplyChargeHandoverScreenState createState() => _ApplyChargeHandoverScreenState();
}

class _ApplyChargeHandoverScreenState extends State<ApplyChargeHandoverScreen> {
  static const String _baseUrl = 'http://192.168.1.33:5000'; // Match React's localhost:5000 if needed
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> formData = {
    'employeeName': '',
    'employeeId': '',
    'designation': '',
    'department': '',
    'handoverStartDate': '',
    'handoverEndDate': '',
    'handoverReason': '',
    'receiverName': '',
    'receiverDesignation': '',
    'receiverDepartment': '',
    'receiverEmployeeId': '',
    'documents': [],
    'assets': [],
    'pendingTasks': [],
    'remarks': '',
    'status': 'pending_hod',
  };
  String tempItem = '';
  String itemType = 'documents';
  bool isSubmitting = false;
  String? error;
  bool success = false;
  bool isLoading = false;
  List<Map<String, dynamic>> facultyList = [];
  String receiverId = '';
  Map<String, dynamic>? selectedReceiver;
  Map<String, dynamic>? userData;

  final handoverReasons = [
    {'value': '', 'label': 'Select reason for handover'},
    {'value': 'Transfer', 'label': '🔄 Transfer'},
    {'value': 'Resignation', 'label': '📤 Resignation'},
    {'value': 'Leave', 'label': '🏖️ Leave'},
    {'value': 'Promotion', 'label': '⬆️ Promotion'},
    {'value': 'Other', 'label': '➕ Other'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    await _fetchUserProfile();
    await _fetchFacultyList();
    setState(() => isLoading = false);
  }

  Future<void> _fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user');
      String? token = prefs.getString('authToken');

      // Fallback to token in user data, like React
      if (userDataString != null) {
        final storedUserData = jsonDecode(userDataString);
        token ??= storedUserData['token']?.toString();
        setState(() {
          userData = storedUserData;
          formData['employeeName'] = _constructFullName(storedUserData);
          formData['employeeId'] = storedUserData['employeeId']?.toString() ?? '';
          formData['designation'] = storedUserData['designation']?.toString() ?? '';
          formData['department'] = storedUserData['department']?.toString() ?? '';
        });
        debugPrint('Stored user data: $storedUserData');
        debugPrint('Initial employeeName: ${formData['employeeName']}');
      }

      if (userDataString == null || token == null) {
        setState(() {
          error = '❌ Please log in to continue';
        });
        debugPrint('No user data or token found in SharedPreferences');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Profile API response status: ${response.statusCode}');
      debugPrint('Profile API response body: ${response.body}');

      if (response.statusCode == 200) {
        final profileData = jsonDecode(response.body);
        setState(() {
          userData = {...userData ?? {}, ...profileData, 'token': token};
          formData['employeeName'] = _constructFullName(profileData);
          formData['employeeId'] = profileData['employeeId']?.toString() ?? formData['employeeId'];
          formData['designation'] = profileData['designation']?.toString() ?? formData['designation'];
          formData['department'] = profileData['department']?.toString() ?? formData['department'];
        });
        await prefs.setString('user', jsonEncode(userData));
        debugPrint('Updated user data: $userData');
        debugPrint('Updated employeeName: ${formData['employeeName']}');
        if (formData['employeeName'].isEmpty) {
          setState(() {
            error = '❌ Employee name could not be retrieved from profile';
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          error = '❌ ${errorData['message'] ?? 'Failed to fetch user profile'}';
        });
        if (response.statusCode == 401) {
          await prefs.clear();
          debugPrint('Unauthorized: Clearing SharedPreferences and redirecting to login');
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      }
    } catch (err) {
      setState(() {
        error = '❌ Failed to connect to the server: ${err.toString()}';
      });
      debugPrint('Error fetching user profile: $err');
    }
  }

  String _constructFullName(Map<String, dynamic> data) {
    // Align with React: prioritize 'name', then firstName + lastName
    final name = data['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final firstName = data['firstName']?.toString().trim() ?? '';
    final lastName = data['lastName']?.toString().trim() ?? '';
    return (firstName + (lastName.isNotEmpty ? ' $lastName' : '')).trim();
  }

  Future<void> _fetchFacultyList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken') ?? userData?['token']?.toString();
      if (token == null) {
        setState(() {
          error = '❌ Authentication token not found for faculty list';
        });
        return;
      }
      final response = await http.get(
        Uri.parse('$_baseUrl/api/faculty/faculties?limit=1000'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          facultyList = List<Map<String, dynamic>>.from(data['data']?['faculties'] ?? []);
        });
        debugPrint('Fetched faculty list: ${facultyList.length} items');
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          error = '❌ ${errorData['message'] ?? 'Failed to fetch faculty list'}';
        });
        debugPrint('Faculty list fetch failed: ${response.statusCode}, ${response.body}');
      }
    } catch (err) {
      setState(() {
        error = '❌ Failed to fetch faculty list: ${err.toString()}';
      });
      debugPrint('Error fetching faculty list: $err');
    }
  }

  void _handleChange(String key, String value) {
    setState(() {
      formData[key] = value;
    });
  }

  void _handleAddItem() {
    if (tempItem.trim().isNotEmpty) {
      setState(() {
        formData[itemType] = [...formData[itemType], tempItem.trim()];
        tempItem = '';
      });
    }
  }

  void _handleRemoveItem(int index) {
    setState(() {
      formData[itemType] = List.from(formData[itemType])..removeAt(index);
    });
  }

  DateTime _parseCustomDate(String dateString) {
    try {
      if (dateString.isEmpty) throw FormatException('Empty date string');
      try {
        return DateTime.parse(dateString);
      } catch (_) {
        final parts = dateString.split(' ');
        if (parts.length >= 6) {
          final datePart = '${parts[1]} ${parts[2]} ${parts[3]} ${parts[4]}';
          final formatter = DateFormat('MMM dd yyyy HH:mm:ss');
          return formatter.parse(datePart);
        }
        throw FormatException('Invalid date format: $dateString');
      }
    } catch (e) {
      throw FormatException('Invalid date format: $dateString');
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final dateTime = _parseCustomDate(dateString);
      return DateFormat('yyyy-MM-dd').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        error = '❌ Please fill all required fields correctly';
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      error = null;
      success = false;
    });

    try {
      if (formData['employeeName'].isEmpty ||
          formData['employeeId'].isEmpty ||
          formData['designation'].isEmpty ||
          formData['department'].isEmpty ||
          formData['handoverStartDate'].isEmpty ||
          formData['handoverEndDate'].isEmpty ||
          formData['handoverReason'].isEmpty ||
          formData['receiverDesignation'].isEmpty) {
        throw Exception('Please fill all required fields');
      }

      final startDate = _parseCustomDate(formData['handoverStartDate']);
      final endDate = _parseCustomDate(formData['handoverEndDate']);
      if (startDate.isAfter(endDate)) {
        throw Exception('End date must be after start date');
      }

      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user');
      final token = prefs.getString('authToken') ?? userData?['token']?.toString();
      if (userDataString == null || token == null) {
        throw Exception('Authentication token not found. Please log in again.');
      }

      final user = jsonDecode(userDataString);
      final senderId = user['_id'] ?? user['id'];
      final receiverName = selectedReceiver != null
          ? (selectedReceiver!['name']?.trim() ?? _constructFullName(selectedReceiver!))
          : formData['receiverName'];

      final payload = {
        ...formData,
        'senderId': senderId,
        'receiverName': receiverName,
        'receiverId': receiverId,
        'reason': formData['handoverReason'],
        'handoverStartDate': DateFormat('yyyy-MM-dd').format(startDate),
        'handoverEndDate': DateFormat('yyyy-MM-dd').format(endDate),
        'reportingManager': formData['employeeName'],
      }..remove('handoverReason');

      debugPrint('Payload being submitted: $payload');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        setState(() {
          success = true;
          error = null;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard/approveChargeHandover');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Submission failed');
      }
    } catch (err) {
      setState(() {
        error = '❌ ${err.toString().replaceFirst('Exception: ', '')}';
      });
      if (err.toString().contains('401')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        debugPrint('Unauthorized: Clearing SharedPreferences and redirecting to login');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  String _formatItemType(String itemType) {
    if (itemType.isEmpty) return 'items';
    return itemType.replaceAllMapped(
      RegExp(r'([A-Z])'),
          (match) => ' ${match[1]?.toLowerCase() ?? ''}',
    ).trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final padding = EdgeInsets.symmetric(
      horizontal: isMobile ? 16.0 : 24.0,
      vertical: isMobile ? 16.0 : 24.0,
    );
    final fontSizeLarge = isMobile ? 20.0 : 28.0;
    final fontSizeMedium = isMobile ? 14.0 : 16.0;
    final fontSizeSmall = isMobile ? 12.0 : 14.0;
    final fontSizeXSmall = isMobile ? 10.0 : 12.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Apply Charge Handover',
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
                          'Charge Handover Application',
                          style: TextStyle(
                            fontSize: fontSizeLarge,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Submit your charge handover request for approval',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSizeMedium,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Form Card
                  Container(
                    padding: EdgeInsets.all(padding.horizontal),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Symbols.description,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Charge Handover Form',
                                    style: TextStyle(
                                      fontSize: fontSizeMedium,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Message
                          if (error != null || success) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(padding.horizontal),
                              decoration: BoxDecoration(
                                color: error != null ? Colors.red[50] : Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: error != null ? Colors.red[200]! : Colors.green[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    error != null ? '❌' : '✅',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      error ?? 'Form submitted successfully! Redirecting...',
                                      style: TextStyle(
                                        fontSize: fontSizeSmall,
                                        color: error != null ? Colors.red[800] : Colors.green[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Basic Details
                          const SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(padding.horizontal),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Symbols.person,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Basic Details',
                                      style: TextStyle(
                                        fontSize: fontSizeMedium,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildReadOnlyField(
                                      label: '👤 Employee Name',
                                      value: formData['employeeName'],
                                      fontSize: fontSizeSmall,
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      padding: padding,
                                    ),
                                    _buildReadOnlyField(
                                      label: '🆔 Employee ID',
                                      value: formData['employeeId'],
                                      fontSize: fontSizeSmall,
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      padding: padding,
                                    ),
                                    _buildReadOnlyField(
                                      label: '💼 Designation',
                                      value: formData['designation'],
                                      fontSize: fontSizeSmall,
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      padding: padding,
                                    ),
                                    _buildReadOnlyField(
                                      label: '🏢 Department',
                                      value: formData['department'],
                                      fontSize: fontSizeSmall,
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      padding: padding,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Handover Details
                          const SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(padding.horizontal),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF6D28D9), Color(0xFFDB2777)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Symbols.calendar_month,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Handover Details',
                                      style: TextStyle(
                                        fontSize: fontSizeMedium,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
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
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      child: TextFormField(
                                        decoration: InputDecoration(
                                          labelText: '📅 Start Date',
                                          prefixIcon: const Icon(Symbols.calendar_month, color: Color(0xFF6B7280)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          labelStyle: TextStyle(fontSize: fontSizeSmall),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                        ),
                                        enabled: !isSubmitting,
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
                                                    primary: Color(0xFF6D28D9),
                                                    onPrimary: Colors.white,
                                                    surface: Colors.white,
                                                  ),
                                                  textButtonTheme: TextButtonThemeData(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Color(0xFF6D28D9),
                                                    ),
                                                  ),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );
                                          if (picked != null) {
                                            setState(() {
                                              formData['handoverStartDate'] = DateFormat('yyyy-MM-dd').format(picked);
                                            });
                                          }
                                        },
                                        controller: TextEditingController(
                                          text: _formatDate(formData['handoverStartDate']),
                                        ),
                                        style: TextStyle(fontSize: fontSizeSmall),
                                        validator: (value) => value!.isEmpty ? 'Start date is required' : null,
                                      ),
                                    ),
                                    Container(
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      child: TextFormField(
                                        decoration: InputDecoration(
                                          labelText: '📅 End Date',
                                          prefixIcon: const Icon(Symbols.calendar_month, color: Color(0xFF6B7280)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          labelStyle: TextStyle(fontSize: fontSizeSmall),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                        ),
                                        enabled: !isSubmitting,
                                        readOnly: true,
                                        onTap: () async {
                                          final initialDate = formData['handoverStartDate'].isNotEmpty
                                              ? _parseCustomDate(formData['handoverStartDate'])
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
                                                    primary: Color(0xFF6D28D9),
                                                    onPrimary: Colors.white,
                                                    surface: Colors.white,
                                                  ),
                                                  textButtonTheme: TextButtonThemeData(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Color(0xFF6D28D9),
                                                    ),
                                                  ),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );
                                          if (picked != null) {
                                            setState(() {
                                              formData['handoverEndDate'] = DateFormat('yyyy-MM-dd').format(picked);
                                            });
                                          }
                                        },
                                        controller: TextEditingController(
                                          text: _formatDate(formData['handoverEndDate']),
                                        ),
                                        style: TextStyle(fontSize: fontSizeSmall),
                                        validator: (value) => value!.isEmpty ? 'End date is required' : null,
                                      ),
                                    ),
                                    Container(
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      child: DropdownButtonFormField<String>(
                                        value: formData['handoverReason'].isEmpty ? null : formData['handoverReason'],
                                        decoration: InputDecoration(
                                          labelText: '🔄 Reason for Handover',
                                          prefixIcon: const Icon(Symbols.swap_horiz, color: Color(0xFF6B7280)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          labelStyle: TextStyle(fontSize: fontSizeSmall),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                        ),
                                        items: handoverReasons.map((reason) {
                                          return DropdownMenuItem(
                                            value: reason['value'],
                                            child: Text(
                                              reason['label']!,
                                              style: TextStyle(fontSize: fontSizeSmall),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: isSubmitting
                                            ? null
                                            : (value) => setState(() => formData['handoverReason'] = value!),
                                        validator: (value) => value == null || value.isEmpty ? 'Reason is required' : null,
                                        hint: Text(
                                          'Select reason for handover',
                                          style: TextStyle(fontSize: fontSizeSmall),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      child: DropdownButtonFormField<String>(
                                        value: receiverId.isEmpty ? null : receiverId,
                                        decoration: InputDecoration(
                                          labelText: '👤 Select Receiver',
                                          prefixIcon: const Icon(Symbols.person, color: Color(0xFF6B7280)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          labelStyle: TextStyle(fontSize: fontSizeSmall),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                        ),
                                        items: facultyList.map((faculty) {
                                          if (faculty['_id'] == null) return null;
                                          final name = _constructFullName(faculty);
                                          final designation = faculty['designation']?.toString() ?? 'Unknown';
                                          return DropdownMenuItem<String>(
                                            value: faculty['_id'] as String,
                                            child: Container(
                                              constraints: BoxConstraints(maxWidth: isMobile ? screenWidth - 80 : (screenWidth - 80) / 2), // Adjusted maxWidth
                                              child: Text(
                                                name.isEmpty ? 'Unnamed Faculty - $designation' : '$name - $designation',
                                                style: TextStyle(fontSize: fontSizeSmall),
                                                overflow: TextOverflow.ellipsis, // Truncate long text
                                                maxLines: 1,
                                              ),
                                            ),
                                          );
                                        }).whereType<DropdownMenuItem<String>>().toList(),
                                        onChanged: isSubmitting
                                            ? null
                                            : (value) async {
                                          setState(() => receiverId = value!);
                                          if (value != null && value.isNotEmpty) {
                                            final prefs = await SharedPreferences.getInstance();
                                            final token = prefs.getString('authToken') ?? userData?['token']?.toString();
                                            if (token == null) {
                                              setState(() {
                                                error = '❌ Authentication token not found for faculty fetch';
                                              });
                                              return;
                                            }
                                            final response = await http.get(
                                              Uri.parse('$_baseUrl/api/faculty/faculties?facultyId=$value'),
                                              headers: {
                                                'Content-Type': 'application/json',
                                                'Authorization': 'Bearer $token',
                                              },
                                            );
                                            if (response.statusCode == 200) {
                                              final data = jsonDecode(response.body);
                                              final faculty = List<Map<String, dynamic>>.from(data['data']?['faculties'] ?? []).first;
                                              setState(() {
                                                selectedReceiver = faculty;
                                                formData['receiverName'] = _constructFullName(faculty);
                                                formData['receiverDesignation'] = faculty['designation']?.toString() ?? '';
                                                formData['receiverDepartment'] = faculty['department']?.toString() ?? '';
                                                formData['receiverEmployeeId'] = faculty['employeeId']?.toString() ?? '';
                                              });
                                            } else {
                                              setState(() {
                                                selectedReceiver = null;
                                                formData['receiverName'] = '';
                                                formData['receiverDesignation'] = '';
                                                formData['receiverDepartment'] = '';
                                                formData['receiverEmployeeId'] = '';
                                              });
                                            }
                                          } else {
                                            setState(() {
                                              selectedReceiver = null;
                                              formData['receiverName'] = '';
                                              formData['receiverDesignation'] = '';
                                              formData['receiverDepartment'] = '';
                                              formData['receiverEmployeeId'] = '';
                                            });
                                          }
                                        },
                                        validator: (value) => value == null || value.isEmpty ? 'Receiver is required' : null,
                                        hint: Text(
                                          'Choose who will receive the charge',
                                          style: TextStyle(fontSize: fontSizeSmall),
                                          overflow: TextOverflow.ellipsis, // Ensure hint text doesn't overflow
                                        ),
                                        isExpanded: true, // Makes dropdown take full width of container
                                        menuMaxHeight: 300, // Limit dropdown menu height
                                      ),
                                    ),
                                    _buildReadOnlyField(
                                      label: '👤 Receiver\'s Name',
                                      value: formData['receiverName'],
                                      fontSize: fontSizeSmall,
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      padding: padding,
                                    ),
                                    _buildReadOnlyField(
                                      label: '💼 Receiver\'s Designation',
                                      value: formData['receiverDesignation'],
                                      fontSize: fontSizeSmall,
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      padding: padding,
                                    ),
                                    _buildReadOnlyField(
                                      label: '🏢 Receiver\'s Department',
                                      value: formData['receiverDepartment'],
                                      fontSize: fontSizeSmall,
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      padding: padding,
                                    ),
                                    _buildReadOnlyField(
                                      label: '🆔 Receiver\'s Employee ID',
                                      value: formData['receiverEmployeeId'],
                                      fontSize: fontSizeSmall,
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      padding: padding,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Assets & Responsibilities
                          const SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(padding.horizontal),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Symbols.inventory,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Assets & Responsibilities',
                                      style: TextStyle(
                                        fontSize: fontSizeMedium,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
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
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      child: DropdownButtonFormField<String>(
                                        value: itemType,
                                        decoration: InputDecoration(
                                          labelText: '📝 Category',
                                          prefixIcon: const Icon(Symbols.category, color: Color(0xFF6B7280)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          labelStyle: TextStyle(fontSize: fontSizeSmall),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'documents', child: Text('📄 Documents')),
                                          DropdownMenuItem(value: 'assets', child: Text('💎 Assets')),
                                          DropdownMenuItem(value: 'pendingTasks', child: Text('⏰ Pending Tasks')),
                                        ],
                                        onChanged: isSubmitting
                                            ? null
                                            : (value) => setState(() => itemType = value!),
                                        style: TextStyle(fontSize: fontSizeSmall),
                                      ),
                                    ),
                                    Container(
                                      width: isMobile ? screenWidth - padding.horizontal * 2 : (screenWidth - padding.horizontal * 2 - 8) / 2,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              decoration: InputDecoration(
                                                labelText: '✍️ Add Item',
                                                prefixIcon: const Icon(Symbols.add, color: Color(0xFF6B7280)),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                hintText: 'Enter ${_formatItemType(itemType)}...',
                                                hintStyle: TextStyle(fontSize: fontSizeSmall),
                                                labelStyle: TextStyle(fontSize: fontSizeSmall),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                              ),
                                              enabled: !isSubmitting,
                                              onChanged: (value) => setState(() => tempItem = value),
                                              onFieldSubmitted: (_) => _handleAddItem(),
                                              controller: TextEditingController(text: tempItem),
                                              style: TextStyle(fontSize: fontSizeSmall),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: isSubmitting ? null : _handleAddItem,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF10B981),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              minimumSize: const Size(40, 40),
                                            ),
                                            child: const Icon(Symbols.add, size: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: EdgeInsets.all(padding.horizontal),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            itemType == 'documents'
                                                ? '📄 Documents'
                                                : itemType == 'assets'
                                                ? '💎 Assets'
                                                : '⏰ Pending Tasks',
                                            style: TextStyle(
                                              fontSize: fontSizeMedium,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${formData[itemType].length} items',
                                              style: TextStyle(
                                                fontSize: fontSizeXSmall,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      formData[itemType].isNotEmpty
                                          ? SizedBox(
                                        height: 150,
                                        child: ListView.builder(
                                          itemCount: formData[itemType].length,
                                          itemBuilder: (context, index) {
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey[200]!),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      formData[itemType][index],
                                                      style: TextStyle(
                                                        fontSize: fontSizeXSmall,
                                                        color: Colors.grey[700],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: isSubmitting ? null : () => _handleRemoveItem(index),
                                                    icon: const Icon(
                                                      Symbols.delete,
                                                      color: Color(0xFFEF4444),
                                                      size: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                          : Container(
                                        padding: const EdgeInsets.symmetric(vertical: 24),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Symbols.inventory,
                                              color: Colors.grey,
                                              size: 32,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'No ${_formatItemType(itemType)} added yet',
                                              style: TextStyle(
                                                fontSize: fontSizeXSmall,
                                                color: Colors.grey[400],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            Text(
                                              'Add items using the form above',
                                              style: TextStyle(
                                                fontSize: fontSizeXSmall - 2,
                                                color: Colors.grey[400],
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
                          // Remarks
                          const SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(padding.horizontal),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Symbols.comment,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Additional Remarks',
                                      style: TextStyle(
                                        fontSize: fontSizeMedium,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  decoration: InputDecoration(
                                    labelText: '💬 Comments & Instructions',
                                    prefixIcon: const Icon(Symbols.description, color: Color(0xFF6B7280)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: 'Provide any additional information or instructions...',
                                    hintStyle: TextStyle(fontSize: fontSizeSmall),
                                    labelStyle: TextStyle(fontSize: fontSizeSmall),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSizeSmall),
                                  ),
                                  enabled: !isSubmitting,
                                  onChanged: (value) => setState(() => formData['remarks'] = value),
                                  maxLines: 4,
                                  style: TextStyle(fontSize: fontSizeSmall),
                                ),
                              ],
                            ),
                          ),
                          // Submit Button
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed: isSubmitting ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: fontSizeSmall),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                minimumSize: Size(isMobile ? screenWidth - padding.horizontal * 2 : 300, 48),
                                elevation: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSubmitting)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    const Icon(Symbols.check_circle, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    isSubmitting ? 'Submitting...' : 'Submit Request',
                                    style: TextStyle(
                                      fontSize: fontSizeSmall,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Loading Overlay
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading profile...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required double fontSize,
    required double width,
    required EdgeInsets padding,
  }) {
    return Container(
      width: width,
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: label.contains('Name')
              ? const Icon(Symbols.person, color: Color(0xFF6B7280), size: 16)
              : label.contains('ID')
              ? const Icon(Symbols.badge, color: Color(0xFF6B7280), size: 16)
              : label.contains('Designation')
              ? const Icon(Symbols.work, color: Color(0xFF6B7280), size: 16)
              : const Icon(Symbols.business, color: Color(0xFF6B7280), size: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          filled: true,
          fillColor: Colors.grey[100],
          labelStyle: TextStyle(fontSize: fontSize),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: fontSize),
        ),
        readOnly: true,
        controller: TextEditingController(text: value),
        style: TextStyle(fontSize: fontSize),
      ),
    );
  }
}