class AppointmentRiskModel {
  final double riskScore; // 0.0 to 1.0
  final String riskLevel; // 'low' | 'medium' | 'high'
  final List<String> riskFactors;
  final bool extraReminderTriggered;

  AppointmentRiskModel({
    required this.riskScore,
    required this.riskLevel,
    required this.riskFactors,
    this.extraReminderTriggered = false,
  });

  bool get isHighRisk => riskLevel == 'high';
  bool get isMediumRisk => riskLevel == 'medium';
  bool get isLowRisk => riskLevel == 'low';

  int get riskPercentage => (riskScore * 100).round();

  factory AppointmentRiskModel.fromMap(Map<String, dynamic> map) {
    return AppointmentRiskModel(
      riskScore: (map['riskScore'] is num) ? (map['riskScore'] as num).toDouble() : 0.0,
      riskLevel: map['riskLevel'] ?? 'low',
      riskFactors: List<String>.from(map['riskFactors'] ?? []),
      extraReminderTriggered: map['extraReminderTriggered'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'riskFactors': riskFactors,
      'extraReminderTriggered': extraReminderTriggered,
    };
  }
}
