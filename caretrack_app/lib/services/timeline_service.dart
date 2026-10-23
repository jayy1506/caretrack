import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/patient_model.dart';
import '../models/prescription_model.dart';
import '../models/appointment_model.dart';
import '../models/notification_model.dart';
import '../models/timeline_event_model.dart';
import '../core/utils/date_formatter.dart';

class TimelineService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Fetches and synthesizes the chronological patient journey timeline from Supabase
  Future<List<TimelineEventModel>> getPatientTimeline(String patientId) async {
    final List<TimelineEventModel> events = [];

    // 1. Patient Registration Event
    try {
      final patientDoc = await _supabase.from('patients').select('*').eq('id', patientId).maybeSingle();
      if (patientDoc != null) {
        final patient = PatientModel.fromMap(patientDoc, patientId);
        events.add(TimelineEventModel(
          id: 'reg_${patient.id}',
          title: 'Patient Registered',
          subtitle: 'Profile created in CareTrack',
          timestamp: patient.createdAt,
          type: TimelineEventType.registration,
          details: 'Contact: ${patient.phone ?? patient.email ?? "Not specified"}',
        ));
      }
    } catch (_) {}

    // 2. Prescriptions & Follow-ups Scheduled Events
    try {
      final presData = await _supabase
          .from('prescriptions')
          .select('*')
          .eq('patient_id', patientId);

      for (final doc in presData as List<dynamic>) {
        final map = Map<String, dynamic>.from(doc as Map);
        final pres = PrescriptionModel.fromMap(map, map['id'] ?? '');
        final medCount = pres.medicines.length;
        final medNames = pres.medicines.map((m) => m.name).take(2).join(', ');

        events.add(TimelineEventModel(
          id: 'pres_${pres.id}',
          title: 'Prescription Added',
          subtitle: '$medCount medicine(s): $medNames${medCount > 2 ? "..." : ""}',
          timestamp: pres.createdAt,
          type: TimelineEventType.prescription,
          details: 'Source: ${pres.source == "upload" ? "Uploaded Document (AI Verified)" : "Manual Entry"}',
        ));

        if (pres.followUpDate.isNotEmpty) {
          final followUpDt = DateUtilsHelper.parseStorageDate(pres.followUpDate);
          events.add(TimelineEventModel(
            id: 'follow_${pres.id}',
            title: 'Follow-up Scheduled',
            subtitle: 'Due date: ${DateUtilsHelper.formatDisplayDate(followUpDt)}',
            timestamp: pres.createdAt.add(const Duration(minutes: 1)),
            type: TimelineEventType.followUpScheduled,
            details: 'Interval: ${pres.followUpType.replaceAll("_", " ")}',
          ));
        }
      }
    } catch (_) {}

    // 3. Appointments Events
    try {
      final apptData = await _supabase
          .from('appointments')
          .select('*')
          .eq('patient_id', patientId);

      for (final doc in apptData as List<dynamic>) {
        final map = Map<String, dynamic>.from(doc as Map);
        final appt = AppointmentModel.fromMap(map, map['id'] ?? '');
        final apptDt = DateUtilsHelper.parseStorageDate(appt.date);

        if (appt.status.toLowerCase() == 'completed') {
          events.add(TimelineEventModel(
            id: 'comp_${appt.id}',
            title: 'Appointment Completed',
            subtitle: '${appt.type} at ${appt.time}',
            timestamp: appt.updatedAt,
            type: TimelineEventType.appointmentCompleted,
            details: appt.notes ?? 'Consultation finished',
          ));
        } else if (appt.status.toLowerCase() == 'missed') {
          events.add(TimelineEventModel(
            id: 'miss_${appt.id}',
            title: 'Appointment Missed',
            subtitle: 'Scheduled on ${DateUtilsHelper.formatDisplayDate(apptDt)} at ${appt.time}',
            timestamp: appt.updatedAt,
            type: TimelineEventType.appointmentMissed,
            details: 'Follow-up required',
          ));
        } else if (appt.isConfirmed) {
          events.add(TimelineEventModel(
            id: 'conf_${appt.id}',
            title: 'Appointment Confirmed',
            subtitle: '${DateUtilsHelper.formatDisplayDate(apptDt)} at ${appt.time}',
            timestamp: appt.updatedAt,
            type: TimelineEventType.appointmentConfirmed,
          ));
        } else if (appt.isRescheduleRequested) {
          events.add(TimelineEventModel(
            id: 'resch_${appt.id}',
            title: 'Reschedule Requested',
            subtitle: 'Patient requested new slot for ${DateUtilsHelper.formatDisplayDate(apptDt)}',
            timestamp: appt.updatedAt,
            type: TimelineEventType.appointmentRescheduled,
          ));
        } else {
          events.add(TimelineEventModel(
            id: 'sched_${appt.id}',
            title: 'Appointment Scheduled',
            subtitle: '${DateUtilsHelper.formatDisplayDate(apptDt)} at ${appt.time}',
            timestamp: appt.createdAt,
            type: TimelineEventType.appointmentScheduled,
            details: appt.reason,
          ));
        }
      }
    } catch (_) {}

    // 4. Notifications / Reminders Events
    try {
      final notifData = await _supabase
          .from('notifications')
          .select('*')
          .eq('patient_id', patientId);

      for (final doc in notifData as List<dynamic>) {
        final map = Map<String, dynamic>.from(doc as Map);
        final notif = NotificationModel.fromMap(map, map['id'] ?? '');
        events.add(TimelineEventModel(
          id: 'notif_${notif.id}',
          title: notif.readableType,
          subtitle: 'Via ${notif.channel.toUpperCase()} to ${notif.recipient}',
          timestamp: notif.sentAt ?? notif.createdAt,
          type: TimelineEventType.reminderSent,
          details: 'Status: ${notif.status}',
        ));
      }
    } catch (_) {}

    // Sort chronologically ascending
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return events;
  }
}
