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

    return ConversationMessageModel(
      id: id,
      sender: map['sender'] ?? 'patient',
      text: map['text'] ?? '',
      timestamp: parseDate(map['timestamp']),
      status: map['status'] ?? 'sent',
      channel: map['channel'] ?? 'whatsapp',
      isUrgent: map['isUrgent'] ?? false,
      templateName: map['templateName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'channel': channel,
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
        return val.toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    return ConversationThreadModel(
      id: id,
      clinicId: map['clinicId'] ?? 'default-clinic',
      patientId: map['patientId'] ?? id,
      patientName: map['patientName'] ?? 'Patient',
      patientPhone: map['patientPhone'] ?? '',
      lastMessageText: map['lastMessageText'] ?? '',
      lastMessageAt: parseDate(map['lastMessageAt']),
      unreadCount: map['unreadCount'] ?? 0,
      isUrgent: map['isUrgent'] ?? false,
      assignedStaffId: map['assignedStaffId'],
      status: map['status'] ?? 'open',
      lastUserInboundAt: map['lastUserInboundAt'] != null ? parseDate(map['lastUserInboundAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clinicId': clinicId,
      'patientId': patientId,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'lastMessageText': lastMessageText,
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'unreadCount': unreadCount,
      'isUrgent': isUrgent,
      if (assignedStaffId != null) 'assignedStaffId': assignedStaffId,
      'status': status,
      if (lastUserInboundAt != null) 'lastUserInboundAt': lastUserInboundAt!.toIso8601String(),
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
