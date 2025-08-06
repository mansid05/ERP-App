import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailOrIdController = TextEditingController();
  final _passwordController = TextEditingController();
  String _error = '';
  bool _isLoading = false;
  bool _showPassword = false;
  String _activeField = '';

  static const String _baseUrl = 'http://192.168.1.22:5000';

  @override
  void dispose() {
    _emailOrIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _error = '';
      _isLoading = true;
    });

    try {
      final body = _emailOrIdController.text.contains('@')
          ? {'email': _emailOrIdController.text, 'password': _passwordController.text}
          : {'employeeId': _emailOrIdController.text, 'password': _passwordController.text};

      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          data['message'] ?? data['error'] ?? 'Login failed: ${response.reasonPhrase}',
        );
      }

      await Future.delayed(const Duration(milliseconds: 800));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', data['token']);
      await prefs.setString('user', json.encode(data['user']));

      // Extract role from user data
      final String role = data['user']['role']?.toLowerCase() ?? 'teaching';

      // Determine the route based on role
      String route;
      switch (role) {
        case 'principal':
          route = '/principal';
          break;
        case 'hod':
          route = '/hod';
          break;
        case 'cc':
          route = '/user_navigation';
          break;
        case 'facultymanagement':
        case 'teaching':
          route = '/user_navigation';
          break;
        case 'non-teaching':
          route = '/non-teaching';
          break;
        case 'driver':
          route = '/driver';
          break;
        case 'conductor':
          route = '/conductor';
          break;
        default:
          setState(() {
            _error = 'Unknown role: $role. Please contact support.';
            _isLoading = false;
          });
          return;
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, route, arguments: data['user']);
      }
    } catch (err) {
      setState(() {
        _error = err.toString().contains('Invalid credentials')
            ? 'Invalid Employee ID/Email or password. Please try again.'
            : err.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25,
            left: MediaQuery.of(context).size.width * 0.25,
            child: Container(
              width: 384,
              height: 384,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x33A78BFA),
                boxShadow: [BoxShadow(blurRadius: 48, color: Colors.black.withOpacity(0.1))],
              ),
              child: AnimatedOpacity(
                opacity: 0.7,
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                child: Container(),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25,
            right: MediaQuery.of(context).size.width * 0.25,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x33BFDBFE),
                boxShadow: [BoxShadow(blurRadius: 48, color: Colors.black.withOpacity(0.1))],
              ),
              child: AnimatedOpacity(
                opacity: 0.7,
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                child: Container(),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5,
            left: MediaQuery.of(context).size.width * 0.5,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x33C7D2FE),
                boxShadow: [BoxShadow(blurRadius: 32, color: Colors.black.withOpacity(0.1))],
              ),
              child: AnimatedOpacity(
                opacity: 0.7,
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                child: Container(),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF1F2937), Color(0xFF7C3AED), Color(0xFF4F46E5)],
                          ).createShader(bounds),
                          child: const Text(
                            'Faculty Portal',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Welcome back! Please sign in to continue',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4B5563),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFEF2F2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFEF4444),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error,
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        TextField(
                          controller: _emailOrIdController,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 16, right: 8),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _activeField == 'emailOrId'
                                      ? const Color(0xFFE0E7FF)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: _activeField == 'emailOrId'
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFF6B7280),
                                  size: 20,
                                ),
                              ),
                            ),
                            labelText: 'Employee ID or Email',
                            labelStyle: TextStyle(
                              color: _activeField == 'emailOrId' || _emailOrIdController.text.isNotEmpty
                                  ? Colors.transparent
                                  : const Color(0xFF6B7280),
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                          ),
                          onTap: () {
                            setState(() {
                              _activeField = 'emailOrId';
                            });
                          },
                          onEditingComplete: () {
                            setState(() {
                              _activeField = '';
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 16, right: 8),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _activeField == 'password'
                                      ? const Color(0xFFE0E7FF)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.lock,
                                  color: _activeField == 'password'
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFF6B7280),
                                  size: 20,
                                ),
                              ),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                              icon: Icon(
                                _showPassword ? Icons.visibility : Icons.visibility_off,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            labelText: 'Password',
                            labelStyle: TextStyle(
                              color: _activeField == 'password' || _passwordController.text.isNotEmpty
                                  ? Colors.transparent
                                  : const Color(0xFF6B7280),
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                          ),
                          onTap: () {
                            setState(() {
                              _activeField = 'password';
                            });
                          },
                          onEditingComplete: () {
                            setState(() {
                              _activeField = '';
                            });
                          },
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isLoading
                                      ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
                                      : [
                                    const Color(0xFF4F46E5),
                                    const Color(0xFF7C3AED),
                                    const Color(0xFF4F46E5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  if (!_isLoading)
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED).withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isLoading)
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.login,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isLoading ? 'Authenticating...' : 'Sign In',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!_isLoading) ...[
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Secure access to your faculty dashboard',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}