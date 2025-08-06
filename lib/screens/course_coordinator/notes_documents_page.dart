import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

class NotesDocumentsPage extends StatefulWidget {
  const NotesDocumentsPage({super.key});

  @override
  _NotesDocumentsPageState createState() => _NotesDocumentsPageState();
}

class _NotesDocumentsPageState extends State<NotesDocumentsPage> {
  static const String _baseUrl = 'http://192.168.1.33:5000';
  List<Map<String, dynamic>> files = [];
  String title = '';
  String year = '';
  String section = '';
  String department = '';
  String subject = '';
  File? file;
  bool isUploading = false;
  String? error;
  String? success;
  List<String> subjectsTaught = [];
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  String? token;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchFiles();
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

      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      final fetchedToken = userData['token']?.toString() ?? prefs.getString('authToken') ?? '';
      if (fetchedToken.isEmpty) {
        setState(() {
          error = '❌ Authentication token not found';
        });
        debugPrint('No token found in SharedPreferences or user data');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      setState(() {
        token = fetchedToken;
        department = userData['department']?.toString() ?? 'Unknown Department';
        final subjects = userData['subjectsTaught'] ?? [];
        subjectsTaught = subjects is List
            ? (subjects.map((s) => s is Map ? s['name']?.toString() ?? s.toString() : s.toString()).toList())
            : [];
      });

      debugPrint('User department: $department');
      debugPrint('Subjects taught: $subjectsTaught');
    } catch (err) {
      setState(() {
        error = '❌ Failed to load user data: ${err.toString()}';
      });
      debugPrint('Error fetching user data: $err');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _fetchFiles() async {
    setState(() {
      error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/files'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('Files API response status: ${response.statusCode}');
      debugPrint('Files API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          files = data['success'] ? List<Map<String, dynamic>>.from(data['files'] ?? []) : [];
        });
      } else {
        setState(() {
          error = '❌ ${jsonDecode(response.body)['message'] ?? 'Failed to fetch files'}';
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
        error = '❌ Failed to fetch files: ${err.toString()}';
      });
      debugPrint('Error fetching files: $err');
    }
  }

  Future<void> _handleFilePick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png', 'zip', 'rar'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          file = File(result.files.single.path!);
        });
      }
    } catch (err) {
      setState(() {
        error = '❌ Failed to pick file: ${err.toString()}';
      });
    }
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate() || file == null) {
      setState(() {
        error = '❌ Please provide a material title, select subject, target year, section, and choose a file to share.';
      });
      return;
    }

    setState(() {
      isUploading = true;
      error = null;
      success = null;
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/files'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = title;
      request.fields['year'] = year;
      request.fields['section'] = section;
      request.fields['department'] = department;
      request.fields['subject'] = subject;
      request.files.add(await http.MultipartFile.fromPath('file', file!.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 200 && data['success']) {
        setState(() {
          success = '✅ Study material "$title" shared successfully with ${section == 'ALL' ? 'all sections of' : 'section $section'} Year $year students in $department department for $subject!';
          title = '';
          year = '';
          section = '';
          subject = '';
          file = null;
          _titleController.clear();
        });
        await _fetchFiles();
      } else {
        setState(() {
          error = '❌ ${data['message'] ?? 'Upload failed'}';
        });
      }
    } catch (err) {
      setState(() {
        error = '❌ Upload failed: ${err.toString()}';
      });
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _handleDelete(String fileId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to remove this study material? Students will no longer be able to access it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      error = null;
      success = null;
    });

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/files/$fileId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        setState(() {
          success = '✅ Study material removed successfully.';
        });
        await _fetchFiles();
      } else {
        setState(() {
          error = '❌ ${data['message'] ?? 'Delete failed'}';
        });
      }
    } catch (err) {
      setState(() {
        error = '❌ Delete failed: ${err.toString()}';
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
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
              'Share Study Materials',
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
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF7FAFC), Color(0xFFDBEAFE), Color(0xFFE0E7FF)],
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(padding.horizontal),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '📚 Share Study Materials with Students',
                                style: TextStyle(
                                  fontSize: fontSizeLarge,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2937),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload and share documents, notes, assignments, and study materials with your students',
                                style: TextStyle(
                                  fontSize: fontSizeSmall,
                                  color: const Color(0xFF4B5563),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Upload Form Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(padding.horizontal),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    labelText: 'Material Title',
                                    hintText: 'e.g., Unit 1 Notes, Assignment 2, Lab Manual',
                                    prefixIcon: const Icon(Symbols.description, size: 20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  style: TextStyle(fontSize: fontSizeSmall),
                                  enabled: !isUploading,
                                  onChanged: (value) => setState(() => title = value),
                                  validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Subject (${subjectsTaught.length} available)',
                                    prefixIcon: const Icon(Symbols.book, size: 20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  value: subject.isEmpty ? null : subject,
                                  items: subjectsTaught.map((subj) {
                                    return DropdownMenuItem<String>(
                                      value: subj,
                                      child: Text(
                                        subj,
                                        style: TextStyle(fontSize: fontSizeSmall),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: isUploading
                                      ? null
                                      : (value) => setState(() => subject = value ?? ''),
                                  validator: (value) => value == null || value.isEmpty ? 'Please select a subject' : null,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    border: Border.all(color: const Color(0xFFD1D5DB)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Symbols.account_balance, size: 20, color: Color(0xFF4B5563)),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Department: ${department.isEmpty ? 'Loading...' : department}',
                                            style: TextStyle(
                                              fontSize: fontSizeSmall,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF1F2937),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Department is automatically detected from your profile',
                                        style: TextStyle(
                                          fontSize: fontSizeXSmall,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Target Year',
                                    prefixIcon: const Icon(Symbols.school, size: 20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  value: year.isEmpty ? null : year,
                                  items: const [
                                    DropdownMenuItem(value: '1', child: Text('1st Year Students')),
                                    DropdownMenuItem(value: '2', child: Text('2nd Year Students')),
                                    DropdownMenuItem(value: '3', child: Text('3rd Year Students')),
                                    DropdownMenuItem(value: '4', child: Text('4th Year Students')),
                                  ],
                                  onChanged: isUploading ? null : (value) => setState(() => year = value ?? ''),
                                  validator: (value) => value == null || value.isEmpty ? 'Please select a year' : null,
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Target Section',
                                    prefixIcon: const Icon(Symbols.group, size: 20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  value: section.isEmpty ? null : section,
                                  items: const [
                                    DropdownMenuItem(value: 'A', child: Text('Section A')),
                                    DropdownMenuItem(value: 'B', child: Text('Section B')),
                                    DropdownMenuItem(value: 'C', child: Text('Section C')),
                                    DropdownMenuItem(value: 'D', child: Text('Section D')),
                                    DropdownMenuItem(value: 'ALL', child: Text('All Sections (Broadcast to all)')),
                                  ],
                                  onChanged: isUploading ? null : (value) => setState(() => section = value ?? ''),
                                  validator: (value) => value == null || value.isEmpty ? 'Please select a section' : null,
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: isUploading ? null : _handleFilePick,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFD1D5DB)),
                                      borderRadius: BorderRadius.circular(8),
                                      color: const Color(0xFFF3F4F6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Symbols.upload_file, size: 20, color: Color(0xFF4B5563)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            file == null ? 'Choose File' : file!.path.split('/').last,
                                            style: TextStyle(
                                              fontSize: fontSizeSmall,
                                              color: file == null ? const Color(0xFF6B7280) : const Color(0xFF1F2937),
                                            ),
                                          ),
                                        ),
                                        if (file != null)
                                          IconButton(
                                            icon: const Icon(Symbols.close, size: 20, color: Color(0xFFB91C1C)),
                                            onPressed: isUploading
                                                ? null
                                                : () => setState(() => file = null),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Accepted formats: PDF, Word, PowerPoint, Text, Images, Archives',
                                  style: TextStyle(
                                    fontSize: fontSizeXSmall,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '💡 Tip: Students will only see materials for subjects they study and their respective year/section',
                                  style: TextStyle(
                                    fontSize: fontSizeXSmall,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: ElevatedButton(
                                    onPressed: isUploading ? null : _handleUpload,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      minimumSize: const Size(120, 48),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isUploading) ...[
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Uploading...',
                                            style: TextStyle(fontSize: fontSizeMedium),
                                          ),
                                        ] else ...[
                                          const Icon(Symbols.upload, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Share with Students',
                                            style: TextStyle(fontSize: fontSizeMedium),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                if (error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1F0),
                                      borderRadius: BorderRadius.circular(8),
                                      border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFE4E6))),
                                    ),
                                    child: Text(
                                      error!,
                                      style: TextStyle(
                                        fontSize: fontSizeSmall,
                                        color: const Color(0xFFDC2626),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                                if (success != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: const Border.fromBorderSide(BorderSide(color: Color(0xFFD1FAE5))),
                                    ),
                                    child: Text(
                                      success!,
                                      style: TextStyle(
                                        fontSize: fontSizeSmall,
                                        color: const Color(0xFF16A34A),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Files List Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(padding.horizontal),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Symbols.folder, size: 24, color: Color(0xFF1F2937)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Shared Study Materials',
                                    style: TextStyle(
                                      fontSize: fontSizeMedium,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Materials you\'ve shared with your students across different subjects and classes',
                                style: TextStyle(
                                  fontSize: fontSizeXSmall,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 16),
                              files.isEmpty
                                  ? Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFD1D5DB)),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Symbols.book, size: 48, color: Color(0xFF6B7280)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No study materials shared yet',
                                      style: TextStyle(
                                        fontSize: fontSizeMedium,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Start by uploading your first document!',
                                      style: TextStyle(
                                        fontSize: fontSizeXSmall,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                                  : Column(
                                children: files.map((f) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFD1D5DB)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Symbols.description, size: 20, color: Color(0xFF1F2937)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                f['title'] ?? 'Untitled',
                                                style: TextStyle(
                                                  fontSize: fontSizeSmall,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF1F2937),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '📚 Subject: ${f['subject'] ?? 'General'} • 🎓 Year ${f['year'] ?? 'N/A'} • 📝 Section ${f['section'] ?? 'All'} • 🏛️ Department: ${f['uploaderDepartment'] ?? department}',
                                          style: TextStyle(
                                            fontSize: fontSizeXSmall,
                                            color: const Color(0xFF4B5563),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '👨‍🏫 Shared by: ${f['uploaderName'] ?? 'You'} • 📅 ${_formatDate(f['createdAt'] ?? '')}',
                                          style: TextStyle(
                                            fontSize: fontSizeXSmall,
                                            color: const Color(0xFF6B7280),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () {
                                                // Implement file download (e.g., launch URL in browser)
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2563EB),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                minimumSize: const Size(80, 36),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Symbols.download, size: 16),
                                                  SizedBox(width: 4),
                                                  Text('Download'),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () => _handleDelete(f['_id'].toString()),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFEF4444),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                minimumSize: const Size(80, 36),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Symbols.delete, size: 16),
                                                  SizedBox(width: 4),
                                                  Text('Remove'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isUploading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}