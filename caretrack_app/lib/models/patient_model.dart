class PatientConsentRecord {
  final bool messagingConsent;
  final String messagingConsentMethod; // 'in_person' | 'whatsapp_opt_in' | 'web_booking' | 'paper_form'
  final DateTime? messagingConsentTimestamp;
  final bool aiProcessingConsent;
  final String aiProcessingConsentMethod; // 'in_person' | 'web_booking' | 'paper_form'
  final DateTime? aiProcessingConsentTimestamp;
  final String? consentNotes;

  PatientConsentRecord({
    this.messagingConsent = true,
    this.messagingConsentMethod = 'in_person',
    this.messagingConsentTimestamp,
    this.aiProcessingConsent = true,
    this.aiProcessingConsentMethod = 'in_person',
    this.aiProcessingConsentTimestamp,
    this.consentNotes,
  });

  factory PatientConsentRecord.fromMap(Map<String, dynamic>? map) {
    if (map == null) return PatientConsentRecord();
    DateTime? parseD(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      try {
        return val.toDate();
      } catch (_) {
        return null;
      }
    }

    return PatientConsentRecord(
      messagingConsent: map['messagingConsent'] ?? true,
      messagingConsentMethod: map['messagingConsentMethod'] ?? 'in_person',
      messagingConsentTimestamp: parseD(map['messagingConsentTimestamp']),
      aiProcessingConsent: map['aiProcessingConsent'] ?? true,
      aiProcessingConsentMethod: map['aiProcessingConsentMethod'] ?? 'in_person',
      aiProcessingConsentTimestamp: parseD(map['aiProcessingConsentTimestamp']),
      consentNotes: map['consentNotes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messagingConsent': messagingConsent,
      'messagingConsentMethod': messagingConsentMethod,
      'messagingConsentTimestamp': messagingConsentTimestamp?.toIso8601String(),
      'aiProcessingConsent': aiProcessingConsent,
      'aiProcessingConsentMethod': aiProcessingConsentMethod,
      'aiProcessingConsentTimestamp': aiProcessingConsentTimestamp?.toIso8601String(),
      if (consentNotes != null) 'consentNotes': consentNotes,
    };
  }
}

class PatientModel {
  final String id;
  final String clinicId;
  final String doctorId;
  final String name;
  final int? age;
  final String? dateOfBirth;
  final String? phone;
  final String? email;
  final String? address;
  final String status; // 'active' | 'archived'
  final List<String> allergies;
  final int? preferredReminderHour;
  final bool messagingConsent;
  final bool aiProcessingConsent;
  final PatientConsentRecord consentRecord;
  final DateTime createdAt;
  final DateTime updatedAt;

  PatientModel({
    required this.id,
    this.clinicId = 'default-clinic',
    required this.doctorId,
    required this.name,
    this.age,
    this.dateOfBirth,
    this.phone,
    this.email,
    this.address,
    this.status = 'active',
    this.allergies = const [],
    this.preferredReminderHour,
    this.messagingConsent = true,
    this.aiProcessingConsent = true,
    PatientConsentRecord? consentRecord,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : consentRecord = consentRecord ??
            PatientConsentRecord(
              messagingConsent: messagingConsent,
              aiProcessingConsent: aiProcessingConsent,
            ),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory PatientModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      try {
        return val.toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    final consentObj = map['consentRecord'] as Map<String, dynamic>?;
    final msgConsent = map['messagingConsent'] ?? consentObj?['messagingConsent'] ?? true;
    final aiConsent = map['aiProcessingConsent'] ?? consentObj?['aiProcessingConsent'] ?? true;

    return PatientModel(
      id: id,
      clinicId: map['clinicId'] ?? 'default-clinic',
      doctorId: map['doctorId'] ?? '',
      name: map['name'] ?? '',
      age: map['age'] != null ? int.tryParse(map['age'].toString()) : null,
      dateOfBirth: map['dateOfBirth'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      status: map['status'] ?? 'active',
      allergies: map['allergies'] != null ? List<String>.from(map['allergies']) : [],
      preferredReminderHour: map['preferredReminderHour'] != null
          ? int.tryParse(map['preferredReminderHour'].toString())
          : null,
      messagingConsent: msgConsent,
      aiProcessingConsent: aiConsent,
      consentRecord: PatientConsentRecord.fromMap(consentObj),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clinicId': clinicId,
      'doctorId': doctorId,
      'name': name,
      'age': age,
      'dateOfBirth': dateOfBirth,
      'phone': phone,
      'email': email,
      'address': address,
      'status': status,
      'allergies': allergies,
      'preferredReminderHour': preferredReminderHour,
      'messagingConsent': messagingConsent,
      'aiProcessingConsent': aiProcessingConsent,
      'consentRecord': consentRecord.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  PatientModel copyWith({
    String? id,
    String? clinicId,
    String? doctorId,
    String? name,
    int? age,
    String? dateOfBirth,
    String? phone,
    String? email,
    String? address,
    String? status,
    List<String>? allergies,
    int? preferredReminderHour,
    bool? messagingConsent,
    bool? aiProcessingConsent,
    PatientConsentRecord? consentRecord,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      doctorId: doctorId ?? this.doctorId,
      name: name ?? this.name,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      status: status ?? this.status,
      allergies: allergies ?? this.allergies,
      preferredReminderHour: preferredReminderHour ?? this.preferredReminderHour,
      messagingConsent: messagingConsent ?? this.messagingConsent,
      aiProcessingConsent: aiProcessingConsent ?? this.aiProcessingConsent,
      consentRecord: consentRecord ?? this.consentRecord,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
