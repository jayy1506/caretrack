import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/prescription_model.dart';
import 'offline_store.dart';

class PrescriptionService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Stream prescriptions for a specific patient
  Stream<List<PrescriptionModel>> streamPatientPrescriptions(String patientId) {
    return _supabase
        .from('prescriptions')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .map((data) {
      final list = data.map((map) => PrescriptionModel.fromMap(map, map['id'] ?? '')).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Upload prescription file: signed upload into private bucket if STORE_PRESCRIPTION_IMAGES=true,
  /// otherwise operates in no-storage mode.
  Future<String> uploadPrescriptionFile({
    required String doctorId,
    required String patientId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? clinicId,
  }) async {
    final effectiveClinicId = clinicId ?? 'c0000000-0000-0000-0000-000000000001';

    if (!SupabaseConfig.storePrescriptionImages) {
      // In no-storage mode, return data URL representation
      debugPrint('No-storage mode active (STORE_PRESCRIPTION_IMAGES=false). Image retained in memory only.');
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    }

    try {
      final path = '$effectiveClinicId/$doctorId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _supabase.storage.from('prescriptions').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: mimeType),
      );
      return path;
    } catch (e) {
      debugPrint('Notice on storage upload: $e. Operating in memory-only fallback.');
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    }
  }

  /// Trigger Gemini AI extraction via Supabase Edge Function extract-prescription
  Future<Map<String, dynamic>> extractFromPrescription({
    String? storagePath,
    Uint8List? fileBytes,
    String? mimeType,
    String? patientId,
  }) async {
    String? base64Data;
    if (fileBytes != null) {
      base64Data = base64Encode(fileBytes);
    }

    try {
      final res = await _supabase.functions.invoke(
        'extract-prescription',
        body: {
          if (base64Data != null) 'imageBase64': base64Data,
          if (mimeType != null) 'mimeType': mimeType,
          if (storagePath != null) 'imagePath': storagePath,
          if (patientId != null) 'patientId': patientId,
        },
      );

      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return {
        'medicines': [],
        'followUpType': '3_months',
        'followUpDate': '',
      };
    } catch (e) {
      debugPrint('AI extraction error: $e');
      throw Exception(SupabaseConfig.formatError(e));
    }
  }

  /// Save verified prescription and optionally schedule follow-up appointment
  Future<String> savePrescription({
    required String doctorId,
    required String patientId,
    required String prescriptionDate,
    required String source,
    String? originalFileUrl,
    required List<MedicineItemModel> medicines,
    required String followUpType,
    required String followUpDate,
    bool aiExtracted = false,
    bool doctorConfirmed = true,
    String? clinicId,
  }) async {
    final now = DateTime.now();
    final effectiveClinicId = clinicId ?? 'c0000000-0000-0000-0000-000000000001';
    final tempId = 'pres_${now.millisecondsSinceEpoch}';

    final prescription = PrescriptionModel(
      id: tempId,
      clinicId: effectiveClinicId,
      doctorId: doctorId,
      patientId: patientId,
      prescriptionDate: prescriptionDate,
      source: source,
      originalFileUrl: originalFileUrl,
      medicines: medicines,
      followUpType: followUpType,
      followUpDate: followUpDate,
      aiExtracted: aiExtracted,
      doctorConfirmed: doctorConfirmed,
      createdAt: now,
    );

    // Save to local store immediately (<1ms)
    OfflineStore().addPrescription(prescription);

    try {
      final insertData = {
        'clinic_id': effectiveClinicId,
        'doctor_id': doctorId,
        'patient_id': patientId,
        'medicines': medicines.map((m) => m.toMap()).toList(),
        'follow_up_date': followUpDate.isNotEmpty ? followUpDate : null,
        'verified_at': doctorConfirmed ? now.toIso8601String() : null,
      };

      final res = await _supabase.from('prescriptions').insert(insertData).select().single();
      final realId = res['id'] ?? tempId;

      final updatedPres = PrescriptionModel.fromMap(res, realId);
      OfflineStore().addPrescription(updatedPres);

      // Auto schedule follow-up appointment if requested
      if (followUpDate.isNotEmpty) {
        final startsAt = DateTime.tryParse('${followUpDate}T10:00:00Z') ?? now.add(const Duration(days: 30));
        await _supabase.from('appointments').insert({
          'clinic_id': effectiveClinicId,
          'doctor_id': doctorId,
          'patient_id': patientId,
          'starts_at': startsAt.toIso8601String(),
          'status': 'pending',
        }).catchError((_) {});
      }

      return realId;
    } catch (e) {
      debugPrint('Notice saving prescription to Supabase: $e');
      return tempId;
    }
  }

  /// Alias for backward compatibility
  Future<String> savePrescriptionAndScheduleFollowUp({
    required String doctorId,
    required String patientId,
    required String prescriptionDate,
    required String source,
    String? originalFileUrl,
    required List<MedicineItemModel> medicines,
    required String followUpType,
    required String followUpDate,
    bool aiExtracted = false,
    bool doctorConfirmed = true,
    String? clinicId,
  }) =>
      savePrescription(
        doctorId: doctorId,
        patientId: patientId,
        prescriptionDate: prescriptionDate,
        source: source,
        originalFileUrl: originalFileUrl,
        medicines: medicines,
        followUpType: followUpType,
        followUpDate: followUpDate,
        aiExtracted: aiExtracted,
        doctorConfirmed: doctorConfirmed,
        clinicId: clinicId,
      );
}
