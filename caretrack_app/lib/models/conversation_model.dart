class ConversationMessageModel {
  final String id;
  final String sender; // 'patient' | 'clinic'
  final String text;
  final DateTime timestamp;
  final String status; // 'sent' | 'delivered' | 'read' | 'failed'
  final String channel; // 'whatsapp' | 'email' | 'sms'
  final bool isUrgent;
  final String? templateName;

  ConversationMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.status = 'sent',
    this.channel = 'whatsapp',
    this.isUrgent = false,
    this.templateName,
  });

  bool get isFromPatient => sender == 'patient';
  bool get isFromClinic => sender == 'clinic';

  factory ConversationMessageModel.fromMap(Map<String, dynamic> map, String id) {
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

    var senderType = map['sender'] ?? 'patient';
    if (map['direction'] == 'inbound' || map['sender_type'] == 'patient') {
      senderType = 'patient';
    } else if (map['direction'] == 'outbound' || map['sender_type'] == 'staff') {
      senderType = 'clinic';
    }

    return ConversationMessageModel(
      id: map['id'] ?? id,
      sender: senderType,
      text: map['body'] ?? map['text'] ?? '',
      timestamp: parseDate(map['created_at'] ?? map['timestamp']),
      status: map['status'] ?? 'sent',
      channel: map['channel'] ?? 'whatsapp',
      isUrgent: map['is_urgent'] ?? map['isUrgent'] ?? false,
      templateName: map['template_name'] ?? map['templateName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'body': text,
      'text': text,
      'created_at': timestamp.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'channel': channel,
      'is_urgent': isUrgent,
      'isUrgent': isUrgent,
      if (templateName != null) 'templateName': templateName,
    };
  }
}

class ConversationThreadModel {
  final String id;
  final String clinicId;
  final String patientId;
  final String patientName;
  final String patientPhone;
  final String lastMessageText;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isUrgent;
  final String? assignedStaffId;
  final String status; // 'open' | 'resolved'
  final DateTime? lastUserInboundAt;

  ConversationThreadModel({
    required this.id,
    this.clinicId = 'default-clinic',
    required this.patientId,
    required this.patientName,
    required this.patientPhone,
    required this.lastMessageText,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isUrgent = false,
    this.assignedStaffId,
    this.status = 'open',
    this.lastUserInboundAt,
  });

  bool get isOpen => status == 'open';
  bool get isResolved => status == 'resolved';
  bool get isInside24hWindow {
    if (lastUserInboundAt == null) return false;
    return DateTime.now().difference(lastUserInboundAt!).inHours < 24;
  }

  factory ConversationThreadModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      try {
        return (val as dynamic).toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    final patientData = map['patients'] is Map ? map['patients'] as Map : null;
    final resolvedPatientName =
        patientData?['full_name'] ?? patientData?['name'] ?? map['patientName'] ?? 'Patient';
    final resolvedPhone =
        patientData?['phone'] ?? map['phone'] ?? map['patientPhone'] ?? '';

    return ConversationThreadModel(
      id: map['id'] ?? id,
      clinicId: map['clinic_id'] ?? map['clinicId'] ?? 'default-clinic',
      patientId: map['patient_id'] ?? map['patientId'] ?? id,
      patientName: resolvedPatientName.toString(),
      patientPhone: resolvedPhone.toString(),
      lastMessageText: map['last_message_text'] ?? map['lastMessageText'] ?? 'Patient inquiry',
      lastMessageAt: parseDate(map['last_message_at'] ?? map['lastMessageAt']),
      unreadCount: map['unread_count'] ?? map['unreadCount'] ?? 0,
      isUrgent: map['is_urgent'] ?? map['isUrgent'] ?? false,
      assignedStaffId: map['assigned_to'] ?? map['assignedStaffId'],
      status: map['status'] ?? 'open',
      lastUserInboundAt: map['last_message_at'] != null ? parseDate(map['last_message_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'clinicId': clinicId,
      'patient_id': patientId,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'last_message_text': lastMessageText,
      'lastMessageText': lastMessageText,
      'last_message_at': lastMessageAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'unreadCount': unreadCount,
      'is_urgent': isUrgent,
      'isUrgent': isUrgent,
      if (assignedStaffId != null) 'assigned_to': assignedStaffId,
      'status': status,
    };
  }
}

class RecallCampaignModel {
  final String id;
  final String clinicId;
  final String name;
  final String templateName;
  final int targetCount;
  final int sentCount;
  final int skippedConsentCount;
  final int skippedRecentCount;
  final int repliedCount;
  final int bookedCount;
  final DateTime createdAt;
  final String status;

  RecallCampaignModel({
    required this.id,
    required this.clinicId,
    required this.name,
    required this.templateName,
    required this.targetCount,
    required this.sentCount,
    required this.skippedConsentCount,
    required this.skippedRecentCount,
    required this.repliedCount,
    required this.bookedCount,
    required this.createdAt,
    required this.status,
  });

  factory RecallCampaignModel.fromMap(Map<String, dynamic> map, String id) {
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

    return RecallCampaignModel(
      id: id,
      clinicId: map['clinicId'] ?? 'default-clinic',
      name: map['name'] ?? '',
      templateName: map['templateName'] ?? '',
      targetCount: map['targetCount'] ?? 0,
      sentCount: map['sentCount'] ?? 0,
      skippedConsentCount: map['skippedConsentCount'] ?? 0,
      skippedRecentCount: map['skippedRecentCount'] ?? 0,
      repliedCount: map['repliedCount'] ?? 0,
      bookedCount: map['bookedCount'] ?? 0,
      createdAt: parseDate(map['createdAt']),
      status: map['status'] ?? 'completed',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clinicId': clinicId,
      'name': name,
      'templateName': templateName,
      'targetCount': targetCount,
      'sentCount': sentCount,
      'skippedConsentCount': skippedConsentCount,
      'skippedRecentCount': skippedRecentCount,
      'repliedCount': repliedCount,
      'bookedCount': bookedCount,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }
}
