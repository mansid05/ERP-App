import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

class ChargeHandoverDashboard extends StatefulWidget {
  const ChargeHandoverDashboard({super.key});

  @override
  _ChargeHandoverDashboardState createState() => _ChargeHandoverDashboardState();
}

class _ChargeHandoverDashboardState extends State<ChargeHandoverDashboard> {
  static const String _baseUrl = 'http://192.168.1.33:5000';
  List<Map<String, dynamic>> receivedRequests = [];
  List<Map<String, dynamic>> sentRequests = [];
  bool isLoading = true;
  String? error;
  String? successMessage;
  Map<String, dynamic>? userData;
  String userRole = '';
  String currentUserId = '';
  String employeeId = '';
  String employeeName = '';
  String? token;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    await _fetchUserData();
    if (token != null && mounted) {
      await _fetchRequests();
    }
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user');
      if (userDataString == null) {
        setState(() {
          error = '❌ Please log in to continue';
        });
        debugPrint('No user data found in SharedPreferences');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      final storedUserData = jsonDecode(userDataString) as Map<String, dynamic>;
      setState(() {
        userData = storedUserData;
        userRole = storedUserData['role']?.toString().toLowerCase() ?? '';
        currentUserId = storedUserData['_id']?.toString() ?? storedUserData['id']?.toString() ?? '';
        employeeId = storedUserData['employeeId']?.toString() ?? '';
        employeeName = '${storedUserData['firstName'] ?? ''} ${storedUserData['lastName'] ?? ''}'.trim();
        token = storedUserData['token']?.toString() ?? prefs.getString('authToken') ?? '';
      });

      if (token!.isEmpty) {
        setState(() {
          error = '❌ Authentication token not found';
        });
        debugPrint('No token found in SharedPreferences or user data');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else if (userRole.isEmpty || currentUserId.isEmpty || employeeId.isEmpty) {
        setState(() {
          error = '❌ Incomplete user data. Please log in again.';
        });
        debugPrint('Incomplete user data: role=$userRole, userId=$currentUserId, employeeId=$employeeId');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
      debugPrint('User data: $userData');
    } catch (err) {
      setState(() {
        error = '❌ Failed to load user data: ${err.toString()}';
      });
      debugPrint('Error loading user data: $err');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _fetchRequests() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('Tasks API response status: ${response.statusCode}');
      debugPrint('Tasks API response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final allTasks = responseBody is Map<String, dynamic> && responseBody['data'] is List
            ? List<dynamic>.from(responseBody['data'])
            : responseBody is List
            ? responseBody
            : [];

        setState(() {
          receivedRequests = allTasks.cast<Map<String, dynamic>>().where((task) {
            final taskReceiverId = task['receiverId']?.toString();
            final taskSenderId = task['senderId']?.toString();
            final taskDepartment = task['department']?.toString();

            if (userRole == 'hod') {
              return taskDepartment == userData?['department']?.toString();
            } else if (userRole == 'teaching') {
              return taskReceiverId == currentUserId;
            }
            return false;
          }).toList();

          sentRequests = allTasks
              .cast<Map<String, dynamic>>()
              .where((task) => task['senderId']?.toString() == currentUserId)
              .toList();
        });
        debugPrint('Received requests: ${receivedRequests.length}');
        debugPrint('Sent requests: ${sentRequests.length}');
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          error = '❌ ${errorData['error'] ?? errorData['message'] ?? 'Failed to fetch requests'}';
        });
        if (response.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
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
        error = '❌ Failed to fetch requests: ${err.toString()}';
      });
      debugPrint('Error fetching requests: $err');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _handleApprove(String id) async {
    try {
      setState(() {
        error = null;
        successMessage = null;
      });

      final endpoint = userRole == 'hod' ? '/approve-hod' : '/approve-faculty';
      final approverId = userRole == 'hod' ? employeeId : currentUserId;

      debugPrint('Approving request: taskId=$id, endpoint=$endpoint, approverId=$approverId, userRole=$userRole');

      final response = await http.put(
        Uri.parse('$_baseUrl/api/tasks/$id$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'decision': 'approved',
          'approverId': approverId,
          'remarks': 'Approved',
        }),
      );

      if (response.statusCode == 200) {
        final actionText = userRole == 'hod' ? 'approved' : 'accepted';
        setState(() {
          successMessage = 'Request successfully $actionText!';
        });
        await _fetchRequests();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => successMessage = null);
          }
        });
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to approve request');
      }
    } catch (err) {
      setState(() {
        error = '❌ ${err.toString().replaceFirst('Exception: ', '')}';
      });
      debugPrint('Approval error: $err');
      if (err.toString().contains('401')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        debugPrint('Unauthorized: Clearing SharedPreferences and redirecting to login');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  Future<void> _handleReject(String id) async {
    try {
      setState(() {
        error = null;
        successMessage = null;
      });

      final endpoint = userRole == 'hod' ? '/approve-hod' : '/approve-faculty';
      final approverId = userRole == 'hod' ? employeeId : currentUserId;

      debugPrint('Rejecting request: taskId=$id, endpoint=$endpoint, approverId=$approverId, userRole=$userRole');

      final response = await http.put(
        Uri.parse('$_baseUrl/api/tasks/$id$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'decision': 'rejected',
          'approverId': approverId,
          'remarks': 'Rejected',
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          successMessage = 'Request successfully rejected!';
        });
        await _fetchRequests();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => successMessage = null);
          }
        });
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? errorData['error'] ?? 'Failed to reject request');
      }
    } catch (err) {
      setState(() {
        error = '❌ ${err.toString().replaceFirst('Exception: ', '')}';
      });
      debugPrint('Rejection error: $err');
      if (err.toString().contains('401')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        debugPrint('Unauthorized: Clearing SharedPreferences and redirecting to login');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final parts = dateString.split(' ');
      if (parts.length >= 6) {
        final datePart = '${parts[1]} ${parts[2]} ${parts[3]} ${parts[4]}';
        final formatter = DateFormat('MMM dd yyyy HH:mm:ss');
        final dateTime = formatter.parse(datePart);
        return DateFormat('MMM dd, yyyy').format(dateTime);
      }
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(dateString));
    } catch (e) {
      return dateString.isEmpty ? 'Not set' : dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 600;
        final padding = EdgeInsets.symmetric(
          horizontal: isMobile ? 12.0 : 24.0,
          vertical: isMobile ? 12.0 : 24.0,
        );
        final fontSizeLarge = isMobile ? 18.0 : 24.0;
        final fontSizeMedium = isMobile ? 14.0 : 18.0;
        final fontSizeSmall = isMobile ? 12.0 : 16.0;
        final fontSizeXSmall = isMobile ? 10.0 : 14.0;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Approve Charge Handover',
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
                      Color(0xFFF7FAFC), // bg-gray-50
                      Color(0xFFF9FAFB),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(padding.horizontal),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employeeName.isNotEmpty ? 'Welcome, $employeeName' : 'Charge Handover Dashboard',
                              style: TextStyle(
                                fontSize: fontSizeLarge,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Role: ${userRole == 'hod' ? 'HOD' : 'Faculty'}',
                                  style: TextStyle(
                                    fontSize: fontSizeSmall,
                                    color: const Color(0xFF4B5563),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (userData?['department'] != null) ...[
                                  Text(
                                    '•',
                                    style: TextStyle(
                                      fontSize: fontSizeSmall,
                                      color: const Color(0xFF4B5563),
                                    ),
                                  ),
                                  Text(
                                    'Department: ${userData?['department']}',
                                    style: TextStyle(
                                      fontSize: fontSizeSmall,
                                      color: const Color(0xFF4B5563),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: isLoading ? null : _fetchRequests,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF374151),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                                ),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Refresh Requests'),
                                  const SizedBox(width: 8),
                                  const Icon(Symbols.refresh, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Received Requests Section
                      const SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(padding.horizontal),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userRole == 'hod'
                                  ? 'Department Requests (${userData?['department'] ?? 'Your Department'})'
                                  : 'Charge Handover Requests for You',
                              style: TextStyle(
                                fontSize: fontSizeMedium,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userRole == 'hod'
                                  ? 'Track charge handover requests from your department'
                                  : 'Track charge handover requests assigned to you',
                              style: TextStyle(
                                fontSize: fontSizeXSmall,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                            if (receivedRequests.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    if (userRole == 'hod') ...[
                                      _buildStatChip(
                                        label: 'Pending Your Approval',
                                        count: receivedRequests.where((r) => r['status'] == 'pending_hod').length,
                                        color: const Color(0xFFFFD700),
                                        fontSize: fontSizeXSmall,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatChip(
                                        label: 'Waiting for Faculty',
                                        count: receivedRequests.where((r) => r['status'] == 'pending_faculty').length,
                                        color: const Color(0xFF3B82F6),
                                        fontSize: fontSizeXSmall,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatChip(
                                        label: 'Completed',
                                        count: receivedRequests.where((r) => r['status'] == 'approved').length,
                                        color: const Color(0xFF10B981),
                                        fontSize: fontSizeXSmall,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatChip(
                                        label: 'Rejected',
                                        count: receivedRequests.where((r) => r['status'] == 'rejected').length,
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeXSmall,
                                      ),
                                    ] else if (userRole == 'teaching') ...[
                                      _buildStatChip(
                                        label: 'Waiting for HOD',
                                        count: receivedRequests.where((r) => r['status'] == 'pending_hod').length,
                                        color: const Color(0xFFF97316),
                                        fontSize: fontSizeXSmall,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatChip(
                                        label: 'Pending Your Acceptance',
                                        count: receivedRequests.where((r) => r['status'] == 'pending_faculty').length,
                                        color: const Color(0xFFFFD700),
                                        fontSize: fontSizeXSmall,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatChip(
                                        label: 'Accepted',
                                        count: receivedRequests.where((r) => r['status'] == 'approved').length,
                                        color: const Color(0xFF10B981),
                                        fontSize: fontSizeXSmall,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatChip(
                                        label: 'Rejected',
                                        count: receivedRequests.where((r) => r['status'] == 'rejected').length,
                                        color: const Color(0xFFEF4444),
                                        fontSize: fontSizeXSmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Received Requests List
                      if (isLoading)
                        _buildLoadingState(padding)
                      else if (error != null)
                        _buildErrorState(error!, padding, fontSizeSmall)
                      else if (successMessage != null)
                          _buildSuccessState(successMessage!, padding, fontSizeSmall)
                        else
                          receivedRequests.isEmpty
                              ? _buildEmptyState(
                            userRole == 'hod'
                                ? 'No requests from your department.'
                                : 'No charge handover requests where you are the receiver.',
                            padding,
                            fontSizeSmall,
                          )
                              : Column(
                            children: receivedRequests.map((request) {
                              return _buildRequestCard(
                                request: request,
                                isReceived: true,
                                fontSizeSmall: fontSizeSmall,
                                fontSizeXSmall: fontSizeXSmall,
                                padding: padding,
                                isMobile: isMobile,
                                onApprove: () => _handleApprove(request['_id'].toString()),
                                onReject: () => _handleReject(request['_id'].toString()),
                              );
                            }).toList(),
                          ),
                      // Sent Requests Section
                      const SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(padding.horizontal),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Requests You Sent',
                          style: TextStyle(
                            fontSize: fontSizeMedium,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      // Sent Requests List
                      if (isLoading)
                        _buildLoadingState(padding)
                      else if (error != null)
                        _buildErrorState(error!, padding, fontSizeSmall)
                      else
                        sentRequests.isEmpty
                            ? _buildEmptyState('No sent requests found.', padding, fontSizeSmall)
                            : Column(
                          children: sentRequests.map((request) {
                            return _buildRequestCard(
                              request: request,
                              isReceived: false,
                              fontSizeSmall: fontSizeSmall,
                              fontSizeXSmall: fontSizeXSmall,
                              padding: padding,
                              isMobile: isMobile,
                              onApprove: null,
                              onReject: null,
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip({
    required String label,
    required int count,
    required Color color,
    required double fontSize,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: fontSize,
              color: const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(EdgeInsets padding) {
    return Container(
      padding: padding,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, EdgeInsets padding, double fontSize) {
    return Container(
      padding: padding,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F0),
            borderRadius: BorderRadius.circular(8),
            border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFE4E6))),
          ),
          child: Text(
            error,
            style: TextStyle(
              fontSize: fontSize,
              color: const Color(0xFFDC2626),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState(String message, EdgeInsets padding, double fontSize) {
    return Container(
      padding: padding,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: const Border.fromBorderSide(BorderSide(color: Color(0xFFD1FAE5))),
          ),
          child: Text(
            message,
            style: TextStyle(
              fontSize: fontSize,
              color: const Color(0xFF16A34A),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, EdgeInsets padding, double fontSize) {
    return Container(
      padding: padding,
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontSize: fontSize,
            color: const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard({
    required Map<String, dynamic> request,
    required bool isReceived,
    required double fontSizeSmall,
    required double fontSizeXSmall,
    required EdgeInsets padding,
    required bool isMobile,
    VoidCallback? onApprove,
    VoidCallback? onReject,
  }) {
    final isActionRequired = isReceived &&
        ((request['status'] == 'pending_hod' && userRole == 'hod') ||
            (request['status'] == 'pending_faculty' && userRole == 'teaching'));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: isActionRequired
            ? const Border(left: BorderSide(color: Color(0xFF3B82F6), width: 4))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          request['department']?.toString() ?? 'Unknown',
                          style: TextStyle(
                            fontSize: fontSizeXSmall,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        'Request #${request['_id']}',
                        style: TextStyle(
                          fontSize: fontSizeSmall,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      if (isActionRequired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Action Required',
                            style: TextStyle(
                              fontSize: fontSizeXSmall,
                              color: const Color(0xFFF97316),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isReceived && request['status'] == 'pending_hod' && userRole == 'hod') ...[
                  Flexible(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: onReject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFB91C1C),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: Color(0xFFFECACA)),
                            ),
                            minimumSize: const Size(80, 36),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.close, size: 16, color: Color(0xFFB91C1C)),
                              const SizedBox(width: 4),
                              Text(
                                'Reject',
                                style: TextStyle(fontSize: fontSizeXSmall),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: onApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF15803D),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: Color(0xFFD1FAE5)),
                            ),
                            minimumSize: const Size(80, 36),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.check, size: 16, color: Color(0xFF15803D)),
                              const SizedBox(width: 4),
                              Text(
                                'Approve',
                                style: TextStyle(fontSize: fontSizeXSmall),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isReceived && request['status'] == 'pending_faculty' && userRole == 'teaching') ...[
                  Flexible(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: onReject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFB91C1C),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: Color(0xFFFECACA)),
                            ),
                            minimumSize: const Size(80, 36),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.close, size: 16, color: Color(0xFFB91C1C)),
                              const SizedBox(width: 4),
                              Text(
                                'Reject',
                                style: TextStyle(fontSize: fontSizeXSmall),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: onApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF15803D),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(color: Color(0xFFD1FAE5)),
                            ),
                            minimumSize: const Size(80, 36),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.check, size: 16, color: Color(0xFF15803D)),
                              const SizedBox(width: 4),
                              Text(
                                'Accept',
                                style: TextStyle(fontSize: fontSizeXSmall),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isReceived && userRole == 'hod' && request['status'] != 'pending_hod') ...[
                  _buildStatusBadge(
                    status: request['status']?.toString() ?? 'unknown',
                    isHod: true,
                    fontSize: fontSizeXSmall,
                  ),
                ],
                if (isReceived && userRole == 'teaching' && request['status'] != 'pending_faculty') ...[
                  _buildStatusBadge(
                    status: request['status']?.toString() ?? 'unknown',
                    isHod: false,
                    fontSize: fontSizeXSmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Request Details
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isReceived) ...[
                  _buildDetailRow(
                    icon: Symbols.person,
                    label: 'Charge From:',
                    value: request['reportingManager']?.toString() ?? 'Unknown',
                    fontSize: fontSizeSmall,
                    xSmallFontSize: fontSizeXSmall,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildDetailRow(
                  icon: Symbols.person,
                  label: isReceived ? 'Charge To:' : 'Charge To:',
                  value: request['receiverName']?.toString() ?? 'Unknown',
                  fontSize: fontSizeSmall,
                  xSmallFontSize: fontSizeXSmall,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Symbols.calendar_month,
                  label: 'Duration:',
                  value: '${_formatDate(request['handoverStartDate']?.toString() ?? '')} - ${_formatDate(request['handoverEndDate']?.toString() ?? '')}',
                  fontSize: fontSizeSmall,
                  xSmallFontSize: fontSizeXSmall,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Symbols.info,
                  label: 'Reason:',
                  value: request['reason']?.toString() ?? 'None',
                  fontSize: fontSizeSmall,
                  xSmallFontSize: fontSizeXSmall,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Symbols.inventory,
                  label: 'Documents / Assets / Pending Tasks:',
                  value: '',
                  fontSize: fontSizeSmall,
                  xSmallFontSize: fontSizeXSmall,
                  children: [
                    Text(
                      'Documents: ${(request['documents'] as List<dynamic>?)?.map((e) => e.toString()).join(', ') ?? 'None'}',
                      style: TextStyle(
                        fontSize: fontSizeXSmall,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assets: ${(request['assets'] as List<dynamic>?)?.map((e) => e.toString()).join(', ') ?? 'None'}',
                      style: TextStyle(
                        fontSize: fontSizeXSmall,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pending Tasks: ${(request['pendingTasks'] as List<dynamic>?)?.map((e) => e.toString()).join(', ') ?? 'None'}',
                      style: TextStyle(
                        fontSize: fontSizeXSmall,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Workflow Status
                Row(
                  children: [
                    Text(
                      'Workflow Status:',
                      style: TextStyle(
                        fontSize: fontSizeXSmall,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _buildWorkflowIndicator(
                        status: request['status']?.toString() ?? 'unknown',
                        isHod: userRole == 'hod',
                        fontSize: fontSizeXSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildStatusText(
                  status: request['status']?.toString() ?? 'unknown',
                  isHod: userRole == 'hod',
                  isReceived: isReceived,
                  fontSize: fontSizeXSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required double fontSize,
    required double xSmallFontSize,
    List<Widget> children = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: xSmallFontSize,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (children.isEmpty)
          Text(
            value,
            style: TextStyle(
              fontSize: xSmallFontSize,
              color: const Color(0xFF111827),
            ),
          )
        else
          Column(children: children),
      ],
    );
  }

  Widget _buildStatusBadge({
    required String status,
    required bool isHod,
    required double fontSize,
  }) {
    String text;
    Color bgColor;
    Color textColor;

    if (isHod) {
      switch (status) {
        case 'pending_faculty':
          text = 'Waiting for Faculty';
          bgColor = const Color(0xFFFFF3E0);
          textColor = const Color(0xFFD97706);
          break;
        case 'approved':
          text = '✅ Completed';
          bgColor = const Color(0xFFF0FDF4);
          textColor = const Color(0xFF16A34A);
          break;
        case 'rejected':
          text = '❌ Rejected';
          bgColor = const Color(0xFFFFF1F0);
          textColor = const Color(0xFFDC2626);
          break;
        default:
          text = 'Unknown Status';
          bgColor = const Color(0xFFF3F4F6);
          textColor = const Color(0xFF6B7280);
      }
    } else {
      switch (status) {
        case 'pending_hod':
          text = 'Waiting for HOD';
          bgColor = const Color(0xFFFFF3E0);
          textColor = const Color(0xFFF97316);
          break;
        case 'approved':
          text = '✅ Accepted';
          bgColor = const Color(0xFFF0FDF4);
          textColor = const Color(0xFF16A34A);
          break;
        case 'rejected':
          text = '❌ Rejected by Me';
          bgColor = const Color(0xFFFFF1F0);
          textColor = const Color(0xFFDC2626);
          break;
        default:
          text = 'Unknown Status';
          bgColor = const Color(0xFFF3F4F6);
          textColor = const Color(0xFF6B7280);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildWorkflowIndicator({
    required String status,
    required bool isHod,
    required double fontSize,
  }) {
    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status == 'pending_hod' ? const Color(0xFFFFD700) : const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'HOD Approval',
              style: TextStyle(
                fontSize: fontSize,
                color: status == 'pending_hod' ? const Color(0xFFD97706) : const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
        const Text(
          '→',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFFD1D5DB),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status == 'pending_faculty'
                    ? const Color(0xFFFFD700)
                    : status == 'approved'
                    ? const Color(0xFF10B981)
                    : status == 'rejected'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFD1D5DB),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Faculty Acceptance',
              style: TextStyle(
                fontSize: fontSize,
                color: status == 'pending_faculty'
                    ? const Color(0xFFD97706)
                    : status == 'approved'
                    ? const Color(0xFF16A34A)
                    : status == 'rejected'
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusText({
    required String status,
    required bool isHod,
    required bool isReceived,
    required double fontSize,
  }) {
    String text;
    Color textColor;

    if (status == 'pending_hod') {
      text = isReceived ? '⏳ Pending HOD Approval' : '⏳ Waiting for HOD Approval';
      textColor = const Color(0xFFD97706);
    } else if (status == 'pending_faculty') {
      text = isReceived ? '⏳ Pending Faculty Acceptance' : '⏳ Waiting for Faculty Acceptance';
      textColor = const Color(0xFFD97706);
    } else if (status == 'approved') {
      text = '✅ Fully Approved & Accepted';
      textColor = const Color(0xFF16A34A);
    } else if (status == 'rejected') {
      text = isReceived && userRole == 'teaching' ? '❌ Rejected by Me' : '❌ Request Rejected';
      textColor = const Color(0xFFDC2626);
    } else {
      text = 'Unknown Status';
      textColor = const Color(0xFF6B7280);
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
    );
  }
}