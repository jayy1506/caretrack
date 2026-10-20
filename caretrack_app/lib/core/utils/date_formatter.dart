import 'package:intl/intl.dart';

class DateUtilsHelper {
  static final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _shortDateFormat = DateFormat('dd MMM');
  static final DateFormat _storageDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static String formatDisplayDate(DateTime date) => _displayDateFormat.format(date);
  static String formatShortDate(DateTime date) => _shortDateFormat.format(date);
  static String formatStorageDate(DateTime date) => _storageDateFormat.format(date);
  static String formatTime(DateTime time) => _timeFormat.format(time);
  static String formatDateTime(DateTime dateTime) => _dateTimeFormat.format(dateTime);

  static DateTime parseStorageDate(String dateStr) {
    try {
      return _storageDateFormat.parse(dateStr.trim());
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Deterministically calculates follow-up date
  static DateTime calculateFollowUp(DateTime baseDate, String followUpType, {DateTime? customDate}) {
    if (followUpType == 'custom' && customDate != null) {
      return customDate;
    }

    switch (followUpType) {
      case '15_days':
        return baseDate.add(const Duration(days: 15));
      case '1_month':
        return DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
      case '3_months':
        return DateTime(baseDate.year, baseDate.month + 3, baseDate.day);
      case '6_months':
        return DateTime(baseDate.year, baseDate.month + 6, baseDate.day);
      default:
        return DateTime(baseDate.year, baseDate.month + 3, baseDate.day);
    }
  }

  /// Calculates day difference between target date and today
  static int getDaysFromToday(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }
}
