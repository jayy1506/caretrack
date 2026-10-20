import 'package:cloud_functions/cloud_functions.dart';
import '../models/slot_model.dart';
import '../models/appointment_model.dart';
import 'offline_store.dart';

class BookingService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Fetch available slots for a doctor and date range
  Future<List<DaySlotsModel>> fetchAvailableSlots({
    required String doctorId,
    required String startDate,
    String? endDate,
    String? clinicId,
  }) async {
    try {
      final callable = _functions.httpsCallable('getAvailableSlots');
      final res = await callable.call({
        'doctorId': doctorId,
        'startDate': startDate,
        'endDate': endDate ?? startDate,
        if (clinicId != null) 'clinicId': clinicId,
      });

      final data = Map<String, dynamic>.from(res.data as Map);
      final daysRaw = (data['days'] as List<dynamic>?) ?? [];

      return daysRaw.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return DaySlotsModel.fromMap(map);
      }).toList();
    } catch (e) {
      // Offline fallback: generate slots using offline appointments
      return _generateOfflineSlots(doctorId: doctorId, date: startDate);
    }
  }

  /// Receptionist books an appointment directly in clinic
  Future<Map<String, dynamic>> bookAppointmentReception({
    required String clinicId,
    required String doctorId,
    String? patientId,
    String? patientName,
    String? patientPhone,
    required String date,
    required String time,
    String? reason,
    String type = 'Consultation',
  }) async {
    // 1. Save to OfflineStore immediately for zero-lag UI feedback
    final tempApptId = 'appt_${DateTime.now().millisecondsSinceEpoch}';
    final offlineAppt = AppointmentModel(
      id: tempApptId,
      clinicId: clinicId,
      doctorId: doctorId,
      patientId: patientId ?? '',
      date: date,
      time: time,
      type: type,
      reason: reason,
      status: 'Confirmed',
      confirmationStatus: 'Confirmed',
    );
    OfflineStore().addAppointment(offlineAppt);

    // 2. Call Cloud Function backend with concurrency protection
    try {
      final callable = _functions.httpsCallable('bookAppointmentReception');
      final res = await callable.call({
        'clinicId': clinicId,
        'doctorId': doctorId,
        if (patientId != null) 'patientId': patientId,
        if (patientName != null) 'patientName': patientName,
        if (patientPhone != null) 'patientPhone': patientPhone,
        'date': date,
        'time': time,
        'reason': reason,
        'type': type,
      });
      return Map<String, dynamic>.from(res.data as Map);
    } catch (err) {
      // If error (e.g. offline), the appointment remains queued in OfflineStore
      return {
        'success': true,
        'offline': true,
        'appointmentId': tempApptId,
        'message': 'Appointment queued offline.',
      };
    }
  }

  /// Fallback slot generator when network is unavailable
  List<DaySlotsModel> _generateOfflineSlots({
    required String doctorId,
    required String date,
  }) {
    final bookedAppointments = OfflineStore().appointments.values.where((a) {
      return a.doctorId == doctorId && a.date == date && a.status != 'Cancelled';
    }).toList();

    final bookedTimes = bookedAppointments.map((a) => a.time).toSet();

    final defaultSlotTimes = [
      '09:00 AM',
      '09:30 AM',
      '10:00 AM',
      '10:30 AM',
      '11:00 AM',
      '11:30 AM',
      '02:00 PM',
      '02:30 PM',
      '03:00 PM',
      '03:30 PM',
      '04:00 PM',
      '04:30 PM',
      '05:00 PM',
    ];

    final slots = defaultSlotTimes.map((t) {
      final isBooked = bookedTimes.contains(t);
      return SlotModel(
        time: t,
        startMinutes: 0,
        available: !isBooked,
        reasonUnavailable: isBooked ? 'booked' : null,
      );
    }).toList();

    return [
      DaySlotsModel(
        date: date,
        dayName: 'Today',
        isOpen: true,
        slots: slots,
      ),
    ];
  }
}
