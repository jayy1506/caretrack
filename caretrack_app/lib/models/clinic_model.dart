class ClinicFeatureFlags {
  final bool treatmentPlans;
  final bool onlineBooking;
  final bool twoWayWhatsApp;
  final bool recall;
  final bool medicationReminders;
  final bool noShowAI;
  final bool faqAssistant;

  const ClinicFeatureFlags({
    this.treatmentPlans = true,
    this.onlineBooking = true,
    this.twoWayWhatsApp = true,
    this.recall = true,
    this.medicationReminders = true,
    this.noShowAI = true,
    this.faqAssistant = true,
  });

  factory ClinicFeatureFlags.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ClinicFeatureFlags();
    return ClinicFeatureFlags(
      treatmentPlans: map['treatmentPlans'] ?? true,
      onlineBooking: map['onlineBooking'] ?? true,
      twoWayWhatsApp: map['twoWayWhatsApp'] ?? true,
      recall: map['recall'] ?? true,
      medicationReminders: map['medicationReminders'] ?? true,
      noShowAI: map['noShowAI'] ?? true,
      faqAssistant: map['faqAssistant'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'treatmentPlans': treatmentPlans,
      'onlineBooking': onlineBooking,
      'twoWayWhatsApp': twoWayWhatsApp,
      'recall': recall,
      'medicationReminders': medicationReminders,
      'noShowAI': noShowAI,
      'faqAssistant': faqAssistant,
    };
  }
}

class ClinicModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String timezone;
  final Map<String, dynamic> workingHours;
  final List<String> holidays;
  final String? logoUrl;
  final ClinicFeatureFlags featureFlags;

  ClinicModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.timezone = 'Asia/Kolkata',
    this.workingHours = const {},
    this.holidays = const [],
    this.logoUrl,
    this.featureFlags = const ClinicFeatureFlags(),
  });

  factory ClinicModel.fromMap(Map<String, dynamic> map, String id) {
    final settings = map['settings'] is Map ? map['settings'] as Map<String, dynamic> : null;
    return ClinicModel(
      id: map['id'] ?? id,
      name: map['name'] ?? 'CareTrack Clinic',
      address: map['address'] ?? settings?['address'] ?? '',
      phone: map['phone'] ?? settings?['phone'] ?? '',
      timezone: map['timezone'] ?? 'Asia/Kolkata',
      workingHours: Map<String, dynamic>.from(settings?['working_hours'] ?? map['workingHours'] ?? {}),
      holidays: List<String>.from(settings?['holidays'] ?? map['holidays'] ?? []),
      logoUrl: map['logo_url'] ?? map['logoUrl'],
      featureFlags: ClinicFeatureFlags.fromMap(settings?['feature_flags'] ?? map['featureFlags']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'timezone': timezone,
      'workingHours': workingHours,
      'holidays': holidays,
      'logoUrl': logoUrl,
      'featureFlags': featureFlags.toMap(),
    };
  }
}
