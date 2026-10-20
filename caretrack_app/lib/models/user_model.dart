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
    if (map['createdAt'] != null) {
      if (map['createdAt'] is DateTime) {
        created = map['createdAt'];
      } else if (map['createdAt'].toString().isNotEmpty) {
        try {
          created = DateTime.tryParse(map['createdAt'].toString());
        } catch (_) {}
      }
    }

    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      role: map['role'] ?? 'doctor',
      clinicId: map['clinicId'] ?? 'default-clinic',
      active: map['active'] ?? true,
      fcmToken: map['fcmToken'],
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'clinicId': clinicId,
      'active': active,
      'fcmToken': fcmToken,
    };
  }
}
