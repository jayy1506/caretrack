import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/patient_model.dart';
import '../models/appointment_model.dart';
import 'offline_store.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _apiKey = 'AIzaSyAxU6oxTYZyg-1tugDzEmvxwY7MOkYSEeg';

  /// Stream list of all registered doctors with instant offline fallback
  Stream<List<UserModel>> streamDoctors() {
    final controller = StreamController<List<UserModel>>.broadcast();

    // 1. Emit local/ayurveda stored doctors immediately (<1ms)
    controller.add(OfflineStore().getDoctors());

    // 2. Listen to real-time local additions
    final subLocal = OfflineStore().doctorsStream.listen((docs) {
      controller.add(docs);
    });

    // 3. Listen to Firestore stream in background if online
    StreamSubscription? subRemote;
    try {
      subRemote = _firestore
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .snapshots()
          .listen((snapshot) {
        final remoteList = snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList();

        final merged = <String, UserModel>{};
        for (final d in OfflineStore().getDoctors()) {
          merged[d.uid] = d;
        }
        for (final d in remoteList) {
          merged[d.uid] = d;
        }

        controller.add(merged.values.toList());
      }, onError: (_) {
        controller.add(OfflineStore().getDoctors());
      });
    } catch (_) {}

    controller.onCancel = () {
      subLocal.cancel();
      subRemote?.cancel();
    };

    return controller.stream;
  }

  /// Stream all users (doctors and administrators)
  Stream<List<UserModel>> streamAllStaff() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// Stream all patients registered under a specific doctor
  Stream<List<PatientModel>> streamDoctorPatients(String doctorId) {
    return _firestore
        .collection('patients')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PatientModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream all appointments under a specific doctor
  Stream<List<AppointmentModel>> streamDoctorAppointments(String doctorId) {
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }

  /// Admin creates a new doctor with instant execution
  Future<Map<String, dynamic>> createDoctor({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? specialty,
    bool active = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final uid = 'doc_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Save directly to OfflineStore immediately (<1ms)
    OfflineStore().addDoctor(
      uid: uid,
      name: cleanName,
      email: cleanEmail,
      password: password,
      phone: phone,
      active: active,
    );

    // 2. Sync to Firebase Auth & Firestore in background
    fetchAccountCreation(cleanEmail, password, cleanName).then((res) {
      final actualUid = res['localId'] ?? uid;
      final doctorData = {
        'uid': actualUid,
        'name': cleanName,
        'email': cleanEmail,
        'phone': phone?.trim(),
        'specialty': specialty?.trim() ?? 'General Dentistry & Follow-up',
        'role': 'doctor',
        'active': active,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      _firestore.collection('users').doc(actualUid).set(doctorData, SetOptions(merge: true)).catchError((_) {});
    }).catchError((_) {});

    return {
      'uid': uid,
      'email': cleanEmail,
      'name': cleanName,
      'role': 'doctor',
    };
  }

  /// Helper for direct account creation
  static Future<Map<String, dynamic>> fetchAccountCreation(String email, String password, String displayName) async {
    try {
      final signUpUrl = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey');
      final signUpResponse = await http.post(
        signUpUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );

      final res = jsonDecode(signUpResponse.body) as Map<String, dynamic>;

      if (res['error'] != null) {
        return res;
      }

      if (res['idToken'] != null) {
        final updateUrl = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:update?key=$_apiKey');
        await http.post(
          updateUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idToken': res['idToken'],
            'displayName': displayName,
            'returnSecureToken': true,
          }),
        );
      }

      return res;
    } catch (e) {
      throw Exception('Network error during account creation: $e');
    }
  }

  /// Admin toggles doctor active/disabled status
  Future<void> toggleDoctorStatus({
    required String doctorId,
    required bool active,
  }) async {
    await _firestore.collection('users').doc(doctorId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin grants or revokes Admin access to any user
  Future<void> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'role': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
