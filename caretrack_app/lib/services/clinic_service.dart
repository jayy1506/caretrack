import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/clinic_model.dart';

class ClinicService extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;

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
      final data = await _supabase
          .from('clinics')
          .select('id, name, slug, timezone, settings')
          .eq('id', clinicId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (data != null) {
        _currentClinic = ClinicModel.fromMap(data, clinicId);
      } else {
        _currentClinic = ClinicModel(
          id: clinicId,
          name: 'CareTrack Dental Clinic (Demo)',
          address: '101 Healthcare Blvd, Bandra West, Mumbai',
          phone: '+91 9876543210',
          timezone: 'Asia/Kolkata',
          featureFlags: const ClinicFeatureFlags(),
        );
      }
    } catch (e) {
      debugPrint('Notice loading clinic ($clinicId): $e');
      _currentClinic = ClinicModel(
        id: clinicId,
        name: 'CareTrack Dental Clinic (Demo)',
        address: '101 Healthcare Blvd, Bandra West, Mumbai',
        phone: '+91 9876543210',
        timezone: 'Asia/Kolkata',
        featureFlags: const ClinicFeatureFlags(),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateFeatureFlags(ClinicFeatureFlags flags) async {
    if (_currentClinic == null) return;
    try {
      final currentSettings = _currentClinic!.toMap()['settings'] ?? {};
      currentSettings['feature_flags'] = flags.toMap();

      await _supabase
          .from('clinics')
          .update({'settings': currentSettings})
          .eq('id', _currentClinic!.id);

      _currentClinic = ClinicModel(
        id: _currentClinic!.id,
        name: _currentClinic!.name,
        address: _currentClinic!.address,
        phone: _currentClinic!.phone,
        timezone: _currentClinic!.timezone,
        workingHours: _currentClinic!.workingHours,
        holidays: _currentClinic!.holidays,
        logoUrl: _currentClinic!.logoUrl,
        featureFlags: flags,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating feature flags: $e');
    }
  }
}
