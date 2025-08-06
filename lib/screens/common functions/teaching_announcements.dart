import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeachingAnnouncements extends StatefulWidget {
  const TeachingAnnouncements({Key? key}) : super(key: key);

  @override
  _TeachingAnnouncementsState createState() => _TeachingAnnouncementsState();
}

class _TeachingAnnouncementsState extends State<TeachingAnnouncements>
    with TickerProviderStateMixin {
  List<dynamic> announcements = [];
  bool loading = true;
  String? userDepartment;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const String _baseUrl = 'http://192.168.1.33:5000';

  @override
  void initState() {
    super.initState();
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Fetch user department and announcements
    fetchUserDepartment();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> fetchUserDepartment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userData = prefs.getString('user') ?? prefs.getString('userData');

      if (userData != null) {
        try {
          final parsedData = jsonDecode(userData);
          if (parsedData['department'] != null) {
            setState(() {
              userDepartment = parsedData['department'];
            });
            await fetchAnnouncements();
            return;
          }
        } catch (e) {
          debugPrint('Could not parse user data from SharedPreferences: $e');
        }
      }

      final token = prefs.getString('authToken') ?? prefs.getString('token');
      if (token != null) {
        try {
          final response = await http.get(
            Uri.parse('$_baseUrl/api/auth/profile'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['department'] != null) {
              setState(() {
                userDepartment = data['department'];
              });
              await fetchAnnouncements();
              return;
            }
          }
        } catch (apiError) {
          debugPrint('Failed to fetch user department from API: $apiError');
        }
      }

      setState(() {
        userDepartment = '';
      });
      await fetchAnnouncements();
    } catch (error) {
      debugPrint('Failed to fetch user department: $error');
      setState(() {
        userDepartment = '';
        loading = false;
      });
    }
  }

  Future<void> fetchAnnouncements() async {
    try {
      final queryParams = userDepartment != null && userDepartment!.isNotEmpty
          ? '?department=${Uri.encodeComponent(userDepartment!)}'
          : '';
      debugPrint(
          'Fetching announcements for teaching staff, department: ${userDepartment ?? "none"}');
      final response = await http.get(
        Uri.parse('$_baseUrl/api/announcements/teaching_staff$queryParams'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Found ${data.length} announcements');
        setState(() {
          announcements = (data as List).reversed.toList();
        });
      } else {
        debugPrint('Failed to fetch announcements: ${response.statusCode}');
      }
    } catch (err) {
      debugPrint('Failed to fetch announcements: $err');
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Announcements',
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.indigo[50]!,
              Colors.purple[50]!,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: isMobile ? 160 : 200,
                      height: isMobile ? 160 : 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.withOpacity(0.2),
                            Colors.purple.withOpacity(0.2),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: -40,
                    child: Container(
                      width: isMobile ? 160 : 200,
                      height: isMobile ? 160 : 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [
                            Colors.indigo.withOpacity(0.2),
                            Colors.pink.withOpacity(0.2),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height / 2 - (isMobile ? 80 : 100),
                    left: MediaQuery.of(context).size.width / 2 - (isMobile ? 80 : 100),
                    child: Container(
                      width: isMobile ? 160 : 200,
                      height: isMobile ? 160 : 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.cyan.withOpacity(0.1),
                            Colors.blue.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Header
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [Colors.blue[500]!, Colors.purple[600]!],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.email_outlined,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  Colors.grey[900]!,
                                  Colors.blue[800]!,
                                  Colors.purple[800]!,
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                '📢 Teaching Staff Announcements',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Stay updated with official notices and important communications from administrative authorities',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: loading
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.blue[200]!,
                                    width: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.blue),
                                  strokeWidth: 4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading announcements...',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                        : announcements.isEmpty
                        ? Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          margin: EdgeInsets.all(isMobile ? 12 : 16),
                          padding: EdgeInsets.all(isMobile ? 20 : 24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey[200]!,
                                      Colors.grey[300]!,
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    '📭',
                                    style: TextStyle(fontSize: 48),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Announcements',
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No announcements are currently available for teaching staff. Check back later for updates!',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.grey[500],
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                        : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: 8,
                      ),
                      itemCount: announcements.length,
                      itemBuilder: (context, index) {
                        final announcement = announcements[index];
                        return FadeTransition(
                          opacity: Tween<double>(
                            begin: 0,
                            end: 1,
                          ).animate(
                            CurvedAnimation(
                              parent: _fadeController,
                              curve: Interval(
                                index * 0.1,
                                (index + 1) * 0.1,
                                curve: Curves.easeOut,
                              ),
                            ),
                          ),
                          child: MouseRegion(
                            onEnter: (_) => setState(() {}),
                            onExit: (_) => setState(() {}),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Material(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(16),
                                elevation: 4,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {},
                                  onHover: (hovering) {
                                    setState(() {}); // Trigger rebuild for hover effect
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                announcement['title'] ?? '',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 18 : 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[800],
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isMobile ? 8 : 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.blue[100]!,
                                                    Colors.purple[100]!,
                                                  ],
                                                ),
                                                borderRadius:
                                                BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '🏷️ ${announcement['tag'] ?? ''}',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 10 : 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue[800],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          announcement['description'] ?? '',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 14,
                                            color: Colors.grey[700],
                                            height: 1.5,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: EdgeInsets.all(isMobile ? 8 : 12),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.grey[50]!.withOpacity(0.8),
                                                Colors.blue[50]!.withOpacity(0.8),
                                              ],
                                            ),
                                            borderRadius:
                                            BorderRadius.circular(12),
                                            border: Border.all(
                                              color:
                                              Colors.grey[200]!.withOpacity(0.5),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '📅 Posted: ${_formatDate(announcement['createdAt'])}',
                                                    style: TextStyle(
                                                      fontSize: isMobile ? 10 : 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '⏰ Deadline: ${_formatDate(announcement['endDate'])}',
                                                    style: TextStyle(
                                                      fontSize: isMobile ? 10 : 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(date).toLocal());
    } catch (e) {
      return 'N/A';
    }
  }
}