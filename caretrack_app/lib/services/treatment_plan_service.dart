import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/treatment_plan_model.dart';

class TreatmentPlanService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Stream all treatment plans for a specific patient with plan_stages joined
  Stream<List<TreatmentPlanModel>> streamPatientPlans(String patientId) {
    return _supabase
        .from('treatment_plans')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .asyncMap((plans) async {
      final List<TreatmentPlanModel> fullPlans = [];
      for (final plan in plans) {
        final stages = await _supabase
            .from('plan_stages')
            .select('*')
            .eq('plan_id', plan['id'])
            .order('stage_order', ascending: true);
        fullPlans.add(TreatmentPlanModel.fromMap({...plan, 'plan_stages': stages}, plan['id']));
      }
      fullPlans.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return fullPlans;
    });
  }

  /// Stream all active treatment plans in a clinic
  Stream<List<TreatmentPlanModel>> streamClinicPlans(String clinicId) {
    return _supabase
        .from('treatment_plans')
        .stream(primaryKey: ['id'])
        .eq('clinic_id', clinicId)
        .asyncMap((plans) async {
      final List<TreatmentPlanModel> fullPlans = [];
      for (final plan in plans) {
        final stages = await _supabase
            .from('plan_stages')
            .select('*')
            .eq('plan_id', plan['id'])
            .order('stage_order', ascending: true);
        fullPlans.add(TreatmentPlanModel.fromMap({...plan, 'plan_stages': stages}, plan['id']));
      }
      fullPlans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return fullPlans;
    });
  }

  /// Fetch plan templates available for the clinic
  Future<List<PlanTemplateModel>> fetchPlanTemplates({String? clinicId}) async {
    try {
      final effectiveClinicId = clinicId ?? 'c0000000-0000-0000-0000-000000000001';
      final data = await _supabase
          .from('treatment_plan_templates')
          .select('*')
          .or('clinic_id.eq.$effectiveClinicId,clinic_id.is.null');

      return (data as List<dynamic>).map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return PlanTemplateModel.fromMap(map, map['id'] ?? '');
      }).toList();
    } catch (e) {
      debugPrint('Notice loading plan templates: $e');
      return [];
    }
  }

  /// Create a new treatment plan from template or custom stages via Edge Function
  Future<Map<String, dynamic>> createPlanFromTemplate({
    required String clinicId,
    required String patientId,
    String? templateId,
    required String title,
    required String firstAppointmentDate,
    String firstAppointmentTime = '10:00 AM',
    List<Map<String, dynamic>>? stages,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'treatment-plans',
        body: {
          'action': 'create_plan',
          'clinicId': clinicId,
          'patientId': patientId,
          if (templateId != null) 'templateId': templateId,
          'title': title,
          'firstAppointmentDate': firstAppointmentDate,
          'firstAppointmentTime': firstAppointmentTime,
          if (stages != null) 'stages': stages,
        },
      );
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'status': 'success'};
    } catch (e) {
      throw Exception(SupabaseConfig.formatError(e));
    }
  }

  /// Complete a stage and auto-advance the treatment plan via Edge Function
  Future<Map<String, dynamic>> completeStage({
    required String planId,
    required int stageOrder,
    String? notes,
    String? customNextDate,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'treatment-plans',
        body: {
          'action': 'complete_stage',
          'planId': planId,
          'stageOrder': stageOrder,
          if (notes != null) 'notes': notes,
          if (customNextDate != null) 'customNextDate': customNextDate,
        },
      );
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'status': 'completed'};
    } catch (e) {
      throw Exception(SupabaseConfig.formatError(e));
    }
  }

  /// Skip a stage with clinical reason
  Future<Map<String, dynamic>> skipStage({
    required String planId,
    required int stageOrder,
    required String reason,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'treatment-plans',
        body: {
          'action': 'skip_stage',
          'planId': planId,
          'stageOrder': stageOrder,
          'reason': reason,
        },
      );
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'status': 'skipped'};
    } catch (e) {
      throw Exception(SupabaseConfig.formatError(e));
    }
  }

  /// Pause an active treatment plan
  Future<Map<String, dynamic>> pausePlan({
    required String planId,
    String? reason,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'treatment-plans',
        body: {
          'action': 'pause_plan',
          'planId': planId,
          if (reason != null) 'reason': reason,
        },
      );
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'status': 'paused'};
    } catch (e) {
      throw Exception(SupabaseConfig.formatError(e));
    }
  }

  /// Resume a paused treatment plan
  Future<Map<String, dynamic>> resumePlan({
    required String planId,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'treatment-plans',
        body: {
          'action': 'resume_plan',
          'planId': planId,
        },
      );
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'status': 'active'};
    } catch (e) {
      throw Exception(SupabaseConfig.formatError(e));
    }
  }
}
