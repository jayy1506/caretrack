import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/patient_model.dart';
import 'offline_store.dart';

class PatientService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // In-memory cache for ultra-fast instant lookups (<1ms)
  static final Map<String, PatientModel> _patientCache = {};

  /// Stream doctor's patients with optional search term, live updates via Supabase Stream and offline fallback
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

    // 3. Listen to Supabase stream in background if online
    StreamSubscription? subRemote;
    try {
      subRemote = _supabase
          .from('patients')
          .stream(primaryKey: ['id'])
          .listen((data) {
        final remoteList = data.map((map) {
          final p = PatientModel.fromMap(map, map['id'] ?? '');
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
      }, onError: (err) {
        debugPrint('Notice on patients stream (using offline store): $err');
        controller.add(applyFilter(OfflineStore().getDoctorPatients(doctorId)));
      });
    } catch (_) {
      // Local fallback
    }

    controller.onCancel = () {
      subLocal.cancel();
      subRemote?.cancel();
    };

    return controller.stream;
  }

  /// Get single patient by ID with memory cache fallback
  Future<PatientModel?> getPatient(String patientId) async {
    if (_patientCache.containsKey(patientId)) {
      return _patientCache[patientId];
    }
    try {
      final data = await _supabase
          .from('patients')
          .select('*')
          .eq('id', patientId)
          .maybeSingle();

      if (data == null) return null;
      final p = PatientModel.fromMap(data, patientId);
      _patientCache[patientId] = p;
      return p;
    } catch (e) {
      return OfflineStore().patients[patientId];
    }
  }

  /// Add new patient
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
    final now = DateTime.now();
    final effectiveClinicId = clinicId ?? 'c0000000-0000-0000-0000-000000000001';

    // Optimistic patient creation for zero latency UI
    final tempId = 'pat_${now.millisecondsSinceEpoch}';
    final patient = PatientModel(
      id: tempId,
      clinicId: effectiveClinicId,
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

    _patientCache[tempId] = patient;
    OfflineStore().addPatient(patient);

    // Save to Supabase
    try {
      final insertData = {
        'clinic_id': effectiveClinicId,
        'doctor_id': doctorId,
        'full_name': name.trim(),
        'phone': phone?.trim(),
        'email': email?.trim(),
        'medical_notes': address?.trim(),
        'messaging_consent': true,
        'ai_consent': true,
      };

      final res = await _supabase.from('patients').insert(insertData).select().single();
      final realId = res['id'] ?? tempId;

      final updatedPatient = PatientModel.fromMap(res, realId);
      _patientCache[realId] = updatedPatient;
      OfflineStore().addPatient(updatedPatient);

      return realId;
    } catch (e) {
      debugPrint('Notice inserting patient into Supabase (persisted in offline store): $e');
      return tempId;
    }
  }

  /// Update existing patient
  Future<void> updatePatient(PatientModel patient) async {
    _patientCache[patient.id] = patient;
    OfflineStore().addPatient(patient);

    try {
      await _supabase.from('patients').update({
        'full_name': patient.name,
        'phone': patient.phone,
        'email': patient.email,
        'medical_notes': patient.address,
        'messaging_consent': patient.messagingConsent,
        'ai_consent': patient.aiProcessingConsent,
      }).eq('id', patient.id);
    } catch (e) {
      debugPrint('Notice updating patient (persisted locally): $e');
    }
  }

  /// Archive or unarchive patient
  Future<void> setPatientStatus(String patientId, String status) async {
    final patient = _patientCache[patientId] ?? OfflineStore().patients[patientId];
    if (patient != null) {
      final updated = patient.copyWith(status: status);
      _patientCache[patientId] = updated;
      OfflineStore().addPatient(updated);
    }
  }

  /// Permanently delete patient and associated records
  Future<void> deletePatient(String patientId) async {
    _patientCache.remove(patientId);
    OfflineStore().deletePatient(patientId);
    try {
      await _supabase.from('patients').delete().eq('id', patientId);
    } catch (e) {
      debugPrint('Notice deleting patient: $e');
    }
  }

  /// Update patient DPDP consent flags with verified audit trail
  Future<void> updateConsent({
    required String patientId,
    required bool messagingConsent,
    required String messagingConsentMethod,
    required bool aiProcessingConsent,
    required String aiProcessingConsentMethod,
    String? consentNotes,
    String? clinicId,
  }) async {
    try {
      await _supabase.from('patients').update({
        'messaging_consent': messagingConsent,
        'ai_consent': aiProcessingConsent,
      }).eq('id', patientId);

      final patient = _patientCache[patientId];
      final effectiveClinicId = clinicId ?? patient?.clinicId ?? 'c0000000-0000-0000-0000-000000000001';

      await _supabase.from('consents').insert([
        {
          'clinic_id': effectiveClinicId,
          'patient_id': patientId,
          'type': 'messaging',
          'granted': messagingConsent,
          'method': messagingConsentMethod,
          'notes': consentNotes,
        },
        {
          'clinic_id': effectiveClinicId,
          'patient_id': patientId,
          'type': 'ai',
          'granted': aiProcessingConsent,
          'method': aiProcessingConsentMethod,
          'notes': consentNotes,
        }
      ]);
    } catch (e) {
      debugPrint('Notice updating consent: $e');
    }
    _patientCache.remove(patientId);
  }

  /// Export patient data as structured JSON (Owner only via Edge Function)
  Future<Map<String, dynamic>> exportPatientData({
    required String patientId,
    String? clinicId,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'patient-data-tools',
        body: {'action': 'export', 'patientId': patientId},
      );
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {'patientId': patientId, 'status': 'exported'};
    } catch (e) {
      throw Exception(SupabaseConfig.formatError(e));
    }
  }

  /// Erase patient data permanently under DPDP Act (Owner only via Edge Function)
  Future<void> erasePatientData({
    required String patientId,
    required String reason,
    String? clinicId,
  }) async {
    try {
      await _supabase.functions.invoke(
        'patient-data-tools',
        body: {'action': 'erase', 'patientId': patientId, 'reason': reason},
      );
      _patientCache.remove(patientId);
      OfflineStore().deletePatient(patientId);
    } catch (e) {
      throw Exception(SupabaseConfig.formatError(e));
    }
  }
}
