import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/prescription_model.dart';
import '../models/appointment_model.dart';
import '../models/notification_model.dart';
import 'offline_store.dart';

class PrescriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Stream prescriptions for a specific patient
  Stream<List<PrescriptionModel>> streamPatientPrescriptions(String patientId) {
    return _firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PrescriptionModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Upload prescription file to Firebase Storage
  Future<String> uploadPrescriptionFile({
    required String doctorId,
    required String patientId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final path = 'prescriptions/$doctorId/$patientId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child(path);

    final metadata = SettableMetadata(contentType: mimeType);
    final uploadTask = await ref.putData(bytes, metadata);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Trigger Gemini AI extraction via Cloud Functions
  Future<Map<String, dynamic>> extractFromPrescription({
    String? storagePath,
    Uint8List? fileBytes,
    String? mimeType,
  }) async {
    final callable = _functions.httpsCallable('extractPrescriptionData');

    String? base64Data;
    if (fileBytes != null) {
      base64Data = base64Encode(fileBytes);
    }

    final response = await callable.call({
      'storagePath': storagePath,
      'base64Data': base64Data,
      'mimeType': mimeType ?? 'image/jpeg',
    });

    return Map<String, dynamic>.from(response.data);
  }

  /// Confirm and save prescription & auto-create follow-up appointment
  Future<String> savePrescriptionAndScheduleFollowUp({
    required String doctorId,
    required String patientId,
    required String prescriptionDate,
    required String source,
    String? originalFileUrl,
    required List<MedicineItemModel> medicines,
    required String followUpType,
    required String followUpDate,
    required bool aiExtracted,
    String? appointmentTime = '10:00 AM',
    String? notes,
  }) async {
    final presRef = _firestore.collection('prescriptions').doc();
    final now = DateTime.now();

    final prescription = PrescriptionModel(
      id: presRef.id,
      doctorId: doctorId,
      patientId: patientId,
      prescriptionDate: prescriptionDate,
      source: source,
      originalFileUrl: originalFileUrl,
      medicines: medicines,
      followUpType: followUpType,
      followUpDate: followUpDate,
      aiExtracted: aiExtracted,
      doctorConfirmed: true,
      createdAt: now,
    );

    // Save to local store immediately (<1ms)
    OfflineStore().addPrescription(prescription);

    try {
      await presRef.set(prescription.toMap()).timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {},
      );
    } catch (_) {}

    // Automatically create follow-up appointment
    final apptRef = _firestore.collection('appointments').doc();
    final appointment = AppointmentModel(
      id: apptRef.id,
      doctorId: doctorId,
      patientId: patientId,
      date: followUpDate,
      time: appointmentTime ?? '10:00 AM',
      type: 'Follow-up',
      reason: 'Prescription Follow-up (${followUpType.replaceAll('_', ' ')})',
      notes: notes,
      status: 'Scheduled',
      confirmationStatus: 'Pending',
      reminder24hSent: false,
      createdAt: now,
      updatedAt: now,
    );

    OfflineStore().addAppointment(appointment);

    // Look up patient for notification
    final patient = OfflineStore().patients[patientId];
    if (patient?.phone != null && patient!.phone!.isNotEmpty) {
      final smsNotif = NotificationModel(
        id: 'notif_sms_rx_${presRef.id}',
        doctorId: doctorId,
        patientId: patientId,
        appointmentId: apptRef.id,
        channel: 'sms',
        type: 'followup_reminder',
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
        id: 'notif_email_rx_${presRef.id}',
        doctorId: doctorId,
        patientId: patientId,
        appointmentId: apptRef.id,
        channel: 'email',
        type: 'followup_reminder',
        recipient: patient.email!,
        status: 'Sent',
        sentAt: now,
        createdAt: now,
      );
      OfflineStore().addNotification(emailNotif);
      _firestore.collection('notifications').doc(emailNotif.id).set(emailNotif.toMap()).catchError((_) {});
    }

    _firestore.collection('prescriptions').doc(presRef.id).set(prescription.toMap()).catchError((_) {});
    _firestore.collection('appointments').doc(apptRef.id).set(appointment.toMap()).catchError((_) {});

    return presRef.id;
  }
}
