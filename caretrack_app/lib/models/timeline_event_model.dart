import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum TimelineEventType {
  registration,
  prescription,
  followUpScheduled,
  reminderSent,
  appointmentConfirmed,
  appointmentRescheduled,
  appointmentCompleted,
  appointmentMissed,
  appointmentScheduled,
}

class TimelineEventModel {
  final String id;
  final String title;
  final String? subtitle;
  final DateTime timestamp;
  final TimelineEventType type;
  final String? details;

  TimelineEventModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.timestamp,
    required this.type,
    this.details,
  });

  IconData get icon {
    switch (type) {
      case TimelineEventType.registration:
        return Icons.person_add_outlined;
      case TimelineEventType.prescription:
        return Icons.medication_outlined;
      case TimelineEventType.followUpScheduled:
        return Icons.event_repeat;
      case TimelineEventType.reminderSent:
        return Icons.notifications_active_outlined;
      case TimelineEventType.appointmentConfirmed:
        return Icons.check_circle_outline;
      case TimelineEventType.appointmentRescheduled:
        return Icons.schedule_outlined;
      case TimelineEventType.appointmentCompleted:
        return Icons.task_alt;
      case TimelineEventType.appointmentMissed:
        return Icons.cancel_outlined;
      case TimelineEventType.appointmentScheduled:
        return Icons.calendar_month_outlined;
    }
  }

  Color get color {
    switch (type) {
      case TimelineEventType.registration:
      case TimelineEventType.prescription:
        return AppTheme.primaryNavy;
      case TimelineEventType.appointmentConfirmed:
      case TimelineEventType.appointmentCompleted:
        return AppTheme.statusSuccess;
      case TimelineEventType.followUpScheduled:
      case TimelineEventType.appointmentRescheduled:
        return AppTheme.statusPurple;
      case TimelineEventType.reminderSent:
      case TimelineEventType.appointmentScheduled:
        return AppTheme.primaryBlue;
      case TimelineEventType.appointmentMissed:
        return AppTheme.statusDanger;
    }
  }
}
