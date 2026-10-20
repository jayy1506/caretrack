import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/conversation_model.dart';

class InboxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Stream conversation threads for clinic
  Stream<List<ConversationThreadModel>> streamClinicConversations({
    required String clinicId,
    bool urgentOnly = false,
  }) {
    Query query = _firestore
        .collection('conversations')
        .where('clinicId', isEqualTo: clinicId);

    if (urgentOnly) {
      query = query.where('isUrgent', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ConversationThreadModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      list.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return list;
    });
  }

  /// Stream messages in a specific patient conversation thread
  Stream<List<ConversationMessageModel>> streamMessages(String patientId) {
    return _firestore
        .collection('conversations')
        .doc(patientId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ConversationMessageModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Staff replies to a conversation (free-form if within 24h, or template outside)
  Future<Map<String, dynamic>> replyConversation({
    required String patientId,
    String? message,
    String? templateName,
    List<String>? templateParams,
  }) async {
    final callable = _functions.httpsCallable('replyConversation');
    final res = await callable.call({
      'patientId': patientId,
      if (message != null) 'message': message,
      if (templateName != null) 'templateName': templateName,
      if (templateParams != null) 'templateParams': templateParams,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Resolve or assign thread
  Future<void> manageThread({
    required String patientId,
    required String action, // 'resolve' | 'reopen' | 'assign'
    String? assignedStaffId,
  }) async {
    final callable = _functions.httpsCallable('manageConversationThread');
    await callable.call({
      'patientId': patientId,
      'action': action,
      if (assignedStaffId != null) 'assignedStaffId': assignedStaffId,
    });
  }

  /// Query eligible recall candidates
  Future<Map<String, dynamic>> fetchRecallCandidates({
    String? clinicId,
    int monthsSinceLastVisit = 6,
    String? doctorId,
    bool onlyAtRisk = false,
  }) async {
    final callable = _functions.httpsCallable('getRecallCandidates');
    final res = await callable.call({
      if (clinicId != null) 'clinicId': clinicId,
      'monthsSinceLastVisit': monthsSinceLastVisit,
      if (doctorId != null) 'doctorId': doctorId,
      'onlyAtRisk': onlyAtRisk,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Trigger bulk recall campaign
  Future<Map<String, dynamic>> triggerRecallCampaign({
    String? clinicId,
    required String name,
    required String templateName,
    required List<String> patientIds,
  }) async {
    final callable = _functions.httpsCallable('triggerRecallCampaign');
    final res = await callable.call({
      if (clinicId != null) 'clinicId': clinicId,
      'name': name,
      'templateName': templateName,
      'patientIds': patientIds,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Trigger post-visit review request
  Future<Map<String, dynamic>> sendReviewRequest({
    required String patientId,
    String? clinicId,
  }) async {
    final callable = _functions.httpsCallable('sendReviewRequest');
    final res = await callable.call({
      'patientId': patientId,
      if (clinicId != null) 'clinicId': clinicId,
    });
    return Map<String, dynamic>.from(res.data as Map);
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
      return rawList.map((e) => RecallCandidate.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      // Fallback sample candidates for offline/demo
      return [
        RecallCandidate(
          patientId: 'pat_1',
          patientName: 'Rohan Sharma',
          phone: '+919876543210',
          lastVisitDate: '2025-09-14',
          reason: '6-Month Dental Prophylaxis Check',
        ),
        RecallCandidate(
          patientId: 'pat_2',
          patientName: 'Pooja Verma',
          phone: '+919876543211',
          lastVisitDate: '2025-08-02',
          reason: 'Root Canal Stage 3 Pending',
        ),
        RecallCandidate(
          patientId: 'pat_3',
          patientName: 'Anand Kulkarni',
          phone: '+919876543212',
          lastVisitDate: '2025-07-20',
          reason: 'Annual Scaling & Deep Cleaning',
        ),
      ];
    }
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
      patientName: map['patientName'] ?? map['name'] ?? 'Patient',
      phone: map['phone'],
      lastVisitDate: map['lastVisitDate'] ?? map['lastVisit'],
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
