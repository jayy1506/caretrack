import '../core/supabase_config.dart';

enum AppointmentStatus {
  pending,
  confirmed,
  rescheduleRequested,
  rescheduled,
  missed,
  completed,
  cancelled;

  static AppointmentStatus fromString(String? val) {
    if (val == null) return AppointmentStatus.pending;
    final v = val.toLowerCase().replaceAll(' ', '_');
    if (v == 'scheduled' || v == 'pending') return AppointmentStatus.pending;
    if (v == 'confirmed') return AppointmentStatus.confirmed;
    if (v.contains('reschedule')) return AppointmentStatus.rescheduleRequested;
    if (v == 'missed') return AppointmentStatus.missed;
    if (v == 'completed') return AppointmentStatus.completed;
    if (v == 'cancelled') return AppointmentStatus.cancelled;
    return AppointmentStatus.pending;
  }

  String toSqlString() {
    switch (this) {
      case AppointmentStatus.rescheduleRequested:
        return 'reschedule_requested';
      default:
        return name;
    }
  }

  String get displayName {
    switch (this) {
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.rescheduleRequested:
        return 'Reschedule Requested';
      case AppointmentStatus.rescheduled:
        return 'Rescheduled';
      case AppointmentStatus.missed:
        return 'Missed';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class AppointmentModel {
  final String id;
  final String clinicId;
  final String doctorId;
  final String patientId;
  final String date; // YYYY-MM-DD (In clinic time zone)
  final String time; // e.g. 10:00 AM (In clinic time zone)
  final String type; // 'Consultation' | 'Follow-up'
  final String? reason;
  final String? notes;
  final String status; // 'pending' | 'confirmed' | 'reschedule_requested' | 'missed' | 'completed' | 'cancelled'
  final String confirmationStatus; // 'Pending' | 'Confirmed' | 'Declined' | 'Reschedule Requested'
  final bool reminder24hSent;
  final DateTime? lastReminderSentAt;
  final DateTime? startsAt;
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
    this.startsAt,
    this.riskScore,
    this.riskLevel,
    this.riskFactors,
    this.extraReminderSent = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isConfirmed =>
      status.toLowerCase() == 'confirmed' || confirmationStatus.toLowerCase() == 'confirmed';
  bool get isPending =>
      status.toLowerCase() == 'pending' || status.toLowerCase() == 'scheduled' || confirmationStatus.toLowerCase() == 'pending';
  bool get isRescheduleRequested =>
      status.toLowerCase().contains('reschedule') || confirmationStatus.toLowerCase().contains('reschedule');
  bool get isMissed => status.toLowerCase() == 'missed';
  bool get isCompleted => status.toLowerCase() == 'completed';

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) {
        try {
          return DateTime.parse(val);
        } catch (_) {
          return DateTime.now();
        }
      }
      try {
        return (val as dynamic).toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    String derivedDate = map['date'] ?? '';
    String derivedTime = map['time'] ?? '10:00 AM';
    DateTime? parsedStartsAt;

    final rawStartsAt = map['starts_at'] ?? map['startsAt'];
    if (rawStartsAt != null) {
      try {
        final parsedUtc = rawStartsAt is DateTime ? rawStartsAt : DateTime.parse(rawStartsAt.toString());
        parsedStartsAt = parsedUtc;
        final clinicTime = SupabaseConfig.toClinicTime(parsedUtc);
        derivedDate =
            '${clinicTime.year.toString().padLeft(4, '0')}-${clinicTime.month.toString().padLeft(2, '0')}-${clinicTime.day.toString().padLeft(2, '0')}';
        final hour = clinicTime.hour > 12 ? clinicTime.hour - 12 : (clinicTime.hour == 0 ? 12 : clinicTime.hour);
        final ampm = clinicTime.hour >= 12 ? 'PM' : 'AM';
        derivedTime = '${hour.toString().padLeft(2, '0')}:${clinicTime.minute.toString().padLeft(2, '0')} $ampm';
      } catch (_) {}
    }

    final rawStatus = (map['status'] ?? 'Scheduled').toString();
    final statusEnum = AppointmentStatus.fromString(rawStatus);

    final rawReminderSent = map['reminder_sent_at'] ?? map['lastReminderSentAt'];

    return AppointmentModel(
      id: map['id'] ?? id,
      clinicId: map['clinic_id'] ?? map['clinicId'] ?? 'default-clinic',
      doctorId: map['doctor_id'] ?? map['doctorId'] ?? '',
      patientId: map['patient_id'] ?? map['patientId'] ?? '',
      date: derivedDate,
      time: derivedTime,
      startsAt: parsedStartsAt,
      type: map['type'] ?? 'Follow-up',
      reason: map['reason'],
      notes: map['notes'],
      status: statusEnum.displayName,
      confirmationStatus: map['confirmationStatus'] ?? statusEnum.displayName,
      reminder24hSent: map['reminder24hSent'] ?? (map['reminder_sent_at'] != null),
      lastReminderSentAt: rawReminderSent != null ? parseDate(rawReminderSent) : null,
      riskScore: (map['riskScore'] is num) ? (map['riskScore'] as num).toDouble() : null,
      riskLevel: map['riskLevel'],
      riskFactors: map['riskFactors'] != null ? List<String>.from(map['riskFactors']) : null,
      extraReminderSent: map['extraReminderSent'] ?? false,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'clinicId': clinicId,
      'doctor_id': doctorId,
      'doctorId': doctorId,
      'patient_id': patientId,
      'patientId': patientId,
      'date': date,
      'time': time,
      'type': type,
      'reason': reason,
      'notes': notes,
      'status': status.toLowerCase().replaceAll(' ', '_'),
      'confirmationStatus': confirmationStatus,
      'reminder24hSent': reminder24hSent,
      'lastReminderSentAt': lastReminderSentAt?.toIso8601String(),
      'starts_at': startsAt?.toIso8601String(),
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'riskFactors': riskFactors,
      'extraReminderSent': extraReminderSent,
      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
