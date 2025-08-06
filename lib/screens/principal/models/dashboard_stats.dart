class DashboardStats {
  final int totalFaculties;
  final int totalStudents;
  final int totalDepartments;
  final List<DepartmentWiseData> departmentWiseData;
  final int pendingApprovals;
  final PendingApprovalsBreakdown pendingApprovalsBreakdown;

  DashboardStats({
    required this.totalFaculties,
    required this.totalStudents,
    required this.totalDepartments,
    required this.departmentWiseData,
    required this.pendingApprovals,
    required this.pendingApprovalsBreakdown,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalFaculties: json['total'] ?? 0, // From faculties endpoint
      totalStudents: json['total'] ?? 0, // From students endpoint
      totalDepartments: json['total'] ?? 0, // From departments endpoint
      departmentWiseData: (json['departmentWiseData'] as List<dynamic>?)
          ?.map((e) => DepartmentWiseData.fromJson(e))
          .toList() ??
          [],
      pendingApprovals: json['totalPendingApprovals'] ?? 0,
      pendingApprovalsBreakdown:
      PendingApprovalsBreakdown.fromJson(json['breakdown'] ?? {}),
    );
  }
}

class DepartmentWiseData {
  final String name;
  final int faculties;
  final int students;

  DepartmentWiseData({
    required this.name,
    required this.faculties,
    required this.students,
  });

  factory DepartmentWiseData.fromJson(Map<String, dynamic> json) {
    return DepartmentWiseData(
      name: json['name'] ?? '',
      faculties: json['Faculties'] ?? 0,
      students: json['Students'] ?? 0,
    );
  }
}

class PendingApprovalsBreakdown {
  final int leaveApprovals;
  final int odLeaveApprovals;
  final int facultyApprovals;
  final int handoverApprovals;

  PendingApprovalsBreakdown({
    required this.leaveApprovals,
    required this.odLeaveApprovals,
    required this.facultyApprovals,
    required this.handoverApprovals,
  });

  factory PendingApprovalsBreakdown.fromJson(Map<String, dynamic> json) {
    return PendingApprovalsBreakdown(
      leaveApprovals: json['leaveApprovals'] ?? 0,
      odLeaveApprovals: json['odLeaveApprovals'] ?? 0,
      facultyApprovals: json['facultyApprovals'] ?? 0,
      handoverApprovals: json['handoverApprovals'] ?? 0,
    );
  }
}