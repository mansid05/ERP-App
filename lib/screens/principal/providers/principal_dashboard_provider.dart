import 'package:flutter/material.dart';
import '../models/dashboard_stats.dart';
import '../models/todo.dart';
import '../models/timetable.dart';
import '../services/api_service.dart';

class PrincipalDashboardProvider with ChangeNotifier {
  DashboardStats? _dashboardStats;
  List<Todo> _todos = [];
  TodoStats? _todoStats;
  TimetableSummary? _timetableSummary;
  Map<String, List<Timetable>> _timetablesByDepartment = {};
  List<Timetable> _allTimetables = [];
  bool _loading = true;
  String _error = '';
  String _graphFilter = 'Faculties';
  bool _showTimetables = false;
  bool _showAddTodo = false;
  Todo _newTodo = Todo(
    id: '',
    title: '',
    priority: 'Medium',
    status: 'Pending',
    category: 'Administrative',
    assignedTo: '',
    department: '',
    dueDate: DateTime.now(),
  );

  DashboardStats? get dashboardStats => _dashboardStats;
  List<Todo> get todos => _todos;
  TodoStats? get todoStats => _todoStats;
  TimetableSummary? get timetableSummary => _timetableSummary;
  Map<String, List<Timetable>> get timetablesByDepartment => _timetablesByDepartment;
  List<Timetable> get allTimetables => _allTimetables;
  bool get loading => _loading;
  String get error => _error;
  String get graphFilter => _graphFilter;
  bool get showTimetables => _showTimetables;
  bool get showAddTodo => _showAddTodo;
  Todo get newTodo => _newTodo;

  final ApiService _apiService = ApiService();

  PrincipalDashboardProvider() {
    fetchData();
  }

  void setGraphFilter(String filter) {
    _graphFilter = filter;
    notifyListeners();
  }

  void toggleShowTimetables() {
    _showTimetables = !_showTimetables;
    notifyListeners();
  }

  void toggleShowAddTodo() {
    _showAddTodo = !_showAddTodo;
    notifyListeners();
  }

  void updateNewTodo(Todo todo) {
    _newTodo = todo;
    notifyListeners();
  }

  Future<void> fetchData() async {
    _loading = true;
    notifyListeners();

    try {
      final dashboardData = await _apiService.fetchDashboardData();
      final timetablesData = await _apiService.fetchTimetablesData();
      final todosData = await _apiService.fetchTodosData();

      _dashboardStats = DashboardStats.fromJson(dashboardData);
      _timetableSummary = TimetableSummary.fromJson(timetablesData['summary'] ?? {});
      _timetablesByDepartment = (timetablesData['timetablesByDepartment'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
          key,
          (value as List<dynamic>).map((e) => Timetable.fromJson(e)).toList(),
        ),
      ) ??
          {};
      _allTimetables = (timetablesData['allTimetables'] as List<dynamic>?)?.map((e) => Timetable.fromJson(e)).toList() ?? [];
      _todos = (todosData['todos'] as List<dynamic>?)?.map((e) => Todo.fromJson(e)).toList() ?? [];
      _todoStats = TodoStats.fromJson(todosData['stats'] ?? {});
      _error = '';
    } catch (e) {
      _error = e.toString();
      _dashboardStats = DashboardStats(
        totalFaculties: 0,
        totalStudents: 0,
        totalDepartments: 0,
        departmentWiseData: [],
        pendingApprovals: 0,
        pendingApprovalsBreakdown: PendingApprovalsBreakdown(
          leaveApprovals: 0,
          odLeaveApprovals: 0,
          facultyApprovals: 0,
          handoverApprovals: 0,
        ),
      );
      _timetableSummary = TimetableSummary(
        totalTimetables: 0,
        totalDepartments: 0,
        departmentBreakdown: [],
      );
      _timetablesByDepartment = {};
      _allTimetables = [];
      _todos = [];
      _todoStats = TodoStats(
        total: 0,
        pending: 0,
        inProgress: 0,
        completed: 0,
        overdue: 0,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addTodo() async {
    try {
      final todo = await _apiService.addTodo(_newTodo);
      _todos = [todo, ..._todos];
      _todoStats = TodoStats(
        total: _todoStats!.total + 1,
        pending: _todoStats!.pending + 1,
        inProgress: _todoStats!.inProgress,
        completed: _todoStats!.completed,
        overdue: _todoStats!.overdue,
      );
      _newTodo = Todo(
        id: '',
        title: '',
        priority: 'Medium',
        status: 'Pending',
        category: 'Administrative',
        assignedTo: '',
        department: '',
        dueDate: DateTime.now(),
      );
      _showAddTodo = false;
      _error = '';
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateTodo(String id, String status) async {
    try {
      final updatedTodo = await _apiService.updateTodo(id, status);
      final oldTodo = _todos.firstWhere((t) => t.id == id);
      _todos = _todos.map((t) => t.id == id ? updatedTodo : t).toList();
      _todoStats = TodoStats(
        total: _todoStats!.total,
        pending: _todoStats!.pending - (oldTodo.status == 'Pending' ? 1 : 0) + (status == 'Pending' ? 1 : 0),
        inProgress: _todoStats!.inProgress - (oldTodo.status == 'In Progress' ? 1 : 0) + (status == 'In Progress' ? 1 : 0),
        completed: _todoStats!.completed - (oldTodo.status == 'Completed' ? 1 : 0) + (status == 'Completed' ? 1 : 0),
        overdue: _todoStats!.overdue - (oldTodo.status == 'Overdue' ? 1 : 0) + (status == 'Overdue' ? 1 : 0),
      );
      _error = '';
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteTodo(String id) async {
    try {
      await _apiService.deleteTodo(id);
      final deletedTodo = _todos.firstWhere((t) => t.id == id);
      _todos = _todos.where((t) => t.id != id).toList();
      _todoStats = TodoStats(
        total: _todoStats!.total - 1,
        pending: _todoStats!.pending - (deletedTodo.status == 'Pending' ? 1 : 0),
        inProgress: _todoStats!.inProgress - (deletedTodo.status == 'In Progress' ? 1 : 0),
        completed: _todoStats!.completed - (deletedTodo.status == 'Completed' ? 1 : 0),
        overdue: _todoStats!.overdue - (deletedTodo.status == 'Overdue' ? 1 : 0),
      );
      _error = '';
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}