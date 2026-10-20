import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/medication_schedule_model.dart';

class MedicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Stream active and past medication schedules for a patient
  Stream<List<MedicationScheduleModel>> streamPatientSchedules(String patientId) {
    return _firestore
        .collection('medicationSchedules')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MedicationScheduleModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Generate draft schedule from prescription
  Future<Map<String, dynamic>> generateSchedule({
    required String prescriptionId,
    Map<String, dynamic>? customWindows,
  }) async {
    final callable = _functions.httpsCallable('generateMedicationSchedule');
    final res = await callable.call({
      'prescriptionId': prescriptionId,
      if (customWindows != null) 'customWindows': customWindows,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Doctor confirms or customizes medication schedule
  Future<Map<String, dynamic>> confirmSchedule({
    required String scheduleId,
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? timeWindows,
  }) async {
    final callable = _functions.httpsCallable('confirmMedicationSchedule');
    final res = await callable.call({
      'scheduleId': scheduleId,
      if (items != null) 'items': items,
      if (timeWindows != null) 'timeWindows': timeWindows,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Fetch patient medication schedules & adherence statistics
  Future<List<MedicationScheduleModel>> fetchPatientSchedules(String patientId) async {
    final snapshot = await _firestore
        .collection('medicationSchedules')
        .where('patientId', isEqualTo: patientId)
        .get();

    return snapshot.docs
        .map((doc) => MedicationScheduleModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Alias for fetchPatientSchedules
  Future<List<MedicationScheduleModel>> getPatientSchedules({required String patientId}) {
    return fetchPatientSchedules(patientId);
  }
}
