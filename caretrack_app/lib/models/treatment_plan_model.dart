class PlanTemplateStageModel {
  final int order;
  final String name;
  final int intervalDaysFromPrevious;
  final String? notes;

  PlanTemplateStageModel({
    required this.order,
    required this.name,
    this.intervalDaysFromPrevious = 0,
    this.notes,
  });

  factory PlanTemplateStageModel.fromMap(Map<String, dynamic> map) {
    return PlanTemplateStageModel(
      order: map['order'] ?? 1,
      name: map['name'] ?? '',
      intervalDaysFromPrevious: map['intervalDaysFromPrevious'] ?? 0,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order': order,
      'name': name,
      'intervalDaysFromPrevious': intervalDaysFromPrevious,
      if (notes != null) 'notes': notes,
    };
  }
}

class PlanTemplateModel {
  final String id;
  final String clinicId;
  final String title;
  final String description;
  final List<PlanTemplateStageModel> stages;

  PlanTemplateModel({
    required this.id,
    required this.clinicId,
    required this.title,
    required this.description,
    required this.stages,
  });

  factory PlanTemplateModel.fromMap(Map<String, dynamic> map, String id) {
    final stagesRaw = map['stages'] as List<dynamic>? ?? [];
    return PlanTemplateModel(
      id: id,
      clinicId: map['clinicId'] ?? 'default-clinic',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      stages: stagesRaw
          .map((s) => PlanTemplateStageModel.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clinicId': clinicId,
      'title': title,
      'description': description,
      'stages': stages.map((s) => s.toMap()).toList(),
    };
  }
}

class TreatmentPlanStageModel {
  final int order;
  final String name;
  final int intervalDaysFromPrevious;
  final String? appointmentId;
  final String status; // 'upcoming' | 'scheduled' | 'done' | 'skipped'
  final String? notes;

  TreatmentPlanStageModel({
    required this.order,
    required this.name,
    required this.intervalDaysFromPrevious,
    this.appointmentId,
    required this.status,
    this.notes,
  });

  bool get isDone => status == 'done';
  bool get isScheduled => status == 'scheduled';
  bool get isUpcoming => status == 'upcoming';
  bool get isSkipped => status == 'skipped';

  factory TreatmentPlanStageModel.fromMap(Map<String, dynamic> map) {
    return TreatmentPlanStageModel(
      order: map['order'] ?? 1,
      name: map['name'] ?? '',
      intervalDaysFromPrevious: map['intervalDaysFromPrevious'] ?? 0,
      appointmentId: map['appointmentId'],
      status: map['status'] ?? 'upcoming',
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order': order,
      'name': name,
      'intervalDaysFromPrevious': intervalDaysFromPrevious,
      if (appointmentId != null) 'appointmentId': appointmentId,
      'status': status,
      if (notes != null) 'notes': notes,
    };
  }
}

class TreatmentPlanModel {
  final String id;
  final String clinicId;
  final String patientId;
  final String doctorId;
  final String title;
  final String? templateId;
  final String status; // 'active' | 'completed' | 'paused' | 'cancelled' | 'at_risk'
  final List<TreatmentPlanStageModel> stages;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  TreatmentPlanModel({
    required this.id,
    this.clinicId = 'default-clinic',
    required this.patientId,
    required this.doctorId,
    required this.title,
    this.templateId,
    this.status = 'active',
    required this.stages,
    DateTime? startedAt,
    this.completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : startedAt = startedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isActive => status == 'active';
  bool get isAtRisk => status == 'at_risk';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  int get totalStagesCount => stages.length;
  int get completedStagesCount => stages.where((s) => s.isDone).length;
  double get progressPercentage =>
      stages.isEmpty ? 0.0 : (completedStagesCount / stages.length).clamp(0.0, 1.0);

  TreatmentPlanStageModel? get currentStage {
    for (final s in stages) {
      if (s.isScheduled || s.isUpcoming) return s;
    }
    return stages.isNotEmpty ? stages.last : null;
  }

  factory TreatmentPlanModel.fromMap(Map<String, dynamic> map, String id) {
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

    final stagesRaw = map['stages'] as List<dynamic>? ?? [];
    return TreatmentPlanModel(
      id: id,
      clinicId: map['clinicId'] ?? 'default-clinic',
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      title: map['title'] ?? 'Treatment Plan',
      templateId: map['templateId'],
      status: map['status'] ?? 'active',
      stages: stagesRaw
          .map((s) => TreatmentPlanStageModel.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      startedAt: parseDate(map['startedAt']),
      completedAt: map['completedAt'] != null ? parseDate(map['completedAt']) : null,
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
      'title': title,
      if (templateId != null) 'templateId': templateId,
      'status': status,
      'stages': stages.map((s) => s.toMap()).toList(),
      'startedAt': startedAt.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
