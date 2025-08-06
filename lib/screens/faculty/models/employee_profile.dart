class EmployeeProfile {
  final String employeeName;
  final Salary salary;
  final PFProfile? pf;
  final IncomeTaxProfile? incomeTax;
  final ComplianceProfile compliance;

  EmployeeProfile({
    required this.employeeName,
    required this.salary,
    this.pf,
    this.incomeTax,
    required this.compliance,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      employeeName: json['employeeName'] ?? '',
      salary: Salary.fromJson(json['salary'] ?? {}),
      pf: json['pf'] != null ? PFProfile.fromJson(json['pf']) : null,
      incomeTax: json['incomeTax'] != null
          ? IncomeTaxProfile.fromJson(json['incomeTax'])
          : null,
      compliance: ComplianceProfile.fromJson(json['compliance'] ?? {}),
    );
  }
}

class Salary {
  final double totalAnnual;
  final double monthlyAverage;
  final int recordCount;

  Salary({
    required this.totalAnnual,
    required this.monthlyAverage,
    required this.recordCount,
  });

  factory Salary.fromJson(Map<String, dynamic> json) {
    return Salary(
      totalAnnual: (json['totalAnnual'] ?? 0).toDouble(),
      monthlyAverage: (json['monthlyAverage'] ?? 0).toDouble(),
      recordCount: json['recordCount'] ?? 0,
    );
  }
}

class PFProfile {
  final String pfNumber;
  final double employeePFContribution;
  final double employerPFContribution;
  final double professionalTax;

  PFProfile({
    required this.pfNumber,
    required this.employeePFContribution,
    required this.employerPFContribution,
    required this.professionalTax,
  });

  factory PFProfile.fromJson(Map<String, dynamic> json) {
    return PFProfile(
      pfNumber: json['pfNumber'] ?? '',
      employeePFContribution: (json['employeePFContribution'] ?? 0).toDouble(),
      employerPFContribution: (json['employerPFContribution'] ?? 0).toDouble(),
      professionalTax: (json['professionalTax'] ?? 0).toDouble(),
    );
  }
}

class IncomeTaxProfile {
  final String panNumber;
  final double grossIncome;
  final double totalTax;
  final double tdsDeducted;

  IncomeTaxProfile({
    required this.panNumber,
    required this.grossIncome,
    required this.totalTax,
    required this.tdsDeducted,
  });

  factory IncomeTaxProfile.fromJson(Map<String, dynamic> json) {
    return IncomeTaxProfile(
      panNumber: json['panNumber'] ?? '',
      grossIncome: (json['grossIncome'] ?? 0).toDouble(),
      totalTax: (json['totalTax'] ?? 0).toDouble(),
      tdsDeducted: (json['tdsDeducted'] ?? 0).toDouble(),
    );
  }
}

class ComplianceProfile {
  final bool hasSalaryData;
  final bool hasPFData;
  final bool hasIncomeTaxData;
  final bool isFullyCompliant;

  ComplianceProfile({
    required this.hasSalaryData,
    required this.hasPFData,
    required this.hasIncomeTaxData,
    required this.isFullyCompliant,
  });

  factory ComplianceProfile.fromJson(Map<String, dynamic> json) {
    return ComplianceProfile(
      hasSalaryData: json['hasSalaryData'] ?? false,
      hasPFData: json['hasPFData'] ?? false,
      hasIncomeTaxData: json['hasIncomeTaxData'] ?? false,
      isFullyCompliant: json['isFullyCompliant'] ?? false,
    );
  }
}