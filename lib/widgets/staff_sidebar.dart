import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../auth/login_screen.dart';
import '../services/api_service.dart'; // Import ApiService for API calls
import '../utils/role_permissions_and_routes.dart'; // Import role permissions

class StaffSidebar extends StatefulWidget {
  final bool isOpen;
  final Function(Map<String, dynamic>) handleMenuClick;
  final Map<String, dynamic> userData;
  final VoidCallback onClose;

  const StaffSidebar({
    super.key,
    required this.isOpen,
    required this.handleMenuClick,
    required this.userData,
    required this.onClose,
  });

  @override
  _StaffSidebarState createState() => _StaffSidebarState();
}

class _StaffSidebarState extends State<StaffSidebar> {
  bool _isCC = false;
  bool _loadingCCStatus = true;

  @override
  void initState() {
    super.initState();
    _checkCCStatus();
  }

  Future<void> _checkCCStatus() async {
    if (widget.userData['role'] != 'teaching') {
      setState(() {
        _isCC = false;
        _loadingCCStatus = false;
      });
      return;
    }

    try {
      final department = widget.userData['department']?.toLowerCase().replaceFirst(RegExp(r'^\w'), (match) => match.group(0)!.toUpperCase()) ?? '';
      final facultyId = widget.userData['_id'];

      if (facultyId == null || department.isEmpty) {
        debugPrint('[SidebarCCStatus] Missing facultyId or department');
        setState(() => _loadingCCStatus = false);
        return;
      }

      debugPrint('[SidebarCCStatus] Fetching for: facultyId=$facultyId, department=$department');
      final response = await ApiService.get('/api/faculty/cc-assignments?department=$department');
      if (response.statusCode != 200) {
        debugPrint('[SidebarCCStatus] API error: ${response.statusCode}');
        setState(() => _loadingCCStatus = false);
        return;
      }

      final data = json.decode(response.body);
      debugPrint('[SidebarCCStatus] API response: $data');
      final assignments = (data['data'] as List<dynamic>?)?.where((cc) => cc['facultyId'] == facultyId).toList() ?? [];
      setState(() {
        _isCC = assignments.isNotEmpty;
        _loadingCCStatus = false;
      });
      debugPrint('[SidebarCCStatus] Is CC: ${assignments.isNotEmpty}');
    } catch (err) {
      debugPrint('[SidebarCCStatus] Error: $err');
      setState(() => _loadingCCStatus = false);
    }
  }

  Map<String, String> get _roleDisplayNames => {
    'director': 'Director',
    'principal': 'Principal',
    'HOD': 'Head of Department',
    'hod': 'Head of Department',
    'teaching': 'Teacher',
    'nonteaching': 'Non-Teaching Staff',
    'non-teaching': 'Non-Teaching Staff',
    'facultymanagement': 'Faculty Management',
    'cc': 'Course Coordinator',
  };

  String _getAnnouncementRoute(String? role) {
    switch (role?.toLowerCase()) {
      case 'hod':
        return '/dashboard/compose-hod-announcement';
      case 'principal':
        return '/dashboard/compose-principal-announcement';
      case 'nonteaching':
      case 'non-teaching':
        return '/dashboard/announcementnonteaching';
      default:
        return '/dashboard/announcement';
    }
  }

  String _getApproveLeaveRoute(String? role) {
    if (role?.toLowerCase() == 'principal') return '/dashboard/approveleavebyprincipal';
    return '/dashboard/approveleave';
  }

  String _getAnnouncementTitle(String? role) {
    if (['hod', 'principal'].contains(role?.toLowerCase())) return 'Compose Announcement';
    return 'Announcements';
  }

  String _getDashboardRoute(String? role) {
    switch (role?.toLowerCase()) {
      case 'hod':
        return '/hod-dashboard';
      case 'principal':
        return '/principal-dashboard';
      case 'cc':
        return '/cc-dashboard';
      default:
        return '/dashboard';
    }
  }

  String _getAllStaffRoute(String? role) {
    if (role?.toLowerCase() == 'hod') return '/dashboard/departmentfaculty';
    return '/dashboard/allstaff';
  }

  List<Map<String, dynamic>> _getMenuItems() {
    final role = widget.userData['role']?.toLowerCase();
    return [
      // Dashboard Section
      {
        'title': 'Dashboard',
        'icon': Icons.home,
        'href': _getDashboardRoute(role),
        'routeName': role == 'cc' ? 'cc_dashboard' : 'dashboard',
        'isSection': true,
        'sectionTitle': 'Main',
      },
      // Personal Section
      {
        'title': 'Profile',
        'icon': Icons.person,
        'href': '/dashboard/profile',
        'routeName': 'profile',
        'isSection': true,
        'sectionTitle': 'Personal',
      },
      {
        'title': 'Pay Slip',
        'icon': Icons.credit_card,
        'href': '/dashboard/payslip',
        'routeName': 'payslip',
      },
      // Staff Management Section
      ...(role == 'hod'
          ? [
        {
          'title': 'Department Faculty',
          'icon': Icons.group,
          'href': '/dashboard/departmentfaculty',
          'routeName': 'all_staff',
          'isSection': true,
          'sectionTitle': 'Staff Management',
        },
        {
          'title': 'Department Students',
          'icon': Icons.group,
          'href': '/dashboard/department-students',
          'routeName': 'department_students',
        },
        {
          'title': 'Academic Calendar',
          'icon': Icons.calendar_today,
          'href': '/dashboard/academic-calendar',
          'routeName': 'academic_calendar',
        },
      ]
          : [
        {
          'title': 'All Staff',
          'icon': Icons.book,
          'href': _getAllStaffRoute(role),
          'routeName': 'all_staff',
          'isSection': true,
          'sectionTitle': 'Staff Management',
        },
        {
          'title': 'Department Students',
          'icon': Icons.group,
          'href': '/dashboard/department-students',
          'routeName': 'department_students',
        },
      ]),
      // Communication Section
      {
        'title': _getAnnouncementTitle(role),
        'icon': Icons.announcement,
        'href': _getAnnouncementRoute(role),
        'routeName': role == 'hod'
            ? 'compose_hod_announcement'
            : role == 'principal'
            ? 'compose_principal_announcement'
            : role == 'nonteaching' || role == 'non-teaching'
            ? 'announcement_nonteaching'
            : 'announcement',
        'isSection': true,
        'sectionTitle': 'Communication',
      },
      // Student Feedback for HOD
      ...(role == 'hod'
          ? [
        {
          'title': 'Student Feedback',
          'icon': Icons.feedback,
          'href': '/dashboard/student-feedback',
          'routeName': 'student_feedback',
        },
      ]
          : []),
      // Academic Management Section
      {
        'title': 'Fetched Timetable',
        'icon': Icons.calendar_today,
        'href': '/dashboard/fetched-timetable',
        'routeName': 'fetched_timetable',
        'isSection': true,
        'sectionTitle': 'Academic Management',
      },
      {
        'title': 'Timetable',
        'icon': Icons.schedule,
        'href': '/dashboard/timetable',
        'routeName': 'timetable',
      },
      {
        'title': 'Mark Attendance',
        'icon': Icons.person,
        'href': '/dashboard/markattendance',
        'routeName': 'mark_attendance',
      },
      // Leave Management Section
      {
        'title': 'Apply Leave',
        'icon': Icons.description,
        'href': '/dashboard/applyleave',
        'routeName': 'apply_leave',
        'isSection': true,
        'sectionTitle': 'Leave Management',
      },
      ...(role == 'principal'
          ? [
        {
          'title': 'Approve Leave',
          'icon': Icons.checklist,
          'href': '/dashboard/approveleavebyprincipal',
          'routeName': 'approve_leave',
        },
        {
          'title': 'Approve OD Leave',
          'icon': Icons.checklist,
          'href': '/dashboard/approveodleave',
          'routeName': 'approve_od_leave',
        },
      ]
          : []),
      ...(role == 'hod'
          ? [
        {
          'title': 'Approve Leave',
          'icon': Icons.checklist,
          'href': '/dashboard/approveleave',
          'routeName': 'approve_leave',
        },
        {
          'title': 'Approve OD Leave',
          'icon': Icons.checklist,
          'href': '/dashboard/approveodleave',
          'routeName': 'approve_od_leave',
        },
      ]
          : []),
      {
        'title': 'Apply OD Leave',
        'icon': Icons.description,
        'href': '/dashboard/applyodleave',
        'routeName': 'apply_od_leave',
      },
      // Handover Management Section
      {
        'title': 'Apply Charge Handover',
        'icon': Icons.folder_open,
        'href': '/dashboard/applyChargeHandover',
        'routeName': 'apply_charge_handover',
        'isSection': true,
        'sectionTitle': 'Handover Management',
      },
      {
        'title': 'Approve Charge Handover',
        'icon': Icons.checklist,
        'href': '/dashboard/approveChargeHandover',
        'routeName': 'approve_charge_handover',
      },
      {
        'title': 'Sent Charge Handover',
        'icon': Icons.access_time,
        'href': '/dashboard/sentChargeHandover',
        'routeName': 'sent_charge_handover',
      },
      // Documents Section
      {
        'title': 'Notes & Documents',
        'icon': Icons.description,
        'href': '/dashboard/files',
        'routeName': 'files',
        'isSection': true,
        'sectionTitle': 'Documents',
      },
      // Additional CC functionality for teaching staff with CC assignments
      ...(_isCC && role == 'teaching'
          ? [
        {
          'title': 'CC Functions',
          'icon': Icons.star,
          'href': '/cc-dashboard/${widget.userData['_id']}',
          'routeName': 'cc_dashboard',
          'isSection': true,
          'sectionTitle': 'Additional Functions',
        },
      ]
          : []),
      ...(role == 'cc'
          ? [
        {
          'title': 'Class Students',
          'icon': Icons.group,
          'href': '/cc-class-students',
          'routeName': 'cc_class_students',
          'isSection': true,
          'sectionTitle': 'Class Management',
        },
      ]
          : []),
    ];
  }

  Map<String, List<String>> get _rolePermissions {
    return rolePermissionsAndRoutes.fold<Map<String, List<String>>>({}, (acc, role) {
      acc[role['role']] = role['permissions'];
      return acc;
    });
  }

  List<Map<String, dynamic>> get _filteredMenuItems {
    final role = widget.userData['role']?.toLowerCase();
    return _getMenuItems().where((item) {
      final permissions = _rolePermissions[role] ?? _rolePermissions[widget.userData['role']] ?? [];
      return permissions.contains(item['routeName']);
    }).toList();
  }

  Future<void> _handleLogout() async {
    final storage = FlutterSecureStorage();
    await storage.delete(key: 'authToken');
    await storage.delete(key: 'user');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.userData['role']?.toLowerCase();
    return Drawer(
      width: 320,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[800]!, Colors.grey[600]!, Colors.grey[800]!],
          ),
        ),
        child: Stack(
          children: [
            // Decorative Background Pattern
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[600]!.withOpacity(0.1), Colors.transparent, Colors.teal[600]!.withOpacity(0.1)],
                ),
              ),
            ),
            Positioned(
              top: -64,
              right: -64,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue[500]!.withOpacity(0.2), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.teal[500]!.withOpacity(0.2), Colors.transparent],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.grey[600]!.withOpacity(0.9), Colors.grey[600]!.withOpacity(0.9)],
                    ),
                    border: Border(bottom: BorderSide(color: Colors.grey[500]!.withOpacity(0.3))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.blue[500]!, Colors.teal[500]!],
                          ),
                          boxShadow: [BoxShadow(color: Colors.blue[400]!.withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: Icon(
                          role == 'hod' ? Icons.account_balance : role == 'cc' ? Icons.star : Icons.book,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role == 'hod'
                                ? 'HOD Portal'
                                : role == 'principal'
                                ? 'Principal Portal'
                                : role == 'cc'
                                ? 'CC Portal'
                                : ['teaching', 'nonteaching', 'non-teaching'].contains(role)
                                ? 'Staff Portal'
                                : 'Admin Portal',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (role == 'hod' || role == 'cc')
                            Text(
                              role == 'hod'
                                  ? '${widget.userData['department']} Department'
                                  : 'Course Coordinator${widget.userData['department'] != null ? ' - ${widget.userData['department']}' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[200],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Menu Items
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: _filteredMenuItems.asMap().entries.map((entry) {
                        final item = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item['isSection'] && item['sectionTitle'] != null) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.blue[400]!, Colors.teal[400]!],
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item['sectionTitle'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[300],
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(color: Colors.grey[500]!.withOpacity(0.4)),
                            ],
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: ModalRoute.of(context)!.settings.name == item['href']
                                        ? [Colors.blue[500]!.withOpacity(0.5), Colors.teal[500]!.withOpacity(0.5)]
                                        : [Colors.grey[500]!.withOpacity(0.5), Colors.grey[500]!.withOpacity(0.5)],
                                  ),
                                  boxShadow: [
                                    if (ModalRoute.of(context)!.settings.name == item['href'])
                                      BoxShadow(color: Colors.blue[400]!.withOpacity(0.3), blurRadius: 8),
                                  ],
                                ),
                                child: Icon(item['icon'], color: Colors.white, size: 20),
                              ),
                              title: Text(
                                item['title'],
                                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              trailing: Icon(Icons.chevron_right, color: Colors.grey[300]!.withOpacity(0.6), size: 18),
                              selected: ModalRoute.of(context)!.settings.name == item['href'],
                              selectedTileColor: Colors.blue[600]!.withOpacity(0.4),
                              onTap: () {
                                widget.handleMenuClick(item);
                                widget.onClose();
                              },
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Logout Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Divider(color: Colors.grey[500]!.withOpacity(0.4)),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.red[500]!.withOpacity(0.4), Colors.pink[500]!.withOpacity(0.4)],
                      ),
                      boxShadow: [BoxShadow(color: Colors.red[400]!.withOpacity(0.3), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.logout, color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  onTap: _handleLogout,
                ),
                // User Info
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[500]!.withOpacity(0.4))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.blue[500]!, Colors.teal[500]!],
                          ),
                          boxShadow: [BoxShadow(color: Colors.blue[400]!.withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.userData['email'] ?? 'Unknown',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (role == 'hod')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.blue[500]!, Colors.teal[500]!],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [BoxShadow(color: Colors.blue[400]!.withOpacity(0.3), blurRadius: 4)],
                                    ),
                                    child: const Text(
                                      'HOD',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              _roleDisplayNames[role] ?? 'Unknown',
                              style: TextStyle(fontSize: 12, color: Colors.grey[300], fontWeight: FontWeight.w500),
                            ),
                          ],
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
    );
  }
}