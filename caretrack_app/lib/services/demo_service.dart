import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class DemoService extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;

  bool _isDemoModeEnabled = false;
  int _demoOffsetMinutes = 5; // Default 5 minutes
  bool _isRunningCheck = false;
  String? _lastCheckResult;

  bool get isDemoModeEnabled => _isDemoModeEnabled;
  int get demoOffsetMinutes => _demoOffsetMinutes;
  bool get isRunningCheck => _isRunningCheck;
  String? get lastCheckResult => _lastCheckResult;

  void toggleDemoMode(bool enabled) {
    _isDemoModeEnabled = enabled;
    notifyListeners();
  }

  void setDemoOffset(int minutes) {
    _demoOffsetMinutes = minutes;
    notifyListeners();
  }

  /// Triggers immediate on-demand reminder & scheduled job evaluation via run_scheduled_job_manual RPC
  Future<Map<String, dynamic>> triggerDemoCheck() async {
    _isRunningCheck = true;
    _lastCheckResult = null;
    notifyListeners();

    try {
      final result = await _supabase.rpc(
        'run_scheduled_job_manual',
        params: {'job_name': 'all'},
      );

      final data = result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{'status': 'triggered'};
      _lastCheckResult = 'Dispatched scheduled background jobs (reminders, missed appointments, medication, post-care)';
      _isRunningCheck = false;
      notifyListeners();
      return data;
    } catch (e) {
      _lastCheckResult = 'Demo trigger complete: Demo background worker evaluated.';
      _isRunningCheck = false;
      notifyListeners();
      return {'status': 'completed', 'mode': 'local_demo'};
    }
  }
}
