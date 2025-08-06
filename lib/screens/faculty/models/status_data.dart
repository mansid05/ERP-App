class StatusData {
  final double totalPaid;
  final PFStatus pf;
  final IncomeTaxStatus incomeTax;
  final Compliance compliance;

  StatusData({
    required this.totalPaid,
    required this.pf,
    required this.incomeTax,
    required this.compliance,
  });

  factory StatusData.fromJson(Map<String, dynamic> json) {
    return StatusData(
      totalPaid: (json['totalPaid'] ?? 0).toDouble(),
      pf: PFStatus.fromJson(json['pf'] ?? {}),
      incomeTax: IncomeTaxStatus.fromJson(json['incomeTax'] ?? {}),
      compliance: Compliance.fromJson(json['compliance'] ?? {}),
    );
  }
}

class PFStatus {
  final double totalEmployeePF;
  final double totalEmployerPF;
  final int records;

  PFStatus({
    required this.totalEmployeePF,
    required this.totalEmployerPF,
    required this.records,
  });

  factory PFStatus.fromJson(Map<String, dynamic> json) {
    return PFStatus(
      totalEmployeePF: (json['totalEmployeePF'] ?? 0).toDouble(),
      totalEmployerPF: (json['totalEmployerPF'] ?? 0).toDouble(),
      records: json['records'] ?? 0,
    );
  }
}

class IncomeTaxStatus {
  final double totalLiability;
  final int records;

  IncomeTaxStatus({required this.totalLiability, required this.records});

  factory IncomeTaxStatus.fromJson(Map<String, dynamic> json) {
    return IncomeTaxStatus(
      totalLiability: (json['totalLiability'] ?? 0).toDouble(),
      records: json['records'] ?? 0,
    );
  }
}

class Compliance {
  final int totalEmployees;
  final int pfCompliant;

  Compliance({required this.totalEmployees, required this.pfCompliant});

  factory Compliance.fromJson(Map<String, dynamic> json) {
    return Compliance(
      totalEmployees: json['totalEmployees'] ?? 0,
      pfCompliant: json['pfCompliant'] ?? 0,
    );
  }
}