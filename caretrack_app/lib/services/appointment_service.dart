import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/appointment_model.dart';
import '../models/notification_model.dart';
import 'offline_store.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Stream all appointments for a doctor with instant offline fallback
  Stream<List<AppointmentModel>> streamDoctorAppointments(String doctorId) {
    final controller = StreamController<List<AppointmentModel>>.broadcast();

    // 1. Emit local/ayurveda stored appointments immediately (<1ms)
    controller.add(OfflineStore().getDoctorAppointments(doctorId));

    // 2. Listen to real-time local additions
    final subLocal = OfflineStore().appointmentsStream.listen((_) {
      controller.add(OfflineStore().getDoctorAppointments(doctorId));
    });

    // 3. Listen to Firestore stream in background if online
    StreamSubscription? subRemote;
    try {
      subRemote = _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .snapshots()
          .listen((snapshot) {
        final remoteList = snapshot.docs
            .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
            .toList();

        final merged = <String, AppointmentModel>{};
        for (final a in OfflineStore().getDoctorAppointments(doctorId)) {
          merged[a.id] = a;
        }
        for (final a in remoteList) {
          merged[a.id] = a;
        }

        final result = merged.values.toList();
        result.sort((a, b) => a.date.compareTo(b.date));
        controller.add(result);
      }, onError: (_) {
        controller.add(OfflineStore().getDoctorAppointments(doctorId));
      });
    } catch (_) {}

    controller.onCancel = () {
      subLocal.cancel();
      subRemote?.cancel();
    };

    return controller.stream;
  }

  /// Stream appointments for a specific patient
  Stream<List<AppointmentModel>> streamPatientAppointments(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }

  /// Create a new appointment
  Future<String> createAppointment({
    required String doctorId,
    required String patientId,
    required String date,
    required String time,
    required String type,
    String? clinicId,
    String? reason,
    String? notes,
  }) async {
    final docRef = _firestore.collection('appointments').doc();
    final now = DateTime.now();

    final appt = AppointmentModel(
      id: docRef.id,
      clinicId: clinicId ?? 'default-clinic',
      doctorId: doctorId,
      patientId: patientId,
      date: date,
      time: time,
      type: type,
      reason: reason,
      notes: notes,
      status: 'Scheduled',
      confirmationStatus: 'Pending',
      reminder24hSent: false,
      createdAt: now,
      updatedAt: now,
    );

    // Save to local store immediately (<1ms)
    OfflineStore().addAppointment(appt);

    // Look up patient for contact details
    final patient = OfflineStore().patients[patientId];
    if (patient?.phone != null && patient!.phone!.isNotEmpty) {
      final smsNotif = NotificationModel(
        id: 'notif_sms_appt_${docRef.id}',
        doctorId: doctorId,
        patientId: patientId,
        appointmentId: docRef.id,
        channel: 'sms',
        type: 'appointment_confirmation',
        recipient: patient.phone!,
        status: 'Sent',
        sentAt: now,
        createdAt: now,
      );
      OfflineStore().addNotification(smsNotif);
      _firestore.collection('notifications').doc(smsNotif.id).set(smsNotif.toMap()).catchError((_) {});
    }

    if (patient?.email != null && patient!.email!.isNotEmpty) {
      final emailNotif = NotificationModel(
        id: 'notif_email_appt_${docRef.id}',
        doctorId: doctorId,
        patientId: patientId,
        appointmentId: docRef.id,
        channel: 'email',
        type: 'appointment_confirmation',
        recipient: patient.email!,
        status: 'Sent',
        sentAt: now,
        createdAt: now,
      );
      OfflineStore().addNotification(emailNotif);
      _firestore.collection('notifications').doc(emailNotif.id).set(emailNotif.toMap()).catchError((_) {});
    }

    _firestore.collection('appointments').doc(docRef.id).set(appt.toMap()).catchError((_) {});

    // Send confirmation notifications asynchronously
    _functions
        .httpsCallable('sendAppointmentConfirmation')
        .call({'appointmentId': docRef.id})
        .then((_) {})
        .catchError((_) {});

    return docRef.id;
  }

  /// Update appointment status (Completed, Missed, Rescheduled, Cancelled)
  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? confirmationStatus,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (confirmationStatus != null) {
      updates['confirmationStatus'] = confirmationStatus;
    }

    await _firestore.collection('appointments').doc(appointmentId).update(updates);
  }

  /// Reschedule an appointment to a new date/time
  Future<void> rescheduleAppointment({
    required String appointmentId,
    required String newDate,
    required String newTime,
    String? reason,
  }) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'date': newDate,
      'time': newTime,
      'status': 'Scheduled',
      'confirmationStatus': 'Pending',
      'reminder24hSent': false,
      'reason': reason ?? 'Rescheduled',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // Send new confirmation notification asynchronously
    _functions
        .httpsCallable('sendAppointmentConfirmation')
        .call({'appointmentId': appointmentId})
        .then((_) {})
        .catchError((_) {});
  }

  /// Cancel an appointment
  Future<void> cancelAppointment(String appointmentId) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': 'Cancelled',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Permanently delete an appointment
  Future<void> deleteAppointment(String appointmentId) async {
    await _firestore.collection('appointments').doc(appointmentId).delete();
  }
}
