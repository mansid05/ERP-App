class TimetableSummary {
  final int totalTimetables;
  final int totalDepartments;
  final List<DepartmentBreakdown> departmentBreakdown;

  TimetableSummary({
    required this.totalTimetables,
    required this.totalDepartments,
    required this.departmentBreakdown,
  });

  factory TimetableSummary.fromJson(Map<String, dynamic> json) {
    return TimetableSummary(
      totalTimetables: json['totalTimetables'] ?? 0,
      totalDepartments: json['totalDepartments'] ?? 0,
      departmentBreakdown: (json['departmentBreakdown'] as List<dynamic>?)
          ?.map((e) => DepartmentBreakdown.fromJson(e))
          .toList() ??
          [],
    );
  }
}

class DepartmentBreakdown {
  final String department;
  final int count;
  final int semesters;
  final int sections;

  DepartmentBreakdown({
    required this.department,
    required this.count,
    required this.semesters,
    required this.sections,
  });

  factory DepartmentBreakdown.fromJson(Map<String, dynamic> json) {
    return DepartmentBreakdown(
      department: json['department'] ?? '',
      count: json['count'] ?? 0,
      semesters: json['semesters'] ?? 0,
      sections: json['sections'] ?? 0,
    );
  }
}

class Timetable {
  final String id;
  final String department;
  final int semester;
  final String section;
  final int year;
  final DateTime createdAt;
  final DateTime lastModified;

  Timetable({
    required this.id,
    required this.department,
    required this.semester,
    required this.section,
    required this.year,
    required this.createdAt,
    required this.lastModified,
  });

  factory Timetable.fromJson(Map<String, dynamic> json) {
    return Timetable(
      id: json['_id'] ?? '',
      department: json['department'] ?? '',
      semester: json['semester'] ?? 0,
      section: json['section'] ?? '',
      year: json['year'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      lastModified: DateTime.tryParse(json['lastModified'] ?? '') ?? DateTime.now(),
    );
  }
}