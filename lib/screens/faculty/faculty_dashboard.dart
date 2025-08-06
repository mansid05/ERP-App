import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../utils/role_permissions_and_routes.dart';

class FacultyDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FacultyDashboard({Key? key, required this.userData}) : super(key: key);

  @override
  _FacultyDashboardState createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  Map<String, dynamic>? dashboardData;
  Map<String, dynamic>? statusData;
  bool isLoading = true;
  String error = '';
  String selectedFY = '2024-2025';
  Map<String, dynamic>? selectedEmployee;
  bool showEmployeeModal = false;
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
    fetchStatusData();
  }

  Future<void> fetchDashboardData() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token == null) {
        setState(() {
          error = 'No authentication token found';
          isLoading = false;
        });
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/faculty/dashboard/data?financialYear=$selectedFY'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        await prefs.remove('authToken');
        await FlutterSecureStorage().delete(key: 'authToken');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('HTTP error! status: ${response.statusCode}');
      }

      setState(() {
        dashboardData = jsonDecode(response.body);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error fetching dashboard data: $e';
        dashboardData = {
          'summary': {
            'totalEmployees': 0,
            'totalSalaryPaid': 0,
            'employeesWithPF': 0,
            'employeesWithIncomeTax': 0,
            'fullyCompliantEmployees': 0,
            'pendingPayments': 0,
            'complianceRate': 0,
          },
          'facultyData': [],
        };
        isLoading = false;
      });
    }
  }

  Future<void> fetchStatusData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token == null) {
        setState(() => error = 'No authentication token found');
        return;
      }

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/faculty/dashboard/status?financialYear=$selectedFY'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        await prefs.remove('authToken');
        await FlutterSecureStorage().delete(key: 'authToken');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('HTTP error! status: ${response.statusCode}');
      }

      setState(() => statusData = jsonDecode(response.body));
    } catch (e) {
      setState(() {
        error = 'Error fetching status data: $e';
        statusData = {
          'totalPaid': 0,
          'pf': {'totalEmployeePF': 0, 'totalEmployerPF': 0, 'records': 0},
          'incomeTax': {'totalLiability': 0, 'records': 0},
          'compliance': {'totalEmployees': 0, 'pfCompliant': 0},
        };
      });
    }
  }

  Future<void> handleEmployeeClick(String employeeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/faculty/employee/${Uri.encodeComponent(employeeName)}/profile?financialYear=$selectedFY'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          selectedEmployee = jsonDecode(response.body);
          showEmployeeModal = true;
        });
      } else {
        setState(() => error = 'Error fetching employee profile: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => error = 'Error fetching employee profile: $e');
    }
  }

  Future<void> handleAutoGeneratePF(String employeeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/faculty/employee/${Uri.encodeComponent(employeeName)}/auto-generate-pf'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'financialYear': selectedFY, 'ptState': 'Karnataka'}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PF record generated successfully!')),
        );
        await fetchDashboardData();
        await fetchStatusData();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${errorData['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PF record: $e')),
      );
    }
  }

  Future<void> handleBulkGeneratePF() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Bulk PF Generation'),
        content: Text('This will generate PF records for all employees with salary data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/faculty/bulk-operations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'operation': 'generate-all-pf',
          'financialYear': selectedFY,
          'ptState': 'Karnataka',
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final successCount = result['results'].where((r) => r['status'] == 'created').length;
        final skipCount = result['results'].where((r) => r['status'] == 'skipped').length;
        final errorCount = result['results'].where((r) => r['status'] == 'error').length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bulk PF generation completed!\n$successCount created, $skipCount skipped, $errorCount errors',
            ),
          ),
        );
        await fetchDashboardData();
        await fetchStatusData();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${errorData['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error in bulk operation: $e')),
      );
    }
  }

  Color getComplianceColor(bool isCompliant) {
    return isCompliant ? Colors.green.shade100 : Colors.red.shade100;
  }

  String getComplianceText(Map<String, dynamic> employee) {
    if (employee['hasCompleteData'] == true) return 'Fully Compliant';
    if (employee['pf'] != null && employee['incomeTax'] != null) return 'Complete';
    if (employee['pf'] != null || employee['incomeTax'] != null) return 'Partial';
    return 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Faculty Management Dashboard'),
        backgroundColor: Colors.blue.shade600,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: FacultyManagementSidebar(
        handleMenuClick: (item) {
          Navigator.pushNamed(context, item['href']);
          Scaffold.of(context).closeDrawer();
        },
        userData: widget.userData,
      ),
      body: Stack(
        children: [
          isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Faculty Management Dashboard 👨‍🏫',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Comprehensive view of salary, PF, and income tax management',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                SizedBox(height: 16),
                // Controls
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text('Financial Year:', style: TextStyle(fontWeight: FontWeight.w500)),
                            SizedBox(width: 8),
                            DropdownButton<String>(
                              value: selectedFY,
                              items: ['2024-2025', '2023-2024', '2022-2023']
                                  .map((fy) => DropdownMenuItem(value: fy, child: Text(fy)))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedFY = value!;
                                  fetchDashboardData();
                                  fetchStatusData();
                                });
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: handleBulkGeneratePF,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600),
                              child: Text('Bulk Generate PF'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pushNamed(context, '/dashboard/payment'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600),
                              child: Text('Manage Salaries'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pushNamed(context, '/dashboard/faculty-profile'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                              child: Text('Manage PF'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pushNamed(context, '/dashboard/faculty-profile'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600),
                              child: Text('Manage Income Tax'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Summary Statistics
                if (statusData != null)
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        title: 'Total Salary Paid',
                        value: currencyFormat.format(statusData!['totalPaid'] ?? 0),
                        icon: Icons.attach_money,
                        color: Colors.green.shade600,
                      ),
                      _buildStatCard(
                        title: 'PF Contributions',
                        value: currencyFormat.format((statusData!['pf']?['totalEmployeePF'] ?? 0) + (statusData!['pf']?['totalEmployerPF'] ?? 0)),
                        subtitle: '${statusData!['pf']?['records'] ?? 0} employees',
                        icon: Icons.account_balance,
                        color: Colors.blue.shade600,
                      ),
                      _buildStatCard(
                        title: 'Income Tax',
                        value: currencyFormat.format(statusData!['incomeTax']?['totalLiability'] ?? 0),
                        subtitle: '${statusData!['incomeTax']?['records'] ?? 0} records',
                        icon: Icons.description,
                        color: Colors.red.shade600,
                      ),
                      _buildStatCard(
                        title: 'Compliance Rate',
                        value: '${(statusData!['compliance']?['totalEmployees'] ?? 0) > 0 ? ((statusData!['compliance']?['pfCompliant'] ?? 0) / (statusData!['compliance']?['totalEmployees'] ?? 1) * 100).round() : 0}%',
                        subtitle: '${statusData!['compliance']?['pfCompliant'] ?? 0}/${statusData!['compliance']?['totalEmployees'] ?? 0}',
                        icon: Icons.check_circle,
                        color: Colors.purple.shade600,
                      ),
                    ],
                  ),
                SizedBox(height: 16),
                // Overview Cards
                if (dashboardData != null)
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 1,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildOverviewCard(
                        title: '📊 Faculty Overview',
                        items: [
                          {'label': 'Total Employees', 'value': '${dashboardData!['summary']?['totalEmployees'] ?? 0}'},
                          {
                            'label': 'Total Salary Paid',
                            'value': currencyFormat.format(dashboardData!['summary']?['totalSalaryPaid'] ?? 0),
                          },
                          {
                            'label': 'Avg Salary',
                            'value': currencyFormat.format(
                              dashboardData!['summary']?['totalEmployees'] > 0
                                  ? (dashboardData!['summary']['totalSalaryPaid'] ?? 0) / dashboardData!['summary']['totalEmployees']
                                  : 0,
                            ),
                          },
                        ],
                        gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.cyan.shade50]),
                      ),
                      _buildOverviewCard(
                        title: '🏦 PF Status',
                        items: [
                          {'label': 'Employees with PF', 'value': '${dashboardData!['summary']?['employeesWithPF'] ?? 0}'},
                          {
                            'label': 'Coverage',
                            'value': '${dashboardData!['summary']?['totalEmployees'] > 0 ? ((dashboardData!['summary']['employeesWithPF'] ?? 0) / dashboardData!['summary']['totalEmployees'] * 100).round() : 0}%',
                          },
                          {
                            'label': 'Pending PF',
                            'value': '${(dashboardData!['summary']?['totalEmployees'] ?? 0) - (dashboardData!['summary']?['employeesWithPF'] ?? 0)}',
                          },
                        ],
                        gradient: LinearGradient(colors: [Colors.green.shade50, Colors.green.shade50]),
                      ),
                      _buildOverviewCard(
                        title: '📋 Tax Compliance',
                        items: [
                          {'label': 'Income Tax Records', 'value': '${dashboardData!['summary']?['employeesWithIncomeTax'] ?? 0}'},
                          {'label': 'Fully Compliant', 'value': '${dashboardData!['summary']?['fullyCompliantEmployees'] ?? 0}'},
                          {
                            'label': 'Compliance Rate',
                            'value': '${dashboardData!['summary']?['totalEmployees'] > 0 ? ((dashboardData!['summary']['fullyCompliantEmployees'] ?? 0) / dashboardData!['summary']['totalEmployees'] * 100).round() : 0}%',
                          },
                        ],
                        gradient: LinearGradient(colors: [Colors.orange.shade50, Colors.red.shade50]),
                      ),
                    ],
                  ),
                SizedBox(height: 16),
                // Error Message
                if (error.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border(left: BorderSide(color: Colors.red.shade400, width: 4)),
                    ),
                    child: Text(error, style: TextStyle(color: Colors.red.shade700)),
                  ),
                SizedBox(height: 16),
                // Employee List
                if (dashboardData != null)
                  Card(
                    elevation: 2,
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Faculty Members',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (dashboardData!['facultyData'] == null || dashboardData!['facultyData'].isEmpty)
                          Padding(
                            padding: EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Text('👨‍🏫', style: TextStyle(fontSize: 24, color: Colors.grey.shade500)),
                                Text('No faculty data found', style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                DataColumn(label: Text('Employee Details')),
                                DataColumn(label: Text('Salary Info')),
                                DataColumn(label: Text('PF Status')),
                                DataColumn(label: Text('Income Tax')),
                                DataColumn(label: Text('Compliance')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: (dashboardData!['facultyData'] as List<dynamic>).asMap().entries.map((entry) {
                                final employee = entry.value;
                                return DataRow(cells: [
                                  DataCell(Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(employee['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w500)),
                                      Text('Records: ${employee['recordCount'] ?? 0}', style: TextStyle(color: Colors.grey.shade500)),
                                    ],
                                  )),
                                  DataCell(Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(currencyFormat.format(employee['totalSalary'] ?? 0), style: TextStyle(fontWeight: FontWeight.w500)),
                                      Text(
                                        'Avg: ${currencyFormat.format(employee['recordCount'] > 0 ? (employee['totalSalary'] ?? 0) / employee['recordCount'] : 0)}',
                                        style: TextStyle(color: Colors.grey.shade500),
                                      ),
                                    ],
                                  )),
                                  DataCell(employee['pf'] != null
                                      ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(currencyFormat.format(employee['pf']['totalPFContribution'] ?? 0), style: TextStyle(color: Colors.green.shade600)),
                                      Text('PF: ${employee['pf']['pfNumber']}', style: TextStyle(color: Colors.grey.shade500)),
                                    ],
                                  )
                                      : Text('Not Generated', style: TextStyle(color: Colors.red.shade600))),
                                  DataCell(employee['incomeTax'] != null
                                      ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(currencyFormat.format(employee['incomeTax']['totalTax'] ?? 0), style: TextStyle(color: Colors.red.shade600)),
                                      Text('FY: ${employee['incomeTax']['financialYear']}', style: TextStyle(color: Colors.grey.shade500)),
                                    ],
                                  )
                                      : Text('Pending', style: TextStyle(color: Colors.orange.shade600))),
                                  DataCell(Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: getComplianceColor(employee['hasCompleteData'] ?? false),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      getComplianceText(employee),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  )),
                                  DataCell(Row(
                                    children: [
                                      TextButton(
                                        onPressed: () => handleEmployeeClick(employee['name']),
                                        child: Text('View', style: TextStyle(color: Colors.blue.shade600)),
                                      ),
                                      if (employee['pf'] == null)
                                        TextButton(
                                          onPressed: () => handleAutoGeneratePF(employee['name']),
                                          child: Text('Generate PF', style: TextStyle(color: Colors.green.shade600)),
                                        ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Employee Profile Modal
          if (showEmployeeModal && selectedEmployee != null)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(maxWidth: 800, maxHeight: MediaQuery.of(context).size.height * 0.9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 8)],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Employee Profile: ${selectedEmployee!['employeeName']}',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () => setState(() => showEmployeeModal = false),
                            icon: Icon(Icons.close),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 1,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                        children: [
                          _buildProfileCard(
                            title: '💰 Salary Information',
                            items: [
                              {'label': 'Total Annual', 'value': currencyFormat.format(selectedEmployee!['salary']['totalAnnual'])},
                              {'label': 'Monthly Average', 'value': currencyFormat.format(selectedEmployee!['salary']['monthlyAverage'])},
                              {'label': 'Records', 'value': '${selectedEmployee!['salary']['recordCount']}'},
                            ],
                            backgroundColor: Colors.blue.shade50,
                          ),
                          _buildProfileCard(
                            title: '🏦 PF Information',
                            items: selectedEmployee!['pf'] != null
                                ? [
                              {'label': 'PF Number', 'value': selectedEmployee!['pf']['pfNumber']},
                              {'label': 'Employee PF', 'value': currencyFormat.format(selectedEmployee!['pf']['employeePFContribution'])},
                              {'label': 'Employer PF', 'value': currencyFormat.format(selectedEmployee!['pf']['employerPFContribution'])},
                              {'label': 'Professional Tax', 'value': currencyFormat.format(selectedEmployee!['pf']['professionalTax'])},
                            ]
                                : [{'label': '', 'value': 'No PF record found'}],
                            backgroundColor: Colors.green.shade50,
                          ),
                          _buildProfileCard(
                            title: '📋 Income Tax',
                            items: selectedEmployee!['incomeTax'] != null
                                ? [
                              {'label': 'PAN', 'value': selectedEmployee!['incomeTax']['panNumber']},
                              {'label': 'Gross Income', 'value': currencyFormat.format(selectedEmployee!['incomeTax']['grossIncome'] ?? 0)},
                              {'label': 'Tax Liability', 'value': currencyFormat.format(selectedEmployee!['incomeTax']['totalTax'] ?? 0)},
                              {'label': 'TDS Deducted', 'value': currencyFormat.format(selectedEmployee!['incomeTax']['tdsDeducted'] ?? 0)},
                            ]
                                : [{'label': '', 'value': 'No income tax record found'}],
                            backgroundColor: Colors.orange.shade50,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('✅ Compliance Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            GridView.count(
                              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.5,
                              children: [
                                _buildComplianceItem(
                                  title: 'Salary Data',
                                  status: selectedEmployee!['compliance']['hasSalaryData'] ? 'Available' : 'Missing',
                                  isCompliant: selectedEmployee!['compliance']['hasSalaryData'],
                                ),
                                _buildComplianceItem(
                                  title: 'PF Record',
                                  status: selectedEmployee!['compliance']['hasPFData'] ? 'Generated' : 'Pending',
                                  isCompliant: selectedEmployee!['compliance']['hasPFData'],
                                ),
                                _buildComplianceItem(
                                  title: 'Income Tax',
                                  status: selectedEmployee!['compliance']['hasIncomeTaxData'] ? 'Filed' : 'Pending',
                                  isCompliant: selectedEmployee!['compliance']['hasIncomeTaxData'],
                                ),
                                _buildComplianceItem(
                                  title: 'Overall',
                                  status: selectedEmployee!['compliance']['isFullyCompliant'] ? 'Compliant' : 'In Progress',
                                  isCompliant: selectedEmployee!['compliance']['isFullyCompliant'],
                                  altColor: selectedEmployee!['compliance']['isFullyCompliant'] ? Colors.green.shade100 : Colors.yellow.shade100,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => showEmployeeModal = false),
                            child: Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                  if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(icon, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required List<Map<String, String>> items,
    required LinearGradient gradient,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(gradient: gradient),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['label']!, style: TextStyle(color: Colors.grey.shade700)),
                  Text(item['value']!, style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String title,
    required List<Map<String, String>> items,
    required Color backgroundColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          ...items.map((item) => item['label']!.isEmpty
              ? Text(item['value']!, style: TextStyle(color: Colors.grey.shade600))
              : Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['label']!),
                Text(item['value']!, style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildComplianceItem({
    required String title,
    required String status,
    required bool isCompliant,
    Color? altColor,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: altColor ?? (isCompliant ? Colors.green.shade100 : Colors.red.shade100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isCompliant ? Colors.green.shade800 : Colors.red.shade800)),
          Text(status, style: TextStyle(fontSize: 12, color: isCompliant ? Colors.green.shade600 : Colors.red.shade600)),
        ],
      ),
    );
  }
}

class FacultyManagementSidebar extends StatelessWidget {
  final Function(Map<String, dynamic>) handleMenuClick;
  final Map<String, dynamic> userData;

  const FacultyManagementSidebar({
    super.key,
    required this.handleMenuClick,
    required this.userData,
  });

  List<Map<String, dynamic>> _getMenuItems() {
    final role = userData['role']?.toLowerCase();
    return [
      {
        'title': 'Dashboard',
        'icon': Icons.home,
        'href': '/dashboard',
        'routeName': 'dashboard',
        'isSection': true,
        'sectionTitle': 'Main',
      },
      {
        'title': 'Add Faculty',
        'icon': Icons.person_add,
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
      {
        'title': 'Payment',
        'icon': Icons.payment,
        'href': '/dashboard/payment',
        'routeName': 'payment',
        'isSection': true,
        'sectionTitle': 'Financial',
      },
      {
        'title': 'Profile',
        'icon': Icons.person,
        'href': '/dashboard/faculty-profile',
        'routeName': 'faculty_profile',
        'isSection': true,
        'sectionTitle': 'Personal',
      },
      {
        'title': 'Payslip',
        'icon': Icons.receipt,
        'href': '/dashboard/payslip',
        'routeName': 'payslip',
      },
      {
        'title': 'Announcements',
        'icon': Icons.announcement,
        'href': '/dashboard/announcement',
        'routeName': 'announcement',
        'isSection': true,
        'sectionTitle': 'Communication',
      },
      {
        'title': 'Timetable',
        'icon': Icons.schedule,
        'href': '/dashboard/timetable',
        'routeName': 'timetable',
        'isSection': true,
        'sectionTitle': 'Academic',
      },
      {
        'title': 'Fetched Timetable',
        'icon': Icons.calendar_today,
        'href': '/dashboard/fetched-timetable',
        'routeName': 'fetched_timetable',
      },
      {
        'title': 'Apply Charge Handover',
        'icon': Icons.swap_horiz,
        'href': '/dashboard/applyChargeHandover',
        'routeName': 'apply_charge_handover',
        'isSection': true,
        'sectionTitle': 'Handover Management',
      },
      {
        'title': 'Approve Charge Handover',
        'icon': Icons.check_circle,
        'href': '/dashboard/approveChargeHandover',
        'routeName': 'approve_charge_handover',
      },
      {
        'title': 'Apply Leave',
        'icon': Icons.event_busy,
        'href': '/dashboard/applyleave',
        'routeName': 'apply_leave',
        'isSection': true,
        'sectionTitle': 'Leave Management',
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
    await SharedPreferences.getInstance().then((prefs) => prefs.remove('authToken'));
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
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
                                    colors: (ModalRoute.of(context)?.settings.name ?? '') == item['href']
                                        ? [Colors.blue[500]!.withOpacity(0.5), Colors.teal[500]!.withOpacity(0.5)]
                                        : [Colors.grey[500]!.withOpacity(0.5), Colors.grey[500]!.withOpacity(0.5)],
                                  ),
                                  boxShadow: [
                                    if ((ModalRoute.of(context)?.settings.name ?? '') == item['href'])
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
                              selected: (ModalRoute.of(context)?.settings.name ?? '') == item['href'],
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