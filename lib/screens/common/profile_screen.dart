import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UserProfile extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const UserProfile({super.key, this.userData});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> with TickerProviderStateMixin {
  static const String _baseUrl = 'http://192.168.1.33:5000';
  bool isLoading = false;
  String? error;
  String? notification;
  Map<String, dynamic> profileData = {};
  late AnimationController _fadeController;
  late AnimationController _slideController;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600), // Reduced for faster mobile rendering
      vsync: this,
    )..forward();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400), // Reduced for performance
      vsync: this,
    )..forward();
    _loadUserRole();
    fetchProfile();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user');
    if (userData != null) {
      final user = jsonDecode(userData);
      setState(() {
        _userRole = user['role']?.toLowerCase();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> fetchProfile() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token == null) {
        setState(() {
          error = 'Please log in again';
          notification = 'Please log in again';
        });
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          profileData = {
            'employeeId': data['employeeId'] ?? '',
            'title': data['title'] ?? '',
            'firstName': data['firstName'] ?? '',
            'middleName': data['middleName'] ?? '',
            'lastName': data['lastName'] ?? '',
            'email': data['email'] ?? '',
            'gender': data['gender'] ?? '',
            'designation': data['designation'] ?? '',
            'mobile': data['mobile'] ?? '',
            'dateOfBirth': data['dateOfBirth'] ?? '',
            'dateOfJoining': data['dateOfJoining'] ?? '',
            'department': data['department'] ?? '',
            'address': data['address'] ?? '',
            'aadhaar': data['aadhaar'] ?? '',
            'employmentStatus': data['employmentStatus'] ?? 'Probation Period',
            'type': data['type'] ?? '',
            'teachingExperience': data['teachingExperience'] ?? 0,
            'subjectsTaught': data['subjectsTaught'] ?? [],
            'technicalSkills': data['technicalSkills'] ?? [],
            'fathersName': data['fathersName'] ?? '',
            'rfidNo': data['rfidNo'] ?? '',
            'sevarthNo': data['sevarthNo'] ?? '',
            'personalEmail': data['personalEmail'] ?? '',
          };
        });
        await prefs.setString('user', jsonEncode({...jsonDecode(prefs.getString('user') ?? '{}'), ...profileData}));
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          error = 'Failed to fetch profile: ${errorData['message'] ?? response.reasonPhrase}';
          notification = error;
        });
        if (response.statusCode == 401) {
          setState(() => notification = 'Session expired. Please log in again.');
          await prefs.clear();
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      setState(() {
        error = 'Failed to connect to the server. Please check your network or server status.';
        notification = 'Failed to connect to the server';
      });
    } finally {
      setState(() => isLoading = false);
      if (notification != null) {
        await Future.delayed(const Duration(seconds: 3));
        setState(() => notification = null);
      }
    }
  }

  String renderFieldValue(dynamic value, String fieldId) {
    if (fieldId == 'subjectsTaught') {
      return value is List && value.isNotEmpty ? value.map((s) => s['name']).join(', ') : 'Not set';
    }
    if (value is List) {
      return value.isNotEmpty ? value.join(', ') : 'Not set';
    }
    if (fieldId == 'dateOfBirth' || fieldId == 'dateOfJoining') {
      return _formatDate(value);
    }
    return value?.toString() ?? 'Not set';
  }

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return 'Not set';
    try {
      final dateTime = _parseCustomDate(date.toString());
      return DateFormat.yMMMd().format(dateTime);
    } catch (e) {
      return 'Not set';
    }
  }

  DateTime _parseCustomDate(String dateString) {
    // Input format: "Mon Jul 21 2025 05:30:00 GMT+0530 (India Standard Time)"
    // Extract the date and time part: "Jul 21 2025 05:30:00"
    final parts = dateString.split(' ');
    if (parts.length < 6) {
      throw FormatException('Invalid date format: $dateString');
    }
    final datePart = '${parts[1]} ${parts[2]} ${parts[3]} ${parts[4]}';
    // Parse using DateFormat for "MMM dd yyyy HH:mm:ss"
    final formatter = DateFormat('MMM dd yyyy HH:mm:ss');
    return formatter.parse(datePart);
  }

  String getBackRoute() {
    switch (_userRole) {
      case 'principal':
        return '/principal';
      case 'hod':
        return '/hod';
      case 'cc':
        return '/cc_navigation';
      case 'facultymanagement':
      case 'teaching':
        return '/faculty_navigation';
      case 'non-teaching':
        return '/non-teaching';
      case 'driver':
        return '/driver';
      case 'conductor':
        return '/conductor';
      default:
        return '/faculty_navigation'; // Fallback route
    }
  }

  final List<Map<String, dynamic>> profileSections = [
    {
      'id': 'personal',
      'title': 'Personal Details',
      'icon': Symbols.person,
      'fields': [
        {'id': 'employeeId', 'label': 'Employee ID', 'icon': Symbols.security},
        {'id': 'title', 'label': 'Title', 'icon': Symbols.person},
        {'id': 'firstName', 'label': 'First Name', 'icon': Symbols.person},
        {'id': 'middleName', 'label': 'Middle Name', 'icon': Symbols.person},
        {'id': 'lastName', 'label': 'Last Name', 'icon': Symbols.person},
        {'id': 'gender', 'label': 'Gender', 'icon': Symbols.person},
        {'id': 'dateOfBirth', 'label': 'Date of Birth', 'icon': Symbols.calendar_month},
        {'id': 'fathersName', 'label': 'Father\'s Name', 'icon': Symbols.person},
        {'id': 'aadhaar', 'label': 'Aadhaar Number', 'icon': Symbols.description},
        {'id': 'address', 'label': 'Address', 'icon': Symbols.description},
      ],
    },
    {
      'id': 'professional',
      'title': 'Professional Details',
      'icon': Symbols.description,
      'fields': [
        {'id': 'designation', 'label': 'Designation', 'icon': Symbols.description},
        {'id': 'department', 'label': 'Department', 'icon': Symbols.description},
        {'id': 'dateOfJoining', 'label': 'Date of Joining', 'icon': Symbols.calendar_month},
        {'id': 'employmentStatus', 'label': 'Employment Type', 'icon': Symbols.description},
        {'id': 'type', 'label': 'Type', 'icon': Symbols.description},
        {'id': 'teachingExperience', 'label': 'Teaching Experience (Years)', 'icon': Symbols.description},
        {'id': 'subjectsTaught', 'label': 'Subjects Taught', 'icon': Symbols.description},
        {'id': 'technicalSkills', 'label': 'Technical Skills', 'icon': Symbols.description},
      ],
    },
    {
      'id': 'identification',
      'title': 'Identification Details',
      'icon': Symbols.security,
      'fields': [
        {'id': 'rfidNo', 'label': 'RFID Number', 'icon': Symbols.security},
        {'id': 'sevarthNo', 'label': 'Sevarth Number', 'icon': Symbols.description},
      ],
    },
    {
      'id': 'contact',
      'title': 'Contact Information',
      'icon': Symbols.phone,
      'fields': [
        {'id': 'email', 'label': 'Work Email Address', 'icon': Symbols.email},
        {'id': 'personalEmail', 'label': 'Personal Email Address', 'icon': Symbols.email},
        {'id': 'mobile', 'label': 'Mobile Number', 'icon': Symbols.phone},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final double fontScale = isMobile ? 0.9 : 1.0; // Slightly smaller fonts on mobile
    final double paddingScale = isMobile ? 8.0 : 12.0; // Reduced padding on mobile

    if (error != null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFE0F7FA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Container(
              padding: EdgeInsets.all(paddingScale * 1.5),
              margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.error, color: Colors.red, size: 36),
                  SizedBox(height: paddingScale),
                  Text(
                    'Access Error',
                    style: TextStyle(
                      fontSize: 16 * fontScale,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: paddingScale / 2),
                  Text(
                    error!,
                    style: TextStyle(color: Colors.grey, fontSize: 12 * fontScale),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: paddingScale),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: paddingScale * 2, vertical: paddingScale),
                      textStyle: TextStyle(fontSize: 12 * fontScale),
                      minimumSize: const Size(48, 48), // Ensure touch-friendly size
                    ),
                    child: const Text('Go to Login'),
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
          'Profile',
          style: TextStyle(fontSize: 16 * fontScale),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, size: 24), // Increased size for touch
          padding: const EdgeInsets.all(12), // Larger touch target
          onPressed: () => Navigator.pushReplacementNamed(context, getBackRoute()),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFE0F7FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(paddingScale),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    AnimatedBuilder(
                      animation: _fadeController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeController.value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _fadeController.value)),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(paddingScale),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: isMobile ? 48 : 64,
                                  height: isMobile ? 48 : 64,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Colors.indigo, Colors.purple]),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4)],
                                  ),
                                  child: const Icon(Symbols.person, color: Colors.white, size: 28),
                                ),
                                SizedBox(width: paddingScale),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${profileData['title'] ?? ''} ${profileData['firstName'] ?? ''} ${profileData['middleName'] ?? ''} ${profileData['lastName'] ?? ''}'.trim(),
                                        style: TextStyle(
                                          fontSize: 18 * fontScale,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.visible,
                                      ),
                                      SizedBox(height: paddingScale / 2),
                                      Text(
                                        '${profileData['designation'] ?? 'Not set'} • ${profileData['department'] ?? 'Not set'}',
                                        style: TextStyle(fontSize: 12 * fontScale, color: Colors.grey),
                                        maxLines: 2,
                                        overflow: TextOverflow.visible,
                                      ),
                                      SizedBox(height: paddingScale / 2),
                                      Row(
                                        children: [
                                          const Icon(Symbols.calendar_month, size: 14, color: Colors.grey),
                                          SizedBox(width: paddingScale / 2),
                                          Expanded(
                                            child: Text(
                                              renderFieldValue(profileData['dateOfJoining'], 'dateOfJoining'),
                                              style: TextStyle(fontSize: 12 * fontScale, color: Colors.grey),
                                              maxLines: 1,
                                              overflow: TextOverflow.visible,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: paddingScale),
                            Container(
                              padding: EdgeInsets.all(paddingScale * 0.75),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Symbols.email, size: 16, color: Colors.indigo),
                                  SizedBox(width: paddingScale / 2),
                                  Expanded(
                                    child: Text(
                                      profileData['email'] ?? 'Not set',
                                      style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w500, color: Colors.black87),
                                      maxLines: 2,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: paddingScale / 2),
                            Container(
                              padding: EdgeInsets.all(paddingScale * 0.75),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Symbols.phone, size: 16, color: Colors.green),
                                  SizedBox(width: paddingScale / 2),
                                  Expanded(
                                    child: Text(
                                      profileData['mobile'] ?? 'Not set',
                                      style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w500, color: Colors.black87),
                                      maxLines: 2,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: paddingScale),
                            Wrap(
                              spacing: paddingScale / 2,
                              runSpacing: paddingScale / 2,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: paddingScale / 2, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4)],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Symbols.security, size: 14, color: Colors.indigo),
                                      SizedBox(width: paddingScale / 2),
                                      Flexible(
                                        child: Text(
                                          'ID: ${profileData['employeeId'] ?? 'Not set'}',
                                          style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: paddingScale / 2, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4)],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Symbols.description, size: 14, color: Colors.purple),
                                      SizedBox(width: paddingScale / 2),
                                      Flexible(
                                        child: Text(
                                          'Experience: ${profileData['teachingExperience'] ?? 0} years',
                                          style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: paddingScale / 2, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4)],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Symbols.person, size: 14, color: Colors.green),
                                      SizedBox(width: paddingScale / 2),
                                      Flexible(
                                        child: Text(
                                          'Status: ${profileData['employmentStatus'] ?? 'Not set'}',
                                          style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600, color: Colors.black87),
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
                    SizedBox(height: paddingScale),

                    // Profile Sections
                    ...profileSections.asMap().entries.map((entry) {
                      final index = entry.key;
                      final section = entry.value;
                      return AnimatedBuilder(
                        animation: _slideController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(-20 * (1 - _slideController.value), 0),
                            child: Opacity(
                              opacity: _slideController.value,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: paddingScale),
                          padding: EdgeInsets.all(paddingScale),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: isMobile ? 32 : 40,
                                    height: isMobile ? 32 : 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Colors.indigo, Colors.purple]),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4)],
                                    ),
                                    child: Icon(section['icon'] as IconData, color: Colors.white, size: isMobile ? 16 : 20),
                                  ),
                                  SizedBox(width: paddingScale / 2),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        section['title'] as String,
                                        style: TextStyle(
                                          fontSize: 16 * fontScale,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '${(section['fields'] as List?)?.length ?? 0} field${(section['fields'] as List?)?.length != 1 ? 's' : ''} available',
                                        style: TextStyle(fontSize: 10 * fontScale, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: paddingScale / 2),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: (section['fields'] as List?)?.length ?? 0,
                                itemBuilder: (context, fieldIndex) {
                                  final field = (section['fields'] as List)[fieldIndex];
                                  return Container(
                                    margin: EdgeInsets.only(bottom: paddingScale / 2),
                                    padding: EdgeInsets.all(paddingScale * 0.75),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: isMobile ? 28 : 32,
                                          height: isMobile ? 28 : 32,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(field['icon'] as IconData, size: isMobile ? 14 : 16, color: Colors.indigo),
                                        ),
                                        SizedBox(width: paddingScale / 2),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                field['label'] as String,
                                                style: TextStyle(
                                                  fontSize: 12 * fontScale,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              SizedBox(height: paddingScale / 4),
                                              Text(
                                                renderFieldValue(profileData[field['id']], field['id']),
                                                style: TextStyle(
                                                  fontSize: 12 * fontScale,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.visible,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).animate().fadeIn(delay: Duration(milliseconds: (index * 100) + (fieldIndex * 50)));
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(paddingScale * 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SpinKitCircle(color: Colors.indigo, size: 36),
                      SizedBox(height: paddingScale),
                      Text(
                        'Loading Profile...',
                        style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (notification != null)
            Positioned(
              top: paddingScale,
              right: paddingScale,
              child: Container(
                padding: EdgeInsets.all(paddingScale),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: paddingScale / 2),
                    Text(
                      notification!,
                      style: TextStyle(fontSize: 12 * fontScale, fontWeight: FontWeight.w500, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ).animate().fadeIn().then().fadeOut(delay: const Duration(seconds: 3)),
            ),
        ],
      ),
    );
  }
}