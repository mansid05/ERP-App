import 'package:erp_app/screens/course_coordinator/user_navigation.dart';
import 'package:erp_app/screens/faculty/faculty_navigation.dart';
import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'screens/faculty/faculty_dashboard.dart';
import 'screens/principal/principal_dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/faculty_navigation': (context) => FacultyNavigation(),
        '/user_navigation': (context) => UserNavigation(),
        '/dashboard': (context) => FacultyDashboard(
          userData: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
        ),
        '/principal': (context) => PrincipalDashboard(
          userData: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
        ),
        // '/hod': (context) => HODDashboard(
        //   userData: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
        // ),
        // '/cc': (context) => CCDashboard(
        //   userData: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
        // ),
        // '/non-teaching': (context) => NonTeachingDashboard(
        //   userData: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
        // ),
        // '/driver': (context) => DriverDashboard(
        //   userData: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
        // ),
        // '/conductor': (context) => ConductorDashboard(
        //   userData: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
        // ),
      },
    );
  }
}