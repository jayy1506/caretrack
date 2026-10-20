import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'offline_store.dart';

class NotificationTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream communication history for a patient
  Stream<List<NotificationModel>> streamPatientNotifications(String patientId) {
    return _firestore
        .collection('notifications')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream communication history for doctor with instant offline fallback
  Stream<List<NotificationModel>> streamDoctorNotifications(String doctorId) {
    final controller = StreamController<List<NotificationModel>>.broadcast();

    controller.add(OfflineStore().notifications);

    final subLocal = OfflineStore().notificationsStream.listen((list) {
      controller.add(list);
    });

    StreamSubscription? subRemote;
    try {
      subRemote = _firestore
          .collection('notifications')
          .where('doctorId', isEqualTo: doctorId)
          .snapshots()
          .listen((snapshot) {
        final remoteList = snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList();

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
      }, onError: (_) {
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
