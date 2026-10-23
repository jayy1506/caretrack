import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/appointment_model.dart';
import 'offline_store.dart';

class AppointmentService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Fetch live or cached dashboard counters using the SQL RPC dashboard_counters()
  Future<Map<String, int>> getDashboardCounters() async {
    try {
      final res = await _supabase.rpc('dashboard_counters');
      if (res != null && res is Map) {
        final counters = {
          'today': (res['today'] as num?)?.toInt() ?? 0,
          'in_3_days': (res['in_3_days'] as num?)?.toInt() ?? 0,
          'in_7_days': (res['in_7_days'] as num?)?.toInt() ?? 0,
          'overdue': (res['overdue'] as num?)?.toInt() ?? 0,
        };
        OfflineStore().setDashboardCounters(counters);
        return counters;
      }
    } catch (e) {
      debugPrint('Notice loading dashboard counters from RPC (using offline cache): $e');
    }
    return OfflineStore().dashboardCounters;
  }

  /// Helper to convert date string (YYYY-MM-DD) and time string (e.g. "10:00 AM") to UTC DateTime
  DateTime _combineDateAndTime(String dateStr, String timeStr) {
    try {
      final dateParts = dateStr.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      final cleanTime = timeStr.trim();
      final isPM = cleanTime.toUpperCase().contains('PM');
      final isAM = cleanTime.toUpperCase().contains('AM');
      final rawTime = cleanTime.replaceAll(RegExp(r'[AaPp][Mm]'), '').trim();
      final timeParts = rawTime.split(':');
      var hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      // Assume clinic time zone Asia/Kolkata (UTC +05:30)
      final local = DateTime(year, month, day, hour, minute);
      return local.subtract(const Duration(hours: 5, minutes: 30)).toUtc();
    } catch (_) {
      return DateTime.now().add(const Duration(days: 1)).toUtc();
    }
  }

  /// Stream all appointments for a doctor with instant offline fallback
  Stream<List<AppointmentModel>> streamDoctorAppointments(String doctorId) {
    final controller = StreamController<List<AppointmentModel>>.broadcast();

    // 1. Emit local/ayurveda stored appointments immediately (<1ms)
    controller.add(OfflineStore().getDoctorAppointments(doctorId));

    // 2. Listen to real-time local additions
    final subLocal = OfflineStore().appointmentsStream.listen((_) {
      controller.add(OfflineStore().getDoctorAppointments(doctorId));
    });

    // 3. Listen to Supabase stream in background if online
    StreamSubscription? subRemote;
    try {
      subRemote = _supabase
          .from('appointments')
          .stream(primaryKey: ['id'])
          .listen((data) {
        final remoteList = data.map((map) {
          final a = AppointmentModel.fromMap(map, map['id'] ?? '');
          OfflineStore().appointments[a.id] = a;
          return a;
        }).toList();

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
      }, onError: (err) {
        debugPrint('Notice on appointments stream (using offline store): $err');
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
    return _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .map((data) {
      final list = data.map((map) => AppointmentModel.fromMap(map, map['id'] ?? '')).toList();
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
    final now = DateTime.now();
    final effectiveClinicId = clinicId ?? 'c0000000-0000-0000-0000-000000000001';
    final startsAt = _combineDateAndTime(date, time);

    final tempId = 'appt_${now.millisecondsSinceEpoch}';
    final appt = AppointmentModel(
      id: tempId,
      clinicId: effectiveClinicId,
      doctorId: doctorId,
      patientId: patientId,
      date: date,
      time: time,
      startsAt: startsAt,
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

    try {
      final insertData = {
        'clinic_id': effectiveClinicId,
        'doctor_id': doctorId,
        'patient_id': patientId,
        'starts_at': startsAt.toIso8601String(),
        'status': 'pending',
      };

      final res = await _supabase.from('appointments').insert(insertData).select().single();
      final realId = res['id'] ?? tempId;

      final updatedAppt = AppointmentModel.fromMap(res, realId);
      OfflineStore().addAppointment(updatedAppt);
      return realId;
    } catch (e) {
      debugPrint('Notice creating appointment in Supabase: $e');
      return tempId;
    }
  }

  /// Update appointment status (Completed, Missed, Rescheduled, Cancelled)
  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? confirmationStatus,
  }) async {
    final sqlStatus = status.toLowerCase().replaceAll(' ', '_');
    try {
      await _supabase.from('appointments').update({
        'status': sqlStatus,
      }).eq('id', appointmentId);
    } catch (e) {
      debugPrint('Notice updating appointment status: $e');
    }
  }

  /// Reschedule an appointment to a new date/time
  Future<void> rescheduleAppointment({
    required String appointmentId,
    required String newDate,
    required String newTime,
    String? reason,
  }) async {
    final newStartsAt = _combineDateAndTime(newDate, newTime);
    try {
      await _supabase.from('appointments').update({
        'starts_at': newStartsAt.toIso8601String(),
        'status': 'pending',
        'reminder_sent_at': null,
        'reminder_claimed_at': null,
        'reminder_attempts': 0,
      }).eq('id', appointmentId);
    } catch (e) {
      debugPrint('Notice rescheduling appointment: $e');
    }
  }

  /// Cancel an appointment
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await _supabase.from('appointments').update({
        'status': 'cancelled',
      }).eq('id', appointmentId);
    } catch (e) {
      debugPrint('Notice cancelling appointment: $e');
    }
  }

  /// Permanently delete an appointment
  Future<void> deleteAppointment(String appointmentId) async {
    OfflineStore().deleteAppointment(appointmentId);
    try {
      await _supabase.from('appointments').delete().eq('id', appointmentId);
    } catch (e) {
      debugPrint('Notice deleting appointment: $e');
    }
  }
}
