import 'package:erp_app/screens/course_coordinator/apply_charges_handover.dart';
import 'package:erp_app/screens/course_coordinator/apply_leave.dart';
import 'package:erp_app/screens/course_coordinator/approve_charge_handover.dart';
import 'package:erp_app/screens/course_coordinator/cc_class_students_page.dart';
import 'package:erp_app/screens/course_coordinator/fetched_timetable.dart';
import 'package:erp_app/screens/course_coordinator/notes_documents_page.dart';
import 'package:erp_app/screens/course_coordinator/pay_slip_screen.dart';
import 'package:erp_app/screens/course_coordinator/teaching_announcements.dart';
import 'package:erp_app/screens/course_coordinator/timetable_simple.dart';
import 'package:erp_app/screens/service_book.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'cc_dashboard.dart';
import 'mark_attendance_screen.dart';
import 'od_leave_apply_screen.dart';

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
              children: [
                _buildIconButton(Icons.dashboard, 'Dashboard', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CCDashboard()),
                  );
                }),
                _buildIconButton(Icons.check_circle, 'Mark\nAttendance', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MarkAttendanceScreen()),
                  );
                }),
                _buildIconButton(Icons.announcement, 'Announcements', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TeachingAnnouncements()),
                  );
                }),
                _buildIconButton(Icons.calendar_today, 'Class\nSchedule', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FetchedTimetable()),
                  );
                }),
                _buildIconButton(Icons.calendar_month_rounded, 'Timetable', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TimetableSimple(userData: _userData ?? {})),
                  );
                }),
                _buildIconButton(Icons.receipt, 'Pay Slip', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PaySlipScreen()),
                  );
                }),
                _buildIconButton(Icons.edit, 'Apply\nLeave', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ApplyLeave()),
                  );
                }),
                _buildIconButton(Icons.book, 'OD\nLeave', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ApplyODLeaveScreen(userData: _userData ?? {})),
                  );
                }),
                _buildIconButton(Icons.folder_copy_rounded, 'Apply Charge\nHandover', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ApplyChargeHandoverScreen()),
                  );
                }),
                _buildIconButton(Icons.handshake, 'Approve Charge\nHandover', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChargeHandoverDashboard()),
                  );
                }),
                _buildIconButton(Icons.note_alt_sharp, 'Notes and\nDocuments', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NotesDocumentsPage()),
                  );
                }),
                _buildIconButton(Icons.edit_attributes, 'Class\nStudents ', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CCClassStudentsPage()),
                  );
                }),
              ],
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