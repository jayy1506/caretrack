import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_model.dart';
import '../models/prescription_model.dart';
import '../models/appointment_model.dart';
import '../models/notification_model.dart';
import '../models/timeline_event_model.dart';
import '../core/utils/date_formatter.dart';

class TimelineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches and synthesizes the chronological patient journey timeline
  Future<List<TimelineEventModel>> getPatientTimeline(String patientId) async {
    final List<TimelineEventModel> events = [];

    // 1. Patient Registration Event
    final patientDoc = await _firestore.collection('patients').doc(patientId).get();
    if (patientDoc.exists && patientDoc.data() != null) {
      final patient = PatientModel.fromMap(patientDoc.data()!, patientDoc.id);
      events.add(TimelineEventModel(
        id: 'reg_${patient.id}',
        title: 'Patient Registered',
        subtitle: 'Profile created in CareTrack',
        timestamp: patient.createdAt,
        type: TimelineEventType.registration,
        details: 'Contact: ${patient.phone ?? patient.email ?? "Not specified"}',
      ));
    }

    // 2. Prescriptions & Follow-ups Scheduled Events
    final presSnap = await _firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .get();

    for (final doc in presSnap.docs) {
      final pres = PrescriptionModel.fromMap(doc.data(), doc.id);
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

    // 3. Appointments Events
    final apptSnap = await _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .get();

    for (final doc in apptSnap.docs) {
      final appt = AppointmentModel.fromMap(doc.data(), doc.id);
      final apptDt = DateUtilsHelper.parseStorageDate(appt.date);

      if (appt.status == 'Completed') {
        events.add(TimelineEventModel(
          id: 'comp_${appt.id}',
          title: 'Appointment Completed',
          subtitle: '${appt.type} at ${appt.time}',
          timestamp: appt.updatedAt,
          type: TimelineEventType.appointmentCompleted,
          details: appt.notes ?? 'Consultation finished',
        ));
      } else if (appt.status == 'Missed') {
        events.add(TimelineEventModel(
          id: 'miss_${appt.id}',
          title: 'Appointment Missed',
          subtitle: 'Scheduled on ${DateUtilsHelper.formatDisplayDate(apptDt)} at ${appt.time}',
          timestamp: appt.updatedAt,
          type: TimelineEventType.appointmentMissed,
          details: 'Follow-up required',
        ));
      } else if (appt.confirmationStatus == 'Confirmed') {
        events.add(TimelineEventModel(
          id: 'conf_${appt.id}',
          title: 'Appointment Confirmed',
          subtitle: '${DateUtilsHelper.formatDisplayDate(apptDt)} at ${appt.time}',
          timestamp: appt.updatedAt,
          type: TimelineEventType.appointmentConfirmed,
        ));
      } else if (appt.confirmationStatus == 'Reschedule Requested') {
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

    // 4. Notifications / Reminders Events
    final notifSnap = await _firestore
        .collection('notifications')
        .where('patientId', isEqualTo: patientId)
        .get();

    for (final doc in notifSnap.docs) {
      final notif = NotificationModel.fromMap(doc.data(), doc.id);
      if (notif.status == 'Sent' || notif.status == 'Delivered') {
        events.add(TimelineEventModel(
          id: 'notif_${notif.id}',
          title: notif.readableType,
          subtitle: 'Via ${notif.channel.toUpperCase()} to ${notif.recipient}',
          timestamp: notif.sentAt ?? notif.createdAt,
          type: TimelineEventType.reminderSent,
          details: 'Status: ${notif.status}',
        ));
      }
    }

    // Sort chronologically ascending
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return events;
  }
}
