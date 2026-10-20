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
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory PatientModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      try {
        // Firebase Timestamp
        return val.toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

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
