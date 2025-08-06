import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../models/status_data.dart';
import '../models/employee_profile.dart';
import '../services/api_service.dart';

class DashboardProvider with ChangeNotifier {
  DashboardData? _dashboardData;
  StatusData? _statusData;
  EmployeeProfile? _selectedEmployee;
  bool _loading = true;
  String _error = '';
  String _selectedFY = '2024-2025';

  DashboardData? get dashboardData => _dashboardData;
  StatusData? get statusData => _statusData;
  EmployeeProfile? get selectedEmployee => _selectedEmployee;
  bool get loading => _loading;
  String get error => _error;
  String get selectedFY => _selectedFY;

  final ApiService _apiService = ApiService();

  DashboardProvider() {
    fetchData();
  }

  void setFinancialYear(String fy) {
    _selectedFY = fy;
    fetchData();
  }

  Future<void> fetchData() async {
    _loading = true;
    notifyListeners();

    try {
      final dashboardData = await _apiService.fetchDashboardData(_selectedFY);
      final statusData = await _apiService.fetchStatusData(_selectedFY);
      _dashboardData = dashboardData;
      _statusData = statusData;
      _error = '';
    } catch (e) {
      _error = e.toString();
      _dashboardData = DashboardData(
        summary: Summary(
          totalEmployees: 0,
          totalSalaryPaid: 0,
          employeesWithPF: 0,
          employeesWithIncomeTax: 0,
          fullyCompliantEmployees: 0,
          pendingPayments: 0,
          complianceRate: 0,
        ),
        facultyData: [],
      );
      _statusData = StatusData(
        totalPaid: 0,
        pf: PFStatus(totalEmployeePF: 0, totalEmployerPF: 0, records: 0),
        incomeTax: IncomeTaxStatus(totalLiability: 0, records: 0),
        compliance: Compliance(totalEmployees: 0, pfCompliant: 0),
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchEmployeeProfile(String employeeName) async {
    try {
      _selectedEmployee = await _apiService.fetchEmployeeProfile(
          employeeName, _selectedFY);
      _error = '';
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> autoGeneratePF(String employeeName) async {
    try {
      await _apiService.autoGeneratePF(employeeName, _selectedFY);
      await fetchData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> bulkGeneratePF() async {
    try {
      final result = await _apiService.bulkGeneratePF(_selectedFY);
      await fetchData();
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearSelectedEmployee() {
    _selectedEmployee = null;
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}