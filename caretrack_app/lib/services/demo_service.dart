import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class DemoService extends ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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

  /// Triggers immediate on-demand reminder evaluation with demo offset
  Future<Map<String, dynamic>> triggerDemoCheck() async {
    _isRunningCheck = true;
    _lastCheckResult = null;
    notifyListeners();

    try {
      final callable = _functions.httpsCallable('triggerDemoReminderCheck');
      final result = await callable.call<Map<String, dynamic>>({
        'offsetMinutes': _demoOffsetMinutes,
      });

      final data = Map<String, dynamic>.from(result.data);
      _lastCheckResult = 'Processed: ${data['processed']}, Reminders Sent: ${data['sent']}, Errors: ${data['errors']}';
      _isRunningCheck = false;
      notifyListeners();
      return data;
    } catch (e) {
      _lastCheckResult = 'Failed: $e';
      _isRunningCheck = false;
      notifyListeners();
      rethrow;
    }
  }
}
