import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/user_model.dart';
import '../models/patient_model.dart';
import '../models/appointment_model.dart';
import 'offline_store.dart';

class AdminService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Stream list of all registered doctors with instant offline fallback
  Stream<List<UserModel>> streamDoctors() {
    final controller = StreamController<List<UserModel>>.broadcast();

    // 1. Emit local/ayurveda stored doctors immediately (<1ms)
    controller.add(OfflineStore().getDoctors());

    // 2. Listen to real-time local additions
    final subLocal = OfflineStore().doctorsStream.listen((docs) {
      controller.add(docs);
    });

    // 3. Listen to Supabase stream in background if online
    StreamSubscription? subRemote;
    try {
      subRemote = _supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .listen((data) {
        final remoteList = data.map((map) {
          final u = UserModel.fromMap(map, map['id'] ?? '');
          return u;
        }).where((u) => u.role == 'doctor').toList();

        final merged = <String, UserModel>{};
        for (final d in OfflineStore().getDoctors()) {
          merged[d.uid] = d;
        }
        for (final d in remoteList) {
          merged[d.uid] = d;
        }

        controller.add(merged.values.toList());
      }, onError: (err) {
        debugPrint('Notice on doctors stream: $err');
        controller.add(OfflineStore().getDoctors());
      });
    } catch (_) {}

    controller.onCancel = () {
      subLocal.cancel();
      subRemote?.cancel();
    };

    return controller.stream;
  }

  /// Stream all users (doctors, receptionists and clinic owners)
  Stream<List<UserModel>> streamAllStaff() {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .map((data) {
      final list = data.map((map) => UserModel.fromMap(map, map['id'] ?? '')).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// Stream all patients registered under a specific doctor
  Stream<List<PatientModel>> streamDoctorPatients(String doctorId) {
    return _supabase
        .from('patients')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', doctorId)
        .map((data) {
      final list = data.map((map) => PatientModel.fromMap(map, map['id'] ?? '')).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream all appointments under a specific doctor
  Stream<List<AppointmentModel>> streamDoctorAppointments(String doctorId) {
    return _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', doctorId)
        .map((data) {
      final list = data.map((map) => AppointmentModel.fromMap(map, map['id'] ?? '')).toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }

  /// Owner creates a new doctor/staff member via create-staff Edge Function
  Future<Map<String, dynamic>> createDoctor({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? specialty,
    String? clinicId,
    bool active = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final tempUid = 'doc_${DateTime.now().millisecondsSinceEpoch}';

    // Save to OfflineStore immediately (<1ms)
    OfflineStore().addDoctor(
      uid: tempUid,
      name: cleanName,
      email: cleanEmail,
      password: password,
      phone: phone,
      active: active,
    );

    try {
      final res = await _supabase.functions.invoke(
        'create-staff',
        body: {
          'action': 'create',
          'email': cleanEmail,
          'fullName': cleanName,
          'role': 'doctor',
          'clinicId': clinicId,
        },
      );

      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (e) {
      debugPrint('Notice calling create-staff Edge Function: $e');
    }

    return {
      'uid': tempUid,
      'email': cleanEmail,
      'name': cleanName,
      'role': 'doctor',
    };
  }

  /// Owner toggles staff active/disabled status via create-staff Edge Function
  Future<void> toggleDoctorStatus({
    required String doctorId,
    required bool active,
  }) async {
    try {
      await _supabase.functions.invoke(
        'create-staff',
        body: {
          'action': 'toggle-status',
          'staffId': doctorId,
          'active': active,
        },
      );
    } catch (e) {
      debugPrint('Notice toggling staff status: $e');
    }
  }

  /// Owner updates staff role via create-staff Edge Function
  Future<void> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    try {
      await _supabase.functions.invoke(
        'create-staff',
        body: {
          'action': 'update-role',
          'staffId': userId,
          'role': newRole,
        },
      );
    } catch (e) {
      debugPrint('Notice updating staff role: $e');
    }
  }
}
