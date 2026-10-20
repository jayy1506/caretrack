import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/treatment_plan_model.dart';

class TreatmentPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Stream all treatment plans for a specific patient
  Stream<List<TreatmentPlanModel>> streamPatientPlans(String patientId) {
    return _firestore
        .collection('treatmentPlans')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TreatmentPlanModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    });
  }

  /// Stream all active treatment plans in a clinic
  Stream<List<TreatmentPlanModel>> streamClinicPlans(String clinicId) {
    return _firestore
        .collection('treatmentPlans')
        .where('clinicId', isEqualTo: clinicId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TreatmentPlanModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  /// Fetch plan templates available for the clinic
  Future<List<PlanTemplateModel>> fetchPlanTemplates({String? clinicId}) async {
    try {
      final callable = _functions.httpsCallable('getPlanTemplates');
      final res = await callable.call({'clinicId': clinicId});
      final data = Map<String, dynamic>.from(res.data as Map);
      final listRaw = (data['templates'] as List<dynamic>?) ?? [];

      return listRaw.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return PlanTemplateModel.fromMap(map, map['id'] ?? '');
      }).toList();
    } catch (e) {
      // Fallback query directly from Firestore if offline or network hiccup
      final snapshot = await _firestore
          .collection('planTemplates')
          .where('clinicId', isEqualTo: clinicId ?? 'default-clinic')
          .get();

      return snapshot.docs
          .map((doc) => PlanTemplateModel.fromMap(doc.data(), doc.id))
          .toList();
    }
  }

  /// Create a new treatment plan from template or custom stages
  Future<Map<String, dynamic>> createPlanFromTemplate({
    required String clinicId,
    required String patientId,
    String? templateId,
    required String title,
    required String firstAppointmentDate,
    String firstAppointmentTime = '10:00 AM',
    List<Map<String, dynamic>>? stages,
  }) async {
    final callable = _functions.httpsCallable('createPlanFromTemplate');
    final res = await callable.call({
      'clinicId': clinicId,
      'patientId': patientId,
      if (templateId != null) 'templateId': templateId,
      'title': title,
      'firstAppointmentDate': firstAppointmentDate,
      'firstAppointmentTime': firstAppointmentTime,
      if (stages != null) 'stages': stages,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Complete a stage and auto-advance the treatment plan
  Future<Map<String, dynamic>> completeStage({
    required String planId,
    required int stageOrder,
    String? notes,
    String? customNextDate,
  }) async {
    final callable = _functions.httpsCallable('completeStage');
    final res = await callable.call({
      'planId': planId,
      'stageOrder': stageOrder,
      if (notes != null) 'notes': notes,
      if (customNextDate != null) 'customNextDate': customNextDate,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Skip a stage with clinical reason
  Future<Map<String, dynamic>> skipStage({
    required String planId,
    required int stageOrder,
    required String reason,
  }) async {
    final callable = _functions.httpsCallable('skipStage');
    final res = await callable.call({
      'planId': planId,
      'stageOrder': stageOrder,
      'reason': reason,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Pause an active treatment plan
  Future<Map<String, dynamic>> pausePlan({
    required String planId,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('pausePlan');
    final res = await callable.call({
      'planId': planId,
      if (reason != null) 'reason': reason,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Resume a paused treatment plan
  Future<Map<String, dynamic>> resumePlan({
    required String planId,
  }) async {
    final callable = _functions.httpsCallable('resumePlan');
    final res = await callable.call({
      'planId': planId,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }
}
