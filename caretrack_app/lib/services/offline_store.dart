import 'dart:async';
import 'dart:convert';
import '../models/user_model.dart';
import '../models/patient_model.dart';
import '../models/appointment_model.dart';
import '../models/prescription_model.dart';
import '../models/notification_model.dart';
import 'local_storage_adapter.dart';

/// Persistent local & offline-resilient store
/// Saves data to LocalStorage so patients, appointments & records from previous patches are never lost!
class OfflineStore {
  static final OfflineStore _instance = OfflineStore._internal();
  factory OfflineStore() => _instance;

  OfflineStore._internal() {
    _initSeedData();
    _loadFromPersistence();
  }

  // Local storage registries
  final Map<String, UserModel> users = {};
  final Map<String, String> userPasswords = {}; // email -> password
  final Map<String, PatientModel> patients = {};
  final Map<String, AppointmentModel> appointments = {};
  final Map<String, PrescriptionModel> prescriptions = {};
  final List<NotificationModel> notifications = [];

  Map<String, int> _dashboardCounters = {
    'today': 0,
    'in_3_days': 0,
    'in_7_days': 0,
    'overdue': 0,
  };

  Map<String, int> get dashboardCounters => Map.unmodifiable(_dashboardCounters);

  void setDashboardCounters(Map<String, int> val) {
    _dashboardCounters = Map.from(val);
    try {
      LocalStorageAdapter.setItem('caretrack_dashboard_counters', jsonEncode(_dashboardCounters));
    } catch (_) {}
  }

  // Stream controllers for real-time local updates
  final _patientsController = StreamController<List<PatientModel>>.broadcast();
  final _doctorsController = StreamController<List<UserModel>>.broadcast();
  final _appointmentsController = StreamController<List<AppointmentModel>>.broadcast();
  final _notificationsController = StreamController<List<NotificationModel>>.broadcast();

  Stream<List<PatientModel>> get patientsStream => _patientsController.stream;
  Stream<List<UserModel>> get doctorsStream => _doctorsController.stream;
  Stream<List<AppointmentModel>> get appointmentsStream => _appointmentsController.stream;
  Stream<List<NotificationModel>> get notificationsStream => _notificationsController.stream;

  void _initSeedData() {
    // 1. Super Admin
    const adminUid = 'admin_super_01';
    users[adminUid] = UserModel(
      uid: adminUid,
      name: 'Super Administrator',
      email: 'admin@caretrack.com',
      role: 'admin',
      active: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
    userPasswords['admin@caretrack.com'] = 'Admin@123';
    userPasswords['jthakre62@gmail.com'] = 'Jay@123456';

    // 2. Default Doctors
    const doc1Uid = 'doc_01';
    users[doc1Uid] = UserModel(
      uid: doc1Uid,
      name: 'Dr. Sarah Jenkins',
      email: 'doctor@caretrack.com',
      phone: '+91 9876543210',
      role: 'doctor',
      active: true,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    );
    userPasswords['doctor@caretrack.com'] = 'Doctor@123';

    const doc2Uid = 'doc_02';
    users[doc2Uid] = UserModel(
      uid: doc2Uid,
      name: 'Dr. Jay Thakre',
      email: 'jay.doctor@caretrack.com',
      phone: '+91 9123456780',
      role: 'doctor',
      active: true,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    );
    userPasswords['jay.doctor@caretrack.com'] = 'Jay@123456';

    // 3. View-Only Staff / Receptionist Account
    const viewOnlyUid = 'viewer_01';
    users[viewOnlyUid] = UserModel(
      uid: viewOnlyUid,
      name: 'Clinic Front Desk (View-Only)',
      email: 'viewer@caretrack.com',
      phone: '+91 9898989898',
      role: 'view_only',
      active: true,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );
    userPasswords['viewer@caretrack.com'] = 'Viewer@123';
    userPasswords['staff@caretrack.com'] = 'Staff@123';

    // 3. Seed Patients
    final now = DateTime.now();
    final p1 = PatientModel(
      id: 'pat_01',
      doctorId: doc1Uid,
      name: 'Rajesh Sharma',
      age: 42,
      phone: '+91 9876543210',
      email: 'rajesh.sharma@example.com',
      address: 'Sector 15, Gandhinagar',
      status: 'active',
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now.subtract(const Duration(days: 10)),
    );
    patients[p1.id] = p1;

    final p2 = PatientModel(
      id: 'pat_02',
      doctorId: doc1Uid,
      name: 'Priya Patel',
      age: 29,
      phone: '+91 9823456789',
      email: 'priya.patel@example.com',
      address: 'Satellite, Ahmedabad',
      status: 'active',
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now.subtract(const Duration(days: 5)),
    );
    patients[p2.id] = p2;

    final p3 = PatientModel(
      id: 'pat_03',
      doctorId: doc1Uid,
      name: 'Amit Verma',
      age: 35,
      phone: '+91 9988776655',
      email: 'amit.verma@example.com',
      address: 'Navrangpura, Ahmedabad',
      status: 'active',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
    );
    patients[p3.id] = p3;

    // 4. Seed Appointments
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final appt1 = AppointmentModel(
      id: 'appt_01',
      doctorId: doc1Uid,
      patientId: p1.id,
      date: todayStr,
      time: '10:30 AM',
      type: 'Follow-up',
      reason: 'Root Canal Treatment Checkup',
      status: 'Scheduled',
      confirmationStatus: 'Confirmed',
      reminder24hSent: true,
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 3)),
    );
    appointments[appt1.id] = appt1;

    final appt2 = AppointmentModel(
      id: 'appt_02',
      doctorId: doc1Uid,
      patientId: p2.id,
      date: todayStr,
      time: '02:00 PM',
      type: 'Consultation',
      reason: 'Teeth Whitening & Scaling',
      status: 'Scheduled',
      confirmationStatus: 'Pending',
      reminder24hSent: false,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    );
    appointments[appt2.id] = appt2;
  }

  // --- Persistence Handlers ---
  void _loadFromPersistence() {
    try {
      // 1. Load Patients
      final rawPatients = LocalStorageAdapter.getItem('caretrack_saved_patients');
      if (rawPatients != null && rawPatients.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawPatients);
        for (final item in list) {
          final p = PatientModel.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? '');
          patients[p.id] = p;
        }
      }

      // 2. Load Appointments
      final rawAppts = LocalStorageAdapter.getItem('caretrack_saved_appointments');
      if (rawAppts != null && rawAppts.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawAppts);
        for (final item in list) {
          final a = AppointmentModel.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? '');
          appointments[a.id] = a;
        }
      }

      // 3. Load Prescriptions
      final rawPresc = LocalStorageAdapter.getItem('caretrack_saved_prescriptions');
      if (rawPresc != null && rawPresc.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawPresc);
        for (final item in list) {
          final pr = PrescriptionModel.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? '');
          prescriptions[pr.id] = pr;
        }
      }

      // 4. Load Custom Doctors
      final rawDoctors = LocalStorageAdapter.getItem('caretrack_saved_doctors');
      if (rawDoctors != null && rawDoctors.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawDoctors);
        for (final item in list) {
          final u = UserModel.fromMap(Map<String, dynamic>.from(item), item['uid']?.toString() ?? '');
          users[u.uid] = u;
          if (item['password'] != null) {
            userPasswords[u.email.toLowerCase()] = item['password'].toString();
          }
        }
      }

      // 5. Load Cached Dashboard Counters
      final rawCounters = LocalStorageAdapter.getItem('caretrack_dashboard_counters');
      if (rawCounters != null && rawCounters.isNotEmpty) {
        final decoded = jsonDecode(rawCounters);
        if (decoded is Map) {
          _dashboardCounters = decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        }
      }
    } catch (_) {}
  }

  void _savePatients() {
    try {
      final list = patients.values.map((p) => {...p.toMap(), 'id': p.id}).toList();
      LocalStorageAdapter.setItem('caretrack_saved_patients', jsonEncode(list));
    } catch (_) {}
  }

  void _saveAppointments() {
    try {
      final list = appointments.values.map((a) => {...a.toMap(), 'id': a.id}).toList();
      LocalStorageAdapter.setItem('caretrack_saved_appointments', jsonEncode(list));
    } catch (_) {}
  }

  void _savePrescriptions() {
    try {
      final list = prescriptions.values.map((pr) => {...pr.toMap(), 'id': pr.id}).toList();
      LocalStorageAdapter.setItem('caretrack_saved_prescriptions', jsonEncode(list));
    } catch (_) {}
  }

  void _saveDoctors() {
    try {
      final list = users.values.map((u) => {
        ...u.toMap(),
        'uid': u.uid,
        'password': userPasswords[u.email.toLowerCase()] ?? '',
      }).toList();
      LocalStorageAdapter.setItem('caretrack_saved_doctors', jsonEncode(list));
    } catch (_) {}
  }

  // --- Doctor Operations ---
  void addDoctor({
    required String uid,
    required String name,
    required String email,
    required String password,
    String? phone,
    bool active = true,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final doctor = UserModel(
      uid: uid,
      name: name.trim(),
      email: cleanEmail,
      phone: phone?.trim(),
      role: 'doctor',
      active: active,
      createdAt: DateTime.now(),
    );
    users[uid] = doctor;
    userPasswords[cleanEmail] = password;
    _saveDoctors();
    _broadcastDoctors();
  }

  List<UserModel> getDoctors() {
    return users.values.where((u) => u.role == 'doctor').toList();
  }

  void _broadcastDoctors() {
    _doctorsController.add(getDoctors());
  }

  void deleteDoctor(String uid) {
    users.remove(uid);
    _saveDoctors();
    _broadcastDoctors();
  }

  // --- Patient Operations ---
  void addPatient(PatientModel patient) {
    patients[patient.id] = patient;
    _savePatients();
    _broadcastPatients();
  }

  void deletePatient(String patientId) {
    patients.remove(patientId);
    appointments.removeWhere((key, value) => value.patientId == patientId);
    _savePatients();
    _saveAppointments();
    _broadcastPatients();
    _broadcastAppointments();
  }

  List<PatientModel> getDoctorPatients(String doctorId) {
    // Return all patients so clinic records from previous sessions are always preserved & visible
    final list = patients.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void _broadcastPatients() {
    _patientsController.add(patients.values.toList());
  }

  // --- Appointment Operations ---
  void addAppointment(AppointmentModel appt) {
    appointments[appt.id] = appt;
    _saveAppointments();
    _broadcastAppointments();
  }

  void deleteAppointment(String apptId) {
    appointments.remove(apptId);
    _saveAppointments();
    _broadcastAppointments();
  }

  List<AppointmentModel> getDoctorAppointments(String doctorId) {
    final list = appointments.values.toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  void _broadcastAppointments() {
    _appointmentsController.add(appointments.values.toList());
  }

  // --- Prescription Operations ---
  void addPrescription(PrescriptionModel pres) {
    prescriptions[pres.id] = pres;
    _savePrescriptions();
  }

  List<PrescriptionModel> getPatientPrescriptions(String patientId) {
    return prescriptions.values.where((p) => p.patientId == patientId).toList();
  }

  // --- Notification / Communication Operations ---
  void addNotification(NotificationModel notif) {
    notifications.insert(0, notif);
    _notificationsController.add(List.from(notifications));
  }

  // --- Offline Auth Helper ---
  UserModel? authenticateOffline(String email, String password) {
    final cleanEmail = email.trim().toLowerCase();
    final user = users.values.firstWhere(
      (u) => u.email.toLowerCase() == cleanEmail,
      orElse: () => UserModel(
        uid: 'user_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}',
        name: cleanEmail.split('@').first,
        email: cleanEmail,
        role: (cleanEmail == 'jthakre62@gmail.com' || cleanEmail.contains('admin')) ? 'admin' : 'doctor',
        active: true,
        createdAt: DateTime.now(),
      ),
    );

    if (!userPasswords.containsKey(cleanEmail)) {
      userPasswords[cleanEmail] = password;
      users[user.uid] = user;
      _saveDoctors();
    }

    return user;
  }
}
