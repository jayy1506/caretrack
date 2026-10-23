class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String role; // 'owner' | 'doctor' | 'receptionist' | 'admin'
  final String clinicId;
  final bool active;
  final String? fcmToken;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.clinicId = 'default-clinic',
    this.active = true,
    this.fcmToken,
    this.createdAt,
  });

  bool get isOwner => role == 'owner' || role == 'admin';
  bool get isAdmin => isOwner;
  bool get isDoctor => role == 'doctor';
  bool get isReceptionist => role == 'receptionist';
  bool get isViewOnly => isReceptionist || role == 'view_only' || role == 'staff';
  bool get canEdit => isOwner || isDoctor;
  bool get canAccessPrescriptions => isDoctor || isOwner;
  bool get canManageStaff => isOwner;

  String get roleDisplayName {
    if (role == 'owner' || role == 'admin') return 'Clinic Owner';
    if (isDoctor) return 'Doctor';
    if (isReceptionist) return 'Receptionist';
    return 'Staff';
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    DateTime? created;
    final rawCreated = map['created_at'] ?? map['createdAt'];
    if (rawCreated != null) {
      if (rawCreated is DateTime) {
        created = rawCreated;
      } else if (rawCreated.toString().isNotEmpty) {
        try {
          created = DateTime.tryParse(rawCreated.toString());
        } catch (_) {}
      }
    }

    return UserModel(
      uid: map['id'] ?? uid,
      name: map['full_name'] ?? map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      role: map['role'] ?? 'doctor',
      clinicId: map['clinic_id'] ?? map['clinicId'] ?? 'default-clinic',
      active: map['active'] ?? true,
      fcmToken: map['fcm_token'] ?? map['fcmToken'],
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'uid': uid,
      'full_name': name,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'clinic_id': clinicId,
      'clinicId': clinicId,
      'active': active,
      'fcm_token': fcmToken,
    };
  }
}
