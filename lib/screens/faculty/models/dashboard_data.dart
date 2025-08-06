class DashboardData {
  final Summary summary;
  final List<FacultyData> facultyData;

  DashboardData({required this.summary, required this.facultyData});

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      summary: Summary.fromJson(json['summary'] ?? {}),
      facultyData: (json['facultyData'] as List<dynamic>?)
          ?.map((e) => FacultyData.fromJson(e))
          .toList() ??
          [],
    );
  }
}

class Summary {
  final int totalEmployees;
  final double totalSalaryPaid;
  final int employeesWithPF;
  final int employeesWithIncomeTax;
  final int fullyCompliantEmployees;
  final double pendingPayments;
  final double complianceRate;

  Summary({
    required this.totalEmployees,
    required this.totalSalaryPaid,
    required this.employeesWithPF,
    required this.employeesWithIncomeTax,
    required this.fullyCompliantEmployees,
    required this.pendingPayments,
    required this.complianceRate,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      totalEmployees: json['totalEmployees'] ?? 0,
      totalSalaryPaid: (json['totalSalaryPaid'] ?? 0).toDouble(),
      employeesWithPF: json['employeesWithPF'] ?? 0,
      employeesWithIncomeTax: json['employeesWithIncomeTax'] ?? 0,
      fullyCompliantEmployees: json['fullyCompliantEmployees'] ?? 0,
      pendingPayments: (json['pendingPayments'] ?? 0).toDouble(),
      complianceRate: (json['complianceRate'] ?? 0).toDouble(),
    );
  }
}

class FacultyData {
  final String name;
  final int recordCount;
  final double totalSalary;
  final PF? pf;
  final IncomeTax? incomeTax;
  final bool hasCompleteData;

  FacultyData({
    required this.name,
    required this.recordCount,
    required this.totalSalary,
    this.pf,
    this.incomeTax,
    required this.hasCompleteData,
  });

  factory FacultyData.fromJson(Map<String, dynamic> json) {
    return FacultyData(
      name: json['name'] ?? '',
      recordCount: json['recordCount'] ?? 0,
      totalSalary: (json['totalSalary'] ?? 0).toDouble(),
      pf: json['pf'] != null ? PF.fromJson(json['pf']) : null,
      incomeTax:
      json['incomeTax'] != null ? IncomeTax.fromJson(json['incomeTax']) : null,
      hasCompleteData: json['hasCompleteData'] ?? false,
    );
  }
}

class PF {
  final String pfNumber;
  final double totalPFContribution;

  PF({required this.pfNumber, required this.totalPFContribution});

  factory PF.fromJson(Map<String, dynamic> json) {
    return PF(
      pfNumber: json['pfNumber'] ?? '',
      totalPFContribution: (json['totalPFContribution'] ?? 0).toDouble(),
    );
  }
}

class IncomeTax {
  final String financialYear;
  final double totalTax;

  IncomeTax({required this.financialYear, required this.totalTax});

  factory IncomeTax.fromJson(Map<String, dynamic> json) {
    return IncomeTax(
      financialYear: json['financialYear'] ?? '',
      totalTax: (json['totalTax'] ?? 0).toDouble(),
    );
  }
}