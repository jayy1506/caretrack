class MedicineItemModel {
  String name;
  String dosage;
  String frequency;
  String duration;
  String instructions;

  MedicineItemModel({
    required this.name,
    this.dosage = '',
    this.frequency = '',
    this.duration = '',
    this.instructions = '',
  });

  factory MedicineItemModel.fromMap(Map<String, dynamic> map) {
    return MedicineItemModel(
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      duration: map['duration'] ?? '',
      instructions: map['instructions'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
    };
  }
}

class PrescriptionModel {
  final String id;
  final String clinicId;
  final String doctorId;
  final String patientId;
  final String prescriptionDate; // YYYY-MM-DD
  final String source; // 'manual' | 'upload'
  final String? originalFileUrl;
  final List<MedicineItemModel> medicines;
  final String followUpType; // '15_days' | '1_month' | '3_months' | '6_months' | 'custom'
  final String followUpDate; // YYYY-MM-DD
  final bool aiExtracted;
  final bool doctorConfirmed;
  final DateTime createdAt;

  PrescriptionModel({
    required this.id,
    this.clinicId = 'default-clinic',
    required this.doctorId,
    required this.patientId,
    required this.prescriptionDate,
    this.source = 'manual',
    this.originalFileUrl,
    required this.medicines,
    this.followUpType = '3_months',
    required this.followUpDate,
    this.aiExtracted = false,
    this.doctorConfirmed = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PrescriptionModel.fromMap(Map<String, dynamic> map, String id) {
    final rawMedicines = map['medicines'] as List<dynamic>? ?? [];
    final parsedMedicines = rawMedicines
        .map((m) => MedicineItemModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();

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

    return PrescriptionModel(
      id: map['id'] ?? id,
      clinicId: map['clinic_id'] ?? map['clinicId'] ?? 'default-clinic',
      doctorId: map['doctor_id'] ?? map['doctorId'] ?? '',
      patientId: map['patient_id'] ?? map['patientId'] ?? '',
      prescriptionDate: map['prescription_date'] ??
          map['prescriptionDate'] ??
          (map['created_at'] != null ? map['created_at'].toString().split('T')[0] : ''),
      source: map['source'] ?? 'manual',
      originalFileUrl: map['original_file_url'] ?? map['originalFileUrl'],
      medicines: parsedMedicines,
      followUpType: map['follow_up_type'] ?? map['followUpType'] ?? '3_months',
      followUpDate: (map['follow_up_date'] ?? map['followUpDate'] ?? '').toString(),
      aiExtracted: map['ai_extracted'] ?? map['aiExtracted'] ?? false,
      doctorConfirmed: map['verified_at'] != null || map['doctorConfirmed'] == true,
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
      'prescription_date': prescriptionDate,
      'prescriptionDate': prescriptionDate,
      'source': source,
      'original_file_url': originalFileUrl,
      'originalFileUrl': originalFileUrl,
      'medicines': medicines.map((m) => m.toMap()).toList(),
      'follow_up_type': followUpType,
      'followUpType': followUpType,
      'follow_up_date': followUpDate,
      'followUpDate': followUpDate,
      'ai_extracted': aiExtracted,
      'aiExtracted': aiExtracted,
      'verified_at': doctorConfirmed ? createdAt.toIso8601String() : null,
      'doctorConfirmed': doctorConfirmed,
      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
