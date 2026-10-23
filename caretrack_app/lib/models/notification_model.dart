class NotificationModel {
  final String id;
  final String clinicId;
  final String doctorId;
  final String? patientId;
  final String? appointmentId;
  final String channel; // 'push' | 'email' | 'sms'
  final String type; // 'patient_registration' | 'appointment_confirmation' | 'appointment_reminder_24h' | etc.
  final String recipient;
  final String status; // 'Pending' | 'Sent' | 'Delivered' | 'Failed'
  final String? providerMessageId;
  final String? error;
  final DateTime? sentAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    this.clinicId = 'default-clinic',
    required this.doctorId,
    this.patientId,
    this.appointmentId,
    required this.channel,
    required this.type,
    required this.recipient,
    required this.status,
    this.providerMessageId,
    this.error,
    this.sentAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get readableType {
    switch (type) {
      case 'patient_registration':
        return 'Patient Registration';
      case 'appointment_confirmation':
        return 'Appointment Confirmation';
      case 'appointment_reminder_24h':
        return '24h Appointment Reminder';
      case 'appointment_reminder_demo':
        return 'Demo Mode Reminder';
      case 'doctor_appointment_reminder':
        return 'Doctor Reminder Push';
      case 'followup_reminder':
        return 'Follow-up Due Reminder';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
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

    return NotificationModel(
      id: map['id'] ?? id,
      clinicId: map['clinic_id'] ?? map['clinicId'] ?? 'default-clinic',
      doctorId: map['doctor_id'] ?? map['doctorId'] ?? '',
      patientId: map['patient_id'] ?? map['patientId'],
      appointmentId: map['appointment_id'] ?? map['appointmentId'],
      channel: map['channel'] ?? 'whatsapp',
      type: map['type'] ?? 'appointment_reminder',
      recipient: map['recipient_masked'] ?? map['recipient'] ?? '',
      status: map['status'] ?? 'Pending',
      providerMessageId: map['provider_message_id'] ?? map['providerMessageId'],
      error: map['error'],
      sentAt: map['sentAt'] != null ? parseDate(map['sentAt']) : (map['status'] == 'sent' ? parseDate(map['created_at']) : null),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
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
      'appointment_id': appointmentId,
      'appointmentId': appointmentId,
      'channel': channel,
      'type': type,
      'recipient': recipient,
      'recipient_masked': recipient,
      'status': status,
      'provider_message_id': providerMessageId,
      'providerMessageId': providerMessageId,
      'error': error,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
