import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentData {
  final String? firstName;
  final String? lastName;
  final String? semester;
  final String? department;

  StudentData({this.firstName, this.lastName, this.semester, this.department});

  factory StudentData.fromJson(Map<String, dynamic> json) {
    return StudentData(
      firstName: json['firstName'],
      lastName: json['lastName'],
      semester: json['semester']?['number']?.toString() ?? json['semester'],
      department: json['department']?['name'] ?? json['department'] ?? json['stream']?['name'],
    );
  }
}

class NavItem {
  final String id;
  final String label;
  final IconData icon;

  NavItem({required this.id, required this.label, required this.icon});
}

class Sidebar extends StatefulWidget {
  final Function(String) setSection;
  final bool? isCollapsed;
  final VoidCallback? toggleSidebar;
  final bool isMobile;
  final bool mobileMenuOpen;
  final Function(bool)? setMobileMenuOpen;

  const Sidebar({
    Key? key,
    required this.setSection,
    this.isCollapsed,
    this.toggleSidebar,
    this.isMobile = false,
    this.mobileMenuOpen = false,
    this.setMobileMenuOpen,
  }) : super(key: key);

  @override
  _SidebarState createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  String _active = 'announcements';
  bool _localCollapsed = false;
  StudentData? _studentData;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadStudentData();
    if (widget.isCollapsed != null) {
      _localCollapsed = widget.isCollapsed!;
    }
    _animationController.forward();
  }

  @override
  void didUpdateWidget(Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != null && widget.isCollapsed != _localCollapsed) {
      setState(() {
        _localCollapsed = widget.isCollapsed!;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('studentData');
    if (savedData != null) {
      try {
        final parsedData = jsonDecode(savedData);
        setState(() {
          _studentData = StudentData.fromJson(parsedData);
        });
      } catch (e) {
        print('Error parsing student data: $e');
      }
    }
  }

  void _handleNavigation(String section) {
    setState(() {
      _active = section;
    });
    widget.setSection(section);
    if (widget.isMobile && widget.setMobileMenuOpen != null) {
      widget.setMobileMenuOpen!(false);
    }
  }

  void _handleToggle() {
    if (widget.toggleSidebar != null) {
      widget.toggleSidebar!();
    } else {
      setState(() {
        _localCollapsed = !_localCollapsed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.isCollapsed ?? _localCollapsed;

    final navItems = [
      NavItem(id: 'announcements', label: 'Announcements', icon: Icons.announcement),
      NavItem(id: 'timetables', label: 'Timetable', icon: Icons.calendar_today),
      NavItem(id: 'profile', label: 'Profile', icon: Icons.person),
      NavItem(id: 'feedback', label: 'Feedback', icon: Icons.feedback),
      NavItem(id: 'library', label: 'Library', icon: Icons.book),
      NavItem(id: 'materials', label: 'Study Materials', icon: Icons.school),
      NavItem(id: 'scholarship', label: 'Student Scholarship', icon: Icons.card_giftcard),
      NavItem(id: 'busManagement', label: 'Bus Management', icon: Icons.directions_bus),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: widget.isMobile ? 280 : (collapsed ? 80 : 280),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[900]!, Colors.grey[800]!, Colors.grey[900]!],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[700]!.withOpacity(0.5))),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.blue[400]!, Colors.blue[600]!, Colors.blue[800]!],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _studentData?.firstName?.substring(0, 1).toUpperCase() ?? 'N',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (!collapsed || widget.isMobile) ...[
                          const SizedBox(width: 12),
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _studentData != null
                                      ? '${_studentData!.firstName} ${_studentData!.lastName}'
                                      : 'NIET Portal',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    foreground: Paint()
                                      ..shader = LinearGradient(
                                        colors: [Colors.blue[300]!, Colors.blue[600]!],
                                      ).createShader(Rect.fromLTWH(0, 0, 200, 20)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Student Dashboard',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!collapsed || widget.isMobile) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _studentData?.semester ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[400],
                                    ),
                                  ),
                                  const Text(
                                    'Semester',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _studentData?.department ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[400],
                                    ),
                                  ),
                                  const Text(
                                    'Department',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Navigation
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  itemCount: navItems.length,
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isActive = _active == item.id;
                    return GestureDetector(
                      onTap: () => _handleNavigation(item.id),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: collapsed && !widget.isMobile
                            ? const EdgeInsets.all(12)
                            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: isActive
                              ? LinearGradient(
                            colors: [Colors.blue[600]!, Colors.blue[800]!],
                          )
                              : null,
                          color: isActive ? null : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                item.icon,
                                size: 20,
                                color: isActive ? Colors.white : Colors.grey[300],
                              ),
                            ),
                            if (!collapsed || widget.isMobile) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                    color: isActive ? Colors.white : Colors.grey[300],
                                  ),
                                ),
                              ),
                              if (isActive)
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Logout Button
              Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token');
                    await prefs.remove('studentData');
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: Container(
                    padding: collapsed && !widget.isMobile
                        ? const EdgeInsets.all(12)
                        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [Colors.red[500]!, Colors.red[600]!],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: collapsed && !widget.isMobile
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.logout,
                          size: 20,
                          color: Colors.white,
                        ),
                        if (!collapsed || widget.isMobile) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Toggle Button
          if (!widget.isMobile)
            Positioned(
              top: 40,
              right: -12,
              child: GestureDetector(
                onTap: _handleToggle,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue[500]!, Colors.blue[600]!],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    collapsed ? Icons.chevron_right : Icons.chevron_left,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          // Mobile Close Button
          if (widget.isMobile)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => widget.setMobileMenuOpen?.call(false),
              ),
            ),
        ],
      ),
    );
  }
}