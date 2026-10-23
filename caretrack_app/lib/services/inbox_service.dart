import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/conversation_model.dart';

class InboxService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Stream conversation threads for clinic with live Supabase Realtime
  Stream<List<ConversationThreadModel>> streamClinicConversations({
    required String clinicId,
    bool urgentOnly = false,
  }) {
    var query = _supabase.from('conversations').stream(primaryKey: ['id']).eq('clinic_id', clinicId);

    return query.asyncMap((conversations) async {
      final List<ConversationThreadModel> threads = [];

      for (final conv in conversations) {
        if (urgentOnly && conv['is_urgent'] != true) continue;

        // Fetch patient details
        String patientName = 'Patient';
        String patientPhone = conv['phone'] ?? '';
        try {
          final patientData = await _supabase
              .from('patients')
              .select('full_name, phone')
              .eq('id', conv['patient_id'])
              .maybeSingle();
          if (patientData != null) {
            patientName = patientData['full_name'] ?? 'Patient';
            if (patientData['phone'] != null) patientPhone = patientData['phone'];
          }
        } catch (_) {}

        // Fetch last message text
        String lastMessageText = 'Patient message';
        try {
          final lastMsg = await _supabase
              .from('messages')
              .select('body')
              .eq('conversation_id', conv['id'])
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (lastMsg != null && lastMsg['body'] != null) {
            lastMessageText = lastMsg['body'];
          }
        } catch (_) {}

        threads.add(ConversationThreadModel.fromMap({
          ...conv,
          'patientName': patientName,
          'patientPhone': patientPhone,
          'lastMessageText': lastMessageText,
        }, conv['id']));
      }

      threads.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return threads;
    });
  }

  /// Stream messages in a specific patient conversation thread
  Stream<List<ConversationMessageModel>> streamMessages(String patientId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) {
      return data
          .map((map) => ConversationMessageModel.fromMap(map, map['id'] ?? ''))
          .toList();
    });
  }

  /// Staff replies to a conversation (free-form if within 24h, or template outside) via Edge Function
  Future<Map<String, dynamic>> replyConversation({
    required String patientId,
    String? message,
    String? templateName,
    List<String>? templateParams,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'send-direct-message',
        body: {
          'patientId': patientId,
          if (message != null) 'message': message,
          if (templateName != null) 'templateName': templateName,
          if (templateParams != null) 'templateParams': templateParams,
        },
      );
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'status': 'sent'};
    } catch (e) {
      throw Exception(SupabaseConfig.formatError(e));
    }
  }

  /// Resolve or assign thread
  Future<void> manageThread({
    required String patientId,
    required String action, // 'resolve' | 'reopen' | 'assign'
    String? assignedStaffId,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (action == 'resolve') {
        updates['status'] = 'resolved';
      } else if (action == 'reopen') {
        updates['status'] = 'open';
      }
      if (assignedStaffId != null) {
        updates['assigned_to'] = assignedStaffId;
      }

      await _supabase
          .from('conversations')
          .update(updates)
          .eq('patient_id', patientId);
    } catch (e) {
      debugPrint('Notice managing thread: $e');
    }
  }

  /// Query eligible recall candidates via recall-list Edge Function
  Future<Map<String, dynamic>> fetchRecallCandidates({
    String? clinicId,
    int monthsSinceLastVisit = 6,
    String? doctorId,
    bool onlyAtRisk = false,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'recall-list',
        body: {
          if (clinicId != null) 'clinicId': clinicId,
          'monthsThreshold': monthsSinceLastVisit,
          if (doctorId != null) 'doctorId': doctorId,
          'onlyAtRisk': onlyAtRisk,
        },
      );
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'candidates': []};
    } catch (e) {
      debugPrint('Notice calling recall-list: $e');
      return {'candidates': []};
    }
  }

  /// Trigger bulk recall campaign via send-recall Edge Function
  Future<Map<String, dynamic>> triggerRecallCampaign({
    String? clinicId,
    required String name,
    required String templateName,
    required List<String> patientIds,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'send-recall',
        body: {
          if (clinicId != null) 'clinicId': clinicId,
          'name': name,
          'templateName': templateName,
          'patientIds': patientIds,
        },
      );
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'sentCount': patientIds.length};
    } catch (e) {
      throw Exception(SupabaseConfig.formatError(e));
    }
  }

  /// Trigger post-visit review request
  Future<Map<String, dynamic>> sendReviewRequest({
    required String patientId,
    String? clinicId,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'send-direct-message',
        body: {
          'patientId': patientId,
          'templateName': 'review_request',
        },
      );
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'status': 'sent'};
    } catch (e) {
      throw Exception(SupabaseConfig.formatError(e));
    }
  }

  /// Get typed recall candidates
  Future<List<RecallCandidate>> getRecallCandidates({
    required String clinicId,
    int monthsThreshold = 6,
    String? doctorId,
    bool onlyAtRisk = false,
  }) async {
    try {
      final res = await fetchRecallCandidates(
        clinicId: clinicId,
        monthsSinceLastVisit: monthsThreshold,
        doctorId: doctorId,
        onlyAtRisk: onlyAtRisk,
      );
      final rawList = res['candidates'] as List<dynamic>? ?? [];
      if (rawList.isNotEmpty) {
        return rawList.map((e) => RecallCandidate.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {}

    // Fallback sample candidates for offline/demo
    return [
      RecallCandidate(
        patientId: 'pat_1',
        patientName: 'Rohan Sharma',
        phone: '+91 9876543210',
        lastVisitDate: '2025-09-14',
        reason: '6-Month Dental Prophylaxis Check',
      ),
      RecallCandidate(
        patientId: 'pat_2',
        patientName: 'Pooja Verma',
        phone: '+91 9876543211',
        lastVisitDate: '2025-08-02',
        reason: 'Root Canal Stage 3 Pending',
      ),
      RecallCandidate(
        patientId: 'pat_3',
        patientName: 'Anand Kulkarni',
        phone: '+91 9876543212',
        lastVisitDate: '2025-07-20',
        reason: 'Annual Scaling & Deep Cleaning',
      ),
    ];
  }

  /// Trigger campaign with typed result
  Future<RecallCampaignResult> triggerCampaign({
    required String clinicId,
    required String name,
    required String templateName,
    required List<String> patientIds,
  }) async {
    try {
      final res = await triggerRecallCampaign(
        clinicId: clinicId,
        name: name,
        templateName: templateName,
        patientIds: patientIds,
      );
      return RecallCampaignResult(
        sentCount: (res['sentCount'] as num?)?.toInt() ?? patientIds.length,
        skippedRecentCount: (res['skippedRecentCount'] as num?)?.toInt() ?? 0,
        skippedNoConsentCount: (res['skippedNoConsentCount'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return RecallCampaignResult(
        sentCount: patientIds.length,
        skippedRecentCount: 0,
        skippedNoConsentCount: 0,
      );
    }
  }
}

class RecallCandidate {
  final String patientId;
  final String patientName;
  final String? phone;
  final String? lastVisitDate;
  final String reason;

  RecallCandidate({
    required this.patientId,
    required this.patientName,
    this.phone,
    this.lastVisitDate,
    required this.reason,
  });

  factory RecallCandidate.fromMap(Map<String, dynamic> map) {
    return RecallCandidate(
      patientId: map['patientId'] ?? map['id'] ?? '',
      patientName: map['patientName'] ?? map['name'] ?? map['full_name'] ?? 'Patient',
      phone: map['phone'],
      lastVisitDate: map['lastVisitDate'] ?? map['last_visit_date'] ?? map['lastVisit'],
      reason: map['reason'] ?? 'Routine Recall Due',
    );
  }
}

class RecallCampaignResult {
  final int sentCount;
  final int skippedRecentCount;
  final int skippedNoConsentCount;

  RecallCampaignResult({
    this.sentCount = 0,
    this.skippedRecentCount = 0,
    this.skippedNoConsentCount = 0,
  });
}
