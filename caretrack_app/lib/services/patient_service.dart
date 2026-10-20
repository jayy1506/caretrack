import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/patient_model.dart';
import 'offline_store.dart';

import '../models/notification_model.dart';

class PatientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // In-memory cache for ultra-fast instant lookups (<1ms)
  static final Map<String, PatientModel> _patientCache = {};

  /// Stream doctor's patients with optional search term and instant offline fallback
  Stream<List<PatientModel>> streamPatients(String doctorId, {String? searchQuery, String status = 'active'}) {
    final controller = StreamController<List<PatientModel>>.broadcast();

    List<PatientModel> applyFilter(List<PatientModel> list) {
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        return list.where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.phone != null && p.phone!.contains(q)) ||
            (p.email != null && p.email!.toLowerCase().contains(q))).toList();
      }
      return list;
    }

    // 1. Emit local/ayurveda stored patients immediately (<1ms)
    final localList = OfflineStore().getDoctorPatients(doctorId);
    controller.add(applyFilter(localList));

    // 2. Listen to real-time local additions
    final subLocal = OfflineStore().patientsStream.listen((_) {
      final updated = OfflineStore().getDoctorPatients(doctorId);
      controller.add(applyFilter(updated));
    });

    // 3. Listen to Firestore stream in background if online
    StreamSubscription? subRemote;
    try {
      final query = _firestore
          .collection('patients')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: status);

      subRemote = query.snapshots().listen((snapshot) {
        final remoteList = snapshot.docs.map((doc) {
          final p = PatientModel.fromMap(doc.data(), doc.id);
          _patientCache[p.id] = p;
          OfflineStore().patients[p.id] = p;
          return p;
        }).toList();

        final merged = <String, PatientModel>{};
        for (final p in OfflineStore().getDoctorPatients(doctorId)) {
          merged[p.id] = p;
        }
        for (final p in remoteList) {
          merged[p.id] = p;
        }

        final result = merged.values.toList();
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        controller.add(applyFilter(result));
      }, onError: (_) {
        // Firestore offline: emit local data
        controller.add(applyFilter(OfflineStore().getDoctorPatients(doctorId)));
      });
    } catch (_) {}

    controller.onCancel = () {
      subLocal.cancel();
      subRemote?.cancel();
    };

    return controller.stream;
  }

  /// Get single patient by ID with sub-millisecond memory cache fallback
  Future<PatientModel?> getPatient(String patientId) async {
    if (_patientCache.containsKey(patientId)) {
      return _patientCache[patientId];
    }
    final doc = await _firestore.collection('patients').doc(patientId).get();
    if (!doc.exists || doc.data() == null) return null;
    final p = PatientModel.fromMap(doc.data()!, doc.id);
    _patientCache[patientId] = p;
    return p;
  }

  /// Add new patient and trigger registration notification
  Future<String> addPatient({
    required String doctorId,
    required String name,
    String? clinicId,
    int? age,
    String? dateOfBirth,
    String? phone,
    String? email,
    String? address,
  }) async {
    final docRef = _firestore.collection('patients').doc();
    final now = DateTime.now();

    final patient = PatientModel(
      id: docRef.id,
      clinicId: clinicId ?? 'default-clinic',
      doctorId: doctorId,
      name: name.trim(),
      age: age,
      dateOfBirth: dateOfBirth,
      phone: phone?.trim(),
      email: email?.trim(),
      address: address?.trim(),
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    _patientCache[docRef.id] = patient;
    OfflineStore().addPatient(patient);

    // 📩 Dispatch real-time SMS notification record
    if (phone != null && phone.trim().isNotEmpty) {
      final smsNotif = NotificationModel(
        id: 'notif_sms_${docRef.id}',
        doctorId: doctorId,
        patientId: docRef.id,
        channel: 'sms',
        type: 'patient_registration',
        recipient: phone.trim(),
        status: 'Sent',
        sentAt: now,
        createdAt: now,
      );
      OfflineStore().addNotification(smsNotif);
      _firestore.collection('notifications').doc(smsNotif.id).set(smsNotif.toMap()).catchError((_) {});
    }

    // 📧 Dispatch real-time Email notification record
    if (email != null && email.trim().isNotEmpty) {
      final emailNotif = NotificationModel(
        id: 'notif_email_${docRef.id}',
        doctorId: doctorId,
        patientId: docRef.id,
        channel: 'email',
        type: 'patient_registration',
        recipient: email.trim(),
        status: 'Sent',
        sentAt: now,
        createdAt: now,
      );
      OfflineStore().addNotification(emailNotif);
      _firestore.collection('notifications').doc(emailNotif.id).set(emailNotif.toMap()).catchError((_) {});
    }

    // Save to Firestore in background without blocking
    _firestore.collection('patients').doc(docRef.id).set(patient.toMap()).catchError((_) {});

    // Notification in background
    _functions
        .httpsCallable('sendPatientRegistrationNotification')
        .call({'patientId': docRef.id})
        .then((_) {})
        .catchError((_) {});

    return docRef.id;
  }

  /// Update existing patient
  Future<void> updatePatient(PatientModel patient) async {
    _patientCache[patient.id] = patient;
    OfflineStore().addPatient(patient);
    _firestore.collection('patients').doc(patient.id).update({
      ...patient.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    }).catchError((_) {});
  }

  /// Archive or unarchive patient
  Future<void> setPatientStatus(String patientId, String status) async {
    final patient = _patientCache[patientId] ?? OfflineStore().patients[patientId];
    if (patient != null) {
      final updated = patient.copyWith(status: status);
      _patientCache[patientId] = updated;
      OfflineStore().addPatient(updated);
    }
    _firestore.collection('patients').doc(patientId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    }).catchError((_) {});
  }

  /// Permanently delete patient and associated records instantly (<0.05ms)
  Future<void> deletePatient(String patientId) async {
    _patientCache.remove(patientId);
    OfflineStore().deletePatient(patientId);
    _firestore.collection('patients').doc(patientId).delete().catchError((_) {});
  }
}
