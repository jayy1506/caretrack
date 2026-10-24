import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase Configuration & Client Provider
class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ewsfqbihjxjotxliuztl.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_ocjPDCkEqVR3Y7DVC2lGYQ_dyZGuTvB',
  );

  /// Flag indicating whether image files should be stored in private bucket or processed in-memory
  static const bool storePrescriptionImages = bool.fromEnvironment(
    'STORE_PRESCRIPTION_IMAGES',
    defaultValue: false,
  );

  static SupabaseClient get client => Supabase.instance.client;

  /// User friendly error formatter that sanitizes raw backend exceptions
  static String formatError(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';
    final str = error.toString().toLowerCase();

    if (str.contains('unauthorized') || str.contains('invalid login credentials') || str.contains('jwt')) {
      return 'Invalid email or password. Please verify your credentials.';
    }
    if (str.contains('network') || str.contains('socket') || str.contains('failed host lookup') || str.contains('connection')) {
      return 'Unable to reach the server. Please check your internet connection.';
    }
    if (str.contains('unique') || str.contains('conflict') || str.contains('double book') || str.contains('duplicate')) {
      return 'This appointment slot has already been booked. Please choose another time.';
    }
    if (str.contains('row level security') || str.contains('policy') || str.contains('permission denied')) {
      return 'You do not have permission to access or modify this record.';
    }
    if (str.contains('timeout')) {
      return 'Request timed out. Please try again in a moment.';
    }

    return 'Something went wrong while processing your request. Please try again.';
  }

  /// Converts UTC/timestamptz to clinic timezone (default Asia/Kolkata: UTC+05:30)
  static DateTime toClinicTime(DateTime utcTime, {String timezone = 'Asia/Kolkata'}) {
    // Standard IST offset is UTC+5h30m
    if (timezone == 'Asia/Kolkata' || timezone == 'Asia/Calcutta') {
      final utc = utcTime.isUtc ? utcTime : utcTime.toUtc();
      return utc.add(const Duration(hours: 5, minutes: 30));
    }
    return utcTime.toLocal();
  }
}
