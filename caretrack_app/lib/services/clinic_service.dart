import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clinic_model.dart';

class ClinicService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ClinicModel? _currentClinic;
  bool _isLoading = true;

  ClinicModel? get currentClinic => _currentClinic;
  ClinicFeatureFlags get featureFlags => _currentClinic?.featureFlags ?? const ClinicFeatureFlags();
  bool get isLoading => _isLoading;

  bool isFeatureEnabled(String featureName) {
    final flags = featureFlags;
    switch (featureName) {
      case 'treatmentPlans':
        return flags.treatmentPlans;
      case 'onlineBooking':
        return flags.onlineBooking;
      case 'twoWayWhatsApp':
        return flags.twoWayWhatsApp;
      case 'recall':
        return flags.recall;
      case 'medicationReminders':
        return flags.medicationReminders;
      case 'noShowAI':
        return flags.noShowAI;
      case 'faqAssistant':
        return flags.faqAssistant;
      default:
        return true;
    }
  }

  Future<void> loadClinic(String clinicId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore.collection('clinics').doc(clinicId).get();
      if (doc.exists && doc.data() != null) {
        _currentClinic = ClinicModel.fromMap(doc.data()!, doc.id);
      } else {
        // Fallback default clinic configuration
        _currentClinic = ClinicModel(
          id: clinicId,
          name: 'CareTrack Dental Clinic',
          address: '101 Healthcare Blvd, Bandra West, Mumbai',
          phone: '+919876543210',
          timezone: 'Asia/Kolkata',
          featureFlags: const ClinicFeatureFlags(),
        );
      }
    } catch (e) {
      debugPrint('Notice loading clinic ($clinicId): $e');
      _currentClinic = ClinicModel(
        id: clinicId,
        name: 'CareTrack Dental Clinic',
        address: '',
        phone: '',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
