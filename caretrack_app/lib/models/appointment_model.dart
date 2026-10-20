class AppointmentModel {
  final String id;
  final String clinicId;
  final String doctorId;
  final String patientId;
  final String date; // YYYY-MM-DD
  final String time; // e.g. 10:00 AM
  final String type; // 'Consultation' | 'Follow-up'
  final String? reason;
  final String? notes;
  final String status; // 'Scheduled' | 'Confirmed' | 'Completed' | 'Missed' | 'Cancelled' | 'Rescheduled'
  final String confirmationStatus; // 'Pending' | 'Confirmed' | 'Declined' | 'Reschedule Requested'
  final bool reminder24hSent;
  final DateTime? lastReminderSentAt;
  final double? riskScore;
  final String? riskLevel; // 'low' | 'medium' | 'high'
  final List<String>? riskFactors;
  final bool extraReminderSent;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppointmentModel({
    required this.id,
    this.clinicId = 'default-clinic',
    required this.doctorId,
    required this.patientId,
    required this.date,
    required this.time,
    this.type = 'Follow-up',
    this.reason,
    this.notes,
    this.status = 'Scheduled',
    this.confirmationStatus = 'Pending',
    this.reminder24hSent = false,
    this.lastReminderSentAt,
    this.riskScore,
    this.riskLevel,
    this.riskFactors,
    this.extraReminderSent = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isConfirmed => confirmationStatus == 'Confirmed' || status == 'Confirmed';
  bool get isPending => confirmationStatus == 'Pending';
  bool get isRescheduleRequested => confirmationStatus == 'Reschedule Requested';
  bool get isMissed => status == 'Missed';
  bool get isCompleted => status == 'Completed';

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String id) {
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

    return AppointmentModel(
      id: id,
      clinicId: map['clinicId'] ?? 'default-clinic',
      doctorId: map['doctorId'] ?? '',
      patientId: map['patientId'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '10:00 AM',
      type: map['type'] ?? 'Follow-up',
      reason: map['reason'],
      notes: map['notes'],
      status: map['status'] ?? 'Scheduled',
      confirmationStatus: map['confirmationStatus'] ?? 'Pending',
      reminder24hSent: map['reminder24hSent'] ?? false,
      lastReminderSentAt: map['lastReminderSentAt'] != null ? parseDate(map['lastReminderSentAt']) : null,
      riskScore: (map['riskScore'] is num) ? (map['riskScore'] as num).toDouble() : null,
      riskLevel: map['riskLevel'],
      riskFactors: map['riskFactors'] != null ? List<String>.from(map['riskFactors']) : null,
      extraReminderSent: map['extraReminderSent'] ?? false,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clinicId': clinicId,
      'doctorId': doctorId,
      'patientId': patientId,
      'date': date,
      'time': time,
      'type': type,
      'reason': reason,
      'notes': notes,
      'status': status,
      'confirmationStatus': confirmationStatus,
      'reminder24hSent': reminder24hSent,
      'lastReminderSentAt': lastReminderSentAt?.toIso8601String(),
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'riskFactors': riskFactors,
      'extraReminderSent': extraReminderSent,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
