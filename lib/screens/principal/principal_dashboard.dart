import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:erp_app/screens/side_bar.dart';
import 'models/dashboard_stats.dart';
import 'models/todo.dart';
import 'providers/principal_dashboard_provider.dart';

class PrincipalDashboard extends StatefulWidget {
  const PrincipalDashboard({Key? key, required userData}) : super(key: key);

  @override
  _PrincipalDashboardState createState() => _PrincipalDashboardState();
}

class _PrincipalDashboardState extends State<PrincipalDashboard> {
  bool _mobileMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PrincipalDashboardProvider(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Principal Dashboard'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              setState(() {
                _mobileMenuOpen = true;
              });
            },
          ),
        ),
        body: Stack(
          children: [
            Consumer<PrincipalDashboardProvider>(
              builder: (context, provider, child) {
                if (provider.loading) {
                  return const Center(
                    child: SpinKitCircle(
                      color: Colors.blue,
                      size: 50.0,
                    ),
                  );
                }

                if (provider.error.isNotEmpty) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Principal Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border: const Border(
                              left: BorderSide(color: Colors.redAccent, width: 4),
                            ),
                          ),
                          child: Text(
                            provider.error,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text(
                        'Principal Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Total Counts
                      _buildTotalCounts(context, provider.dashboardStats!),
                      const SizedBox(height: 16),

                      // Additional Stats
                      _buildAdditionalStats(context, provider.dashboardStats!),
                      const SizedBox(height: 16),

                      // Graph Section
                      _buildGraphSection(context, provider),
                      const SizedBox(height: 16),

                      // Todo List Section
                      _buildTodoSection(context, provider),
                      const SizedBox(height: 16),

                      // Timetables Section
                      _buildTimetablesSection(context, provider),
                    ],
                  ),
                );
              },
            ),
            if (_mobileMenuOpen)
              Sidebar(
                setSection: (section) {
                  setState(() {
                    _mobileMenuOpen = false;
                  });
                },
                isMobile: true,
                mobileMenuOpen: _mobileMenuOpen,
                setMobileMenuOpen: (open) {
                  setState(() {
                    _mobileMenuOpen = open;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCounts(BuildContext context, DashboardStats stats) {
    const int newHires = 5; // Mock data
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          title: 'Total Faculties',
          value: stats.totalFaculties.toString(),
          subtitle: 'Active faculty members',
          color: Colors.blue,
        ),
        _buildStatCard(
          title: 'Total Students',
          value: stats.totalStudents.toString(),
          subtitle: 'Enrolled students',
          color: Colors.green,
        ),
        _buildStatCard(
          title: 'New Hires',
          value: newHires.toString(),
          subtitle: 'Recent additions',
          color: Colors.orange,
        ),
        _buildStatCard(
          title: 'Departments',
          value: stats.totalDepartments.toString(),
          subtitle: 'Active departments',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalStats(BuildContext context, DashboardStats stats) {
    const int budgetUtilization = 75; // Mock data
    return GridView.count(
      crossAxisCount: 1,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pending Approvals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                stats.pendingApprovals.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const Text(
                'Requires your attention',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              _buildBreakdownItem('Leave Applications', stats.pendingApprovalsBreakdown.leaveApprovals),
              _buildBreakdownItem('OD Applications', stats.pendingApprovalsBreakdown.odLeaveApprovals),
              _buildBreakdownItem('Faculty Approvals', stats.pendingApprovalsBreakdown.facultyApprovals),
              if (stats.pendingApprovalsBreakdown.handoverApprovals > 0)
                _buildBreakdownItem('Handover Requests', stats.pendingApprovalsBreakdown.handoverApprovals),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Budget Utilization',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '$budgetUtilization%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: budgetUtilization / 100,
                backgroundColor: Colors.grey.shade200,
                color: Colors.indigo,
                minHeight: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphSection(BuildContext context, PrincipalDashboardProvider provider) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.amber,
      Colors.red,
      Colors.purple,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Department-wise Distribution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.filter_list, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: provider.graphFilter,
                    onChanged: (value) {
                      if (value != null) {
                        provider.setGraphFilter(value);
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'Faculties', child: Text('Faculties')),
                      DropdownMenuItem(value: 'Students', child: Text('Students')),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bar Chart
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: provider.dashboardStats!.departmentWiseData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dept = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: (provider.graphFilter == 'Faculties' ? dept.faculties : dept.students).toDouble(),
                        color: provider.graphFilter == 'Faculties' ? Colors.blue : Colors.green,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < provider.dashboardStats!.departmentWiseData.length) {
                          return Text(
                            provider.dashboardStats!.departmentWiseData[index].name,
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.center,
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Pie Chart
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: provider.dashboardStats!.departmentWiseData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dept = entry.value;
                  return PieChartSectionData(
                    value: (provider.graphFilter == 'Faculties' ? dept.faculties : dept.students).toDouble(),
                    title: dept.name,
                    color: colors[index % colors.length],
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoSection(BuildContext context, PrincipalDashboardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Tasks Management',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: provider.toggleShowAddTodo,
                child: const Text('Add Task', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Todo Stats
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildTodoStatCard('Total', provider.todoStats!.total, Colors.grey),
              _buildTodoStatCard('Pending', provider.todoStats!.pending, Colors.yellow),
              _buildTodoStatCard('In Progress', provider.todoStats!.inProgress, Colors.blue),
              _buildTodoStatCard('Completed', provider.todoStats!.completed, Colors.green),
              _buildTodoStatCard('Overdue', provider.todoStats!.overdue, Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          // Add Todo Form
          if (provider.showAddTodo)
            _buildAddTodoForm(context, provider),
          // Todo List
          if (provider.todos.isEmpty)
            const Column(
              children: [
                Icon(Icons.access_time, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No tasks yet. Add your first task to get started!', style: TextStyle(color: Colors.grey)),
              ],
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.todos.length,
              itemBuilder: (context, index) {
                final todo = provider.todos[index];
                return _buildTodoItem(context, provider, todo);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTodoStatCard(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTodoForm(BuildContext context, PrincipalDashboardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Add New Task',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
              hintText: 'Enter task title',
            ),
            onChanged: (value) {
              provider.updateNewTodo(provider.newTodo.copyWith(title: value));
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Priority',
              border: OutlineInputBorder(),
            ),
            value: provider.newTodo.priority,
            items: const [
              DropdownMenuItem(value: 'Low', child: Text('Low')),
              DropdownMenuItem(value: 'Medium', child: Text('Medium')),
              DropdownMenuItem(value: 'High', child: Text('High')),
              DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
            ],
            onChanged: (value) {
              if (value != null) {
                provider.updateNewTodo(provider.newTodo.copyWith(priority: value));
              }
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            value: provider.newTodo.category,
            items: const [
              DropdownMenuItem(value: 'Administrative', child: Text('Administrative')),
              DropdownMenuItem(value: 'Academic', child: Text('Academic')),
              DropdownMenuItem(value: 'Meeting', child: Text('Meeting')),
              DropdownMenuItem(value: 'Review', child: Text('Review')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              if (value != null) {
                provider.updateNewTodo(provider.newTodo.copyWith(category: value));
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Assigned To',
              border: OutlineInputBorder(),
              hintText: 'Employee ID or Name',
            ),
            onChanged: (value) {
              provider.updateNewTodo(provider.newTodo.copyWith(assignedTo: value));
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Department',
              border: OutlineInputBorder(),
            ),
            value: provider.newTodo.department.isEmpty ? null : provider.newTodo.department,
            items: provider.dashboardStats!.departmentWiseData
                .map((dept) => DropdownMenuItem(value: dept.name, child: Text(dept.name)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                provider.updateNewTodo(provider.newTodo.copyWith(department: value));
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Due Date',
              border: OutlineInputBorder(),
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: provider.newTodo.dueDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                provider.updateNewTodo(provider.newTodo.copyWith(dueDate: date));
              }
            },
            controller: TextEditingController(
              text: DateFormat('yyyy-MM-dd').format(provider.newTodo.dueDate),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              hintText: 'Enter task description',
            ),
            maxLines: 2,
            onChanged: (value) {
              provider.updateNewTodo(provider.newTodo.copyWith(description: value));
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: provider.toggleShowAddTodo,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: provider.newTodo.title.isEmpty ||
                    provider.newTodo.assignedTo.isEmpty ||
                    provider.newTodo.department.isEmpty
                    ? null
                    : provider.addTodo,
                child: const Text('Add Task'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(BuildContext context, PrincipalDashboardProvider provider, Todo todo) {
    Color getPriorityColor(String priority) {
      switch (priority) {
        case 'Urgent':
          return Colors.red;
        case 'High':
          return Colors.orange;
        case 'Medium':
          return Colors.yellow;
        case 'Low':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    Color getStatusColor(String status) {
      switch (status) {
        case 'Completed':
          return Colors.green;
        case 'In Progress':
          return Colors.blue;
        case 'Pending':
          return Colors.grey;
        case 'Cancelled':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  todo.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (todo.status != 'Completed') ...[
                IconButton(
                  icon: const Icon(Icons.access_time, size: 16, color: Colors.blue),
                  onPressed: () => provider.updateTodo(todo.id, 'In Progress'),
                ),
                IconButton(
                  icon: const Icon(Icons.check, size: 16, color: Colors.green),
                  onPressed: () => provider.updateTodo(todo.id, 'Completed'),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                onPressed: () => provider.deleteTodo(todo.id),
              ),
            ],
          ),
          if (todo.description != null && todo.description!.isNotEmpty)
            Text(
              todo.description!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text(todo.priority, style: const TextStyle(fontSize: 12)),
                backgroundColor: getPriorityColor(todo.priority).withOpacity(0.1),
                labelStyle: TextStyle(color: getPriorityColor(todo.priority)),
              ),
              Chip(
                label: Text(todo.status, style: const TextStyle(fontSize: 12)),
                backgroundColor: getStatusColor(todo.status).withOpacity(0.1),
                labelStyle: TextStyle(color: getStatusColor(todo.status)),
              ),
              Chip(
                label: Text(todo.category, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.grey.withOpacity(0.1),
              ),
              Chip(
                label: Text(todo.department, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.blue.withOpacity(0.1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Assigned to: ${todo.assignedTo}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 16),
              Text(
                'Due: ${DateFormat('dd/MM/yyyy').format(todo.dueDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimetablesSection(BuildContext context, PrincipalDashboardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Department Timetables',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: provider.toggleShowTimetables,
                child: Text(
                  provider.showTimetables ? 'Hide' : 'View',
                  style: const TextStyle(color: Colors.indigo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Timetables Summary Stats
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildTimetableStatCard(
                'Total Timetables',
                provider.timetableSummary!.totalTimetables,
                Colors.indigo,
              ),
              _buildTimetableStatCard(
                'Departments',
                provider.timetableSummary!.totalDepartments,
                Colors.purple,
              ),
              _buildTimetableStatCard(
                'Total Semesters',
                provider.timetableSummary!.departmentBreakdown.fold<int>(
                  0,
                      (sum, dept) => sum + dept.semesters,
                ),
                Colors.pink,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Department Breakdown
          GridView.count(
            crossAxisCount: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: provider.timetableSummary!.departmentBreakdown.map((dept) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dept.department,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _buildBreakdownItem('Timetables', dept.count),
                    _buildBreakdownItem('Semesters', dept.semesters),
                    _buildBreakdownItem('Sections', dept.sections),
                  ],
                ),
              );
            }).toList(),
          ),
          if (provider.showTimetables) ...[
            const SizedBox(height: 16),
            const Text(
              'Detailed Timetables by Department',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (provider.timetablesByDepartment.isEmpty)
              const Column(
                children: [
                  Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No timetables found', style: TextStyle(color: Colors.grey)),
                ],
              )
            else
              ...provider.timetablesByDepartment.keys.map((department) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Text(
                            department,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: provider.timetablesByDepartment[department]!.map((timetable) {
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _buildBreakdownItem('Semester', timetable.semester),
                                _buildBreakdownItem('Section', timetable.section),
                                _buildBreakdownItem('Year', timetable.year),
                                _buildBreakdownItem(
                                  'Created',
                                  DateFormat('dd/MM/yyyy').format(timetable.createdAt),
                                ),
                                _buildBreakdownItem(
                                  'Modified',
                                  DateFormat('dd/MM/yyyy').format(timetable.lastModified),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _buildTimetableStatCard(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}