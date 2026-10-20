class PrescriptionSafetyWarning {
  final String type; // 'allergy_conflict' | 'duplicate_drug' | 'duplicate_drug_class'
  final String severity; // 'danger' | 'warning'
  final String medicineName;
  final String? conflictingItem;
  final String message;
  final String clinicalRationale;

  PrescriptionSafetyWarning({
    required this.type,
    required this.severity,
    required this.medicineName,
    this.conflictingItem,
    required this.message,
    required this.clinicalRationale,
  });

  bool get isDanger => severity == 'danger';
  bool get isWarning => severity == 'warning';

  factory PrescriptionSafetyWarning.fromMap(Map<String, dynamic> map) {
    return PrescriptionSafetyWarning(
      type: map['type'] ?? 'duplicate_drug',
      severity: map['severity'] ?? 'warning',
      medicineName: map['medicineName'] ?? '',
      conflictingItem: map['conflictingItem'],
      message: map['message'] ?? '',
      clinicalRationale: map['clinicalRationale'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'severity': severity,
      'medicineName': medicineName,
      'conflictingItem': conflictingItem,
      'message': message,
      'clinicalRationale': clinicalRationale,
    };
  }
}
