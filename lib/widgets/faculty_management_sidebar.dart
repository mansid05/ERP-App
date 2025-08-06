import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../utils/role_permissions_and_routes.dart'; // Import role permissions
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FacultyManagementSidebar extends StatelessWidget {
  final bool isOpen;
  final Function(Map<String, dynamic>) handleMenuClick;
  final Map<String, dynamic> userData;

  const FacultyManagementSidebar({
    super.key,
    required this.isOpen,
    required this.handleMenuClick,
    required this.userData,
  });

  List<Map<String, dynamic>> _getMenuItems() {
    final role = userData['role']?.toLowerCase();
    return [
      // Dashboard Section
      {
        'title': 'Dashboard',
        'icon': Icons.home,
        'href': role == 'cc' ? '/cc-dashboard' : '/dashboard',
        'routeName': role == 'cc' ? 'cc_dashboard' : 'dashboard',
        'isSection': true,
        'sectionTitle': 'Main',
      },
      // Faculty Management Section
      {
        'title': 'Add Faculty',
        'icon': Icons.book,
        'href': '/dashboard/add-faculty',
        'routeName': 'add_faculty',
        'isSection': true,
        'sectionTitle': 'Faculty Management',
      },
      {
        'title': 'View Faculties',
        'icon': Icons.group,
        'href': '/dashboard/view-faculties',
        'routeName': 'view_faculties',
      },
      // Student Management Section
      {
        'title': 'Department Students',
        'icon': Icons.school,
        'href': '/dashboard/department-students',
        'routeName': 'department_students',
        'isSection': true,
        'sectionTitle': 'Student Management',
      },
      // Administrative Section
      {
        'title': 'Profile',
        'icon': Icons.person,
        'href': '/dashboard/faculty-profile',
        'routeName': 'faculty_profile',
        'isSection': true,
        'sectionTitle': 'Personal',
      },
      {
        'title': 'Pay Slip',
        'icon': Icons.credit_card,
        'href': '/dashboard/payslip',
        'routeName': 'payslip',
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
      // Financial Section
      {
        'title': 'Payment',
        'icon': Icons.credit_card,
        'href': '/dashboard/payment',
        'routeName': 'payment',
        'isSection': true,
        'sectionTitle': 'Financial',
      },
      // Academic Section
      {
        'title': 'Academic Calendar',
        'icon': Icons.calendar_today,
        'href': '/dashboard/academic-calendar',
        'routeName': 'academic_calendar',
        'isSection': true,
        'sectionTitle': 'Academic',
      },
      // Communication Section
      {
        'title': 'Announcements',
        'icon': Icons.description,
        'href': '/dashboard/announcement',
        'routeName': 'announcement',
        'isSection': true,
        'sectionTitle': 'Communication',
      },
    ];
  }

  Map<String, List<String>> get _rolePermissions {
    return rolePermissionsAndRoutes.fold<Map<String, List<String>>>({}, (acc, role) {
      acc[role['role']] = role['permissions'];
      return acc;
    });
  }

  List<Map<String, dynamic>> get _filteredMenuItems {
    final role = userData['role']?.toLowerCase();
    return _getMenuItems().where((item) {
      final permissions = _rolePermissions[role] ?? _rolePermissions[userData['role']] ?? [];
      return permissions.contains(item['routeName']);
    }).toList();
  }

  Future<void> _handleLogout(BuildContext context) async {
    final storage = FlutterSecureStorage();
    await storage.delete(key: 'authToken');
    await storage.delete(key: 'user');
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        child: const Icon(Icons.book, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faculty Management',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Administrative Portal',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blueAccent,
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
                                handleMenuClick(item);
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
                  onTap: () => _handleLogout(context),
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
                                    userData['email'] ?? 'Unknown',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
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
                                    'FM',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Faculty Management',
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
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