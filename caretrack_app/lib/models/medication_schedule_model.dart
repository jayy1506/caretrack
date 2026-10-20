class MedicationScheduleItemModel {
  final String medicineName;
  final String dosage;
  final String frequency;
  final List<String> timing; // ['morning', 'afternoon', 'night']
  final String? instructions;
  final int durationDays;

  MedicationScheduleItemModel({
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.timing,
    this.instructions,
    this.durationDays = 5,
  });

  factory MedicationScheduleItemModel.fromMap(Map<String, dynamic> map) {
    final rawTiming = (map['timing'] as List<dynamic>?) ?? [];
    return MedicationScheduleItemModel(
      medicineName: map['medicineName'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      timing: rawTiming.map((t) => t.toString()).toList(),
      instructions: map['instructions'],
      durationDays: map['durationDays'] ?? 5,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'timing': timing,
      if (instructions != null) 'instructions': instructions,
      'durationDays': durationDays,
    };
  }
}

class MedicationTimeWindowsModel {
  final String morning;
  final String afternoon;
  final String night;

  MedicationTimeWindowsModel({
    this.morning = '08:30 AM',
    this.afternoon = '01:30 PM',
    this.night = '08:30 PM',
  });

  factory MedicationTimeWindowsModel.fromMap(Map<String, dynamic> map) {
    return MedicationTimeWindowsModel(
      morning: map['morning'] ?? '08:30 AM',
      afternoon: map['afternoon'] ?? '01:30 PM',
      night: map['night'] ?? '08:30 PM',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'morning': morning,
      'afternoon': afternoon,
      'night': night,
    };
  }
}

class MedicationAdherenceModel {
  final int totalReminders;
  final int takenCount;
  final int missedCount;
  final double adherenceRate; // 0 to 100%

  MedicationAdherenceModel({
    this.totalReminders = 0,
    this.takenCount = 0,
    this.missedCount = 0,
    this.adherenceRate = 100.0,
  });

  factory MedicationAdherenceModel.fromMap(Map<String, dynamic> map) {
    return MedicationAdherenceModel(
      totalReminders: map['totalReminders'] ?? 0,
      takenCount: map['takenCount'] ?? 0,
      missedCount: map['missedCount'] ?? 0,
      adherenceRate: (map['adherenceRate'] as num?)?.toDouble() ?? 100.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalReminders': totalReminders,
      'takenCount': takenCount,
      'missedCount': missedCount,
      'adherenceRate': adherenceRate,
    };
  }
}

class MedicationScheduleModel {
  final String id;
  final String clinicId;
  final String patientId;
  final String doctorId;
  final String prescriptionId;
  final String status; // 'draft' | 'active' | 'completed' | 'paused' | 'cancelled'
  final String startDate; // YYYY-MM-DD
  final String endDate;   // YYYY-MM-DD
  final MedicationTimeWindowsModel timeWindows;
  final List<MedicationScheduleItemModel> items;
  final MedicationAdherenceModel adherence;
  final bool doctorConfirmed;
  final DateTime? confirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicationScheduleModel({
    required this.id,
    this.clinicId = 'default-clinic',
    required this.patientId,
    required this.doctorId,
    required this.prescriptionId,
    this.status = 'draft',
    required this.startDate,
    required this.endDate,
    required this.timeWindows,
    required this.items,
    required this.adherence,
    this.doctorConfirmed = false,
    this.confirmedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isActive => status == 'active';
  bool get isDraft => status == 'draft';
  bool get isCompleted => status == 'completed';

  factory MedicationScheduleModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      try {
        return val.toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    final rawItems = (map['items'] as List<dynamic>?) ?? [];
    return MedicationScheduleModel(
      id: id,
      clinicId: map['clinicId'] ?? 'default-clinic',
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      prescriptionId: map['prescriptionId'] ?? '',
      status: map['status'] ?? 'draft',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
      timeWindows: MedicationTimeWindowsModel.fromMap(
        map['timeWindows'] != null ? Map<String, dynamic>.from(map['timeWindows']) : {},
      ),
      items: rawItems
          .map((item) => MedicationScheduleItemModel.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      adherence: MedicationAdherenceModel.fromMap(
        map['adherence'] != null ? Map<String, dynamic>.from(map['adherence']) : {},
      ),
      doctorConfirmed: map['doctorConfirmed'] ?? false,
      confirmedAt: map['confirmedAt'] != null ? parseDate(map['confirmedAt']) : null,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clinicId': clinicId,
      'patientId': patientId,
      'doctorId': doctorId,
      'prescriptionId': prescriptionId,
      'status': status,
      'startDate': startDate,
      'endDate': endDate,
      'timeWindows': timeWindows.toMap(),
      'items': items.map((i) => i.toMap()).toList(),
      'adherence': adherence.toMap(),
      'doctorConfirmed': doctorConfirmed,
      if (confirmedAt != null) 'confirmedAt': confirmedAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
