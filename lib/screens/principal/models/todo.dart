class Todo {
  final String id;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final String category;
  final String assignedTo;
  final String department;
  final DateTime dueDate;

  Todo({
    required this.id,
    this.description,
    required this.title,
    required this.priority,
    required this.status,
    required this.category,
    required this.assignedTo,
    required this.department,
    required this.dueDate,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 'Medium',
      status: json['status'] ?? 'Pending',
      category: json['category'] ?? 'Administrative',
      assignedTo: json['assignedTo'] ?? '',
      department: json['department'] ?? '',
      dueDate: DateTime.tryParse(json['dueDate'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      'category': category,
      'assignedTo': assignedTo,
      'department': department,
      'dueDate': dueDate.toIso8601String(),
    };
  }

  // Add copyWith method
  Todo copyWith({
    String? id,
    String? title,
    String? description,
    String? priority,
    String? status,
    String? category,
    String? assignedTo,
    String? department,
    DateTime? dueDate,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      assignedTo: assignedTo ?? this.assignedTo,
      department: department ?? this.department,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}

class TodoStats {
  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int overdue;

  TodoStats({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.overdue,
  });

  factory TodoStats.fromJson(Map<String, dynamic> json) {
    return TodoStats(
      total: json['total'] ?? 0,
      pending: json['pending'] ?? 0,
      inProgress: json['inProgress'] ?? 0,
      completed: json['completed'] ?? 0,
      overdue: json['overdue'] ?? 0,
    );
  }
}