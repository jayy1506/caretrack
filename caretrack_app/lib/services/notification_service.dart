import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/notification_model.dart';
import 'offline_store.dart';

class NotificationTrackingService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Stream communication history for a patient
  Stream<List<NotificationModel>> streamPatientNotifications(String patientId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .map((data) {
      final list = data.map((map) => NotificationModel.fromMap(map, map['id'] ?? '')).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream communication history for doctor with instant offline fallback
  Stream<List<NotificationModel>> streamDoctorNotifications(String doctorId) {
    final controller = StreamController<List<NotificationModel>>.broadcast();

    // 1. Emit local/ayurveda stored notifications immediately (<1ms)
    controller.add(OfflineStore().notifications);

    // 2. Listen to real-time local additions
    final subLocal = OfflineStore().notificationsStream.listen((list) {
      controller.add(list);
    });

    // 3. Listen to Supabase notifications stream
    StreamSubscription? subRemote;
    try {
      subRemote = _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .listen((data) {
        final remoteList = data.map((map) {
          final n = NotificationModel.fromMap(map, map['id'] ?? '');
          return n;
        }).toList();

        final merged = <String, NotificationModel>{};
        for (final n in OfflineStore().notifications) {
          merged[n.id] = n;
        }
        for (final n in remoteList) {
          merged[n.id] = n;
        }

        final result = merged.values.toList();
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        controller.add(result);
      }, onError: (err) {
        debugPrint('Notice on notifications stream: $err');
        controller.add(OfflineStore().notifications);
      });
    } catch (_) {}

    controller.onCancel = () {
      subLocal.cancel();
      subRemote?.cancel();
    };

    return controller.stream;
  }
}
