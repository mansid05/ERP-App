import 'package:erp_app/screens/course_coordinator/timetable_simple.dart';
import 'package:erp_app/screens/principal/principal_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../common functions/apply_charges_handover.dart';
import '../common functions/apply_leave.dart';
import '../common functions/approve_charge_handover.dart';
import '../common functions/fetched_timetable.dart';
import '../common functions/notes_documents_page.dart';
import '../common functions/od_leave_apply_screen.dart';
import '../common functions/pay_slip_screen.dart';
import '../common functions/teaching_announcements.dart';
import '../course_coordinator/cc_class_students_page.dart';
import '../course_coordinator/cc_dashboard.dart';
import '../course_coordinator/mark_attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userName;
  String? _userRole;
  bool _isLoading = true;
  Map<String, dynamic>? _userData; // Store userData for navigation

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user');
      if (userDataStr != null) {
        final userData = jsonDecode(userDataStr);
        setState(() {
          _userData = userData; // Store userData
          _userName = '${userData['firstName']} ${userData['middleName'] ?? ''} ${userData['lastName']}'.trim();
          _userRole = userData['role']?.toUpperCase() ?? 'ASSISTANT PROFESSOR';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = 'User';
          _userRole = 'Unknown Role';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _userName = 'User';
        _userRole = 'Unknown Role';
        _isLoading = false;
      });
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Night';
  }

  // Define the icon buttons for each role
  List<Map<String, dynamic>> _getIconButtons() {
    final role = _userData?['role']?.toLowerCase() ?? 'teaching';
    final List<Map<String, dynamic>> buttons = [
      // Common buttons for all roles
      {
        'icon': Icons.dashboard,
        'label': 'Dashboard',
        'onTap': () {
          if (role == 'principal') {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PrincipalDashboardPage()));
          // } else if (role == 'hod') {
          //   Navigator.push(context, MaterialPageRoute(builder: (context) => const HODDashboard()));
          // } else if (role == 'facultymanagement') {
          //   Navigator.push(context, MaterialPageRoute(builder: (context) => const FacultyDashboard()));
          } else if (role == 'cc') {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CCDashboard()));
          // } else if (role == 'teaching') {
          //   Navigator.push(context, MaterialPageRoute(builder: (context) => const TeachingStaffDashboard()));
          }
        },
      },
      {
        'icon': Icons.account_circle_rounded,
        'label': 'Profile',
        'onTap': () {
          Navigator.pushNamed(context, '/profile', arguments: _userData ?? {});
        },
      },
      {
        'icon': Icons.receipt,
        'label': 'Pay Slip',
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PaySlipScreen()));
        },
      },
    ];

    // Role-specific buttons
    if (role == 'principal') {
      buttons.addAll([
        {
          'icon': Icons.menu_book,
          'label': 'All\nStaff',
          'onTap': () {},
        },
        {
          'icon': Icons.chat_bubble,
          'label': 'Compose\nAnnouncement',
          'onTap': () {},
        },
        {
          'icon': Icons.calendar_today,
          'label': 'Fetched\nTimetable',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FetchedTimetable()));
          },
        },
        {
          'icon': Icons.assignment,
          'label': 'Approve\nLeave',
          'onTap': () {},
        },
        {
          'icon': Icons.assignment,
          'label': 'Approve\nOD Leave',
          'onTap': () {},
        },
      ]);
    } else if (role == 'hod') {
      buttons.addAll([
        {
          'icon': Icons.people_alt,
          'label': 'Department\nFaculty',
          'onTap': () {},
        },
        {
          'icon': Icons.people_alt,
          'label': 'Department\nStudents',
          'onTap': () {},
        },
        {
          'icon': Icons.calendar_month_rounded,
          'label': 'Academic\nCalendar',
          'onTap': () {},
        },
        {
          'icon': Icons.chat_bubble,
          'label': 'Compose\nAnnouncement',
          'onTap': () {},
        },
        {
          'icon': Icons.feedback,
          'label': 'Student\nFeedback',
          'onTap': () {},
        },
        {
          'icon': Icons.calendar_today,
          'label': 'Fetched\nTimetable',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FetchedTimetable()));
          },
        },
        {
          'icon': Icons.edit,
          'label': 'Apply\nLeave',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplyLeave()));
          },
        },
        {
          'icon': Icons.book,
          'label': 'Apply\nOD Leave',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ApplyODLeaveScreen(userData: _userData ?? {})));
          },
        },
        {
          'icon': Icons.assignment,
          'label': 'Approve\nLeave',
          'onTap': () {},
        },
        {
          'icon': Icons.assignment,
          'label': 'Approve\nOD Leave',
          'onTap': () {},
        },
        {
          'icon': Icons.folder_copy_rounded,
          'label': 'Apply Charge\nHandover',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplyChargeHandoverScreen()));
          },
        },
        {
          'icon': Icons.handshake,
          'label': 'Approve Charge\nHandover',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ChargeHandoverDashboard()));
          },
        },
        {
          'icon': Icons.note_alt_sharp,
          'label': 'Notes and\nDocuments',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const NotesDocumentsPage()));
          },
        },
      ]);
    } else if (role == 'facultymanagement') {
      buttons.addAll([
        {
          'icon': Icons.menu_book_rounded,
          'label': 'Add\nFaculty',
          'onTap': () {},
        },
        {
          'icon': Icons.people_alt,
          'label': 'View\nFaculties',
          'onTap': () {},
        },
        {
          'icon': Icons.edit,
          'label': 'Apply\nLeave',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplyLeave()));
          },
        },
        {
          'icon': Icons.wallet,
          'label': 'Payment',
          'onTap': () {},
        },
        {
          'icon': Icons.announcement,
          'label': 'Announcements',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TeachingAnnouncements()));
          },
        },
      ]);
    } else if (role == 'teaching') {
      buttons.addAll([
        {
          'icon': Icons.announcement,
          'label': 'Announcements',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TeachingAnnouncements()));
          },
        },
        {
          'icon': Icons.calendar_today,
          'label': 'Fetched\nTimetable',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FetchedTimetable()));
          },
        },
        {
          'icon': Icons.calendar_month_rounded,
          'label': 'Timetable',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => TimetableSimple(userData: _userData ?? {})));
          },
        },
        {
          'icon': Icons.check_circle,
          'label': 'Mark\nAttendance',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MarkAttendanceScreen()));
          },
        },
        {
          'icon': Icons.edit,
          'label': 'Apply\nLeave',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplyLeave()));
          },
        },
        {
          'icon': Icons.book,
          'label': 'Apply\nOD Leave',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ApplyODLeaveScreen(userData: _userData ?? {})));
          },
        },
        {
          'icon': Icons.folder_copy_rounded,
          'label': 'Apply Charge\nHandover',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplyChargeHandoverScreen()));
          },
        },
        {
          'icon': Icons.handshake,
          'label': 'Approve Charge\nHandover',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ChargeHandoverDashboard()));
          },
        },
        {
          'icon': Icons.note_alt_sharp,
          'label': 'Notes and\nDocuments',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const NotesDocumentsPage()));
          },
        },
      ]);
    } else if (role == 'cc') {
      buttons.addAll([
        {
          'icon': Icons.announcement,
          'label': 'Announcements',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TeachingAnnouncements()));
          },
        },
        {
          'icon': Icons.calendar_today,
          'label': 'Class\nSchedule',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FetchedTimetable()));
          },
        },
        {
          'icon': Icons.calendar_month_rounded,
          'label': 'Timetable',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => TimetableSimple(userData: _userData ?? {})));
          },
        },
        {
          'icon': Icons.check_circle,
          'label': 'Mark\nAttendance',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MarkAttendanceScreen()));
          },
        },
        {
          'icon': Icons.edit,
          'label': 'Apply\nLeave',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplyLeave()));
          },
        },
        {
          'icon': Icons.book,
          'label': 'OD\nLeave',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ApplyODLeaveScreen(userData: _userData ?? {})));
          },
        },
        {
          'icon': Icons.folder_copy_rounded,
          'label': 'Apply Charge\nHandover',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplyChargeHandoverScreen()));
          },
        },
        {
          'icon': Icons.handshake,
          'label': 'Approve Charge\nHandover',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ChargeHandoverDashboard()));
          },
        },
        {
          'icon': Icons.note_alt_sharp,
          'label': 'Notes and\nDocuments',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const NotesDocumentsPage()));
          },
        },
        {
          'icon': Icons.edit_attributes,
          'label': 'Class\nStudents',
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CCClassStudentsPage()));
          },
        },
        {
          'icon': Icons.menu_book,
          'label': 'All\nStaff',
          'onTap': () {},
        },
        {
          'icon': Icons.chat_bubble,
          'label': 'Compose\nAnnouncement',
          'onTap': () {},
        },
        {
          'icon': Icons.assignment,
          'label': 'Approve\nLeave',
          'onTap': () {},
        },
        {
          'icon': Icons.assignment,
          'label': 'Approve\nOD Leave',
          'onTap': () {},
        },
        {
          'icon': Icons.people_alt,
          'label': 'Department\nFaculty',
          'onTap': () {},
        },
        {
          'icon': Icons.people_alt,
          'label': 'Department\nStudents',
          'onTap': () {},
        },
        {
          'icon': Icons.calendar_month_rounded,
          'label': 'Academic\nCalendar',
          'onTap': () {},
        },
        {
          'icon': Icons.feedback,
          'label': 'Student\nFeedback',
          'onTap': () {},
        },
        {
          'icon': Icons.menu_book_rounded,
          'label': 'Add\nFaculty',
          'onTap': () {},
        },
        {
          'icon': Icons.people_alt,
          'label': 'View\nFaculties',
          'onTap': () {},
        },
        {
          'icon': Icons.wallet,
          'label': 'Payment',
          'onTap': () {},
        },
      ]);
    }

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2553A1), Color(0xFF2B7169)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        toolbarHeight: 120,
        title: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getGreeting(),
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
            Text(
              _userName ?? 'User',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            Text(
              _userRole ?? 'Unknown Role',
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Image.asset(
                'assets/logo.jpg',
                height: 100,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'NAGARJUNA INSTITUTE OF ENGINEERING, TECHNOLOGY & MANAGEMENT\n2024-2025',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search Student',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My To Do Details'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: _getIconButtons()
                  .map((button) => _buildIconButton(
                button['icon'],
                button['label'],
                onTap: button['onTap'],
              ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: const [
                        Text('Leave', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Pending Approval'),
                        Text('0', style: TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: const [
                        Text('OD Leave', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Pending Approval'),
                        Text('0', style: TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String label, {VoidCallback? onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(icon, color: const Color(0xFF1D70B9)),
              onPressed: onTap ?? () {},
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}