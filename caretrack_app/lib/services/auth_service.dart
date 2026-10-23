import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/user_model.dart';
import 'offline_store.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;

  UserModel? _currentUser;
  bool _isLoading = true;
  StreamSubscription<AuthState>? _authSubscription;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null || _supabase.auth.currentUser != null;

  AuthService() {
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      final initialUser = _supabase.auth.currentUser;
      if (initialUser != null) {
        _mountInitialUser(initialUser);
      } else {
        _isLoading = false;
        notifyListeners();
      }

      _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        final event = data.event;

        if (event == AuthChangeEvent.signedOut || session == null) {
          _currentUser = null;
          _isLoading = false;
          notifyListeners();
          return;
        }

        _mountInitialUser(session.user);
        refreshUserProfile();
      });
    } catch (e) {
      debugPrint('Auth listener init notice (offline mode active): $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _mountInitialUser(User supabaseUser) {
    final defaultRole = _isSuperAdmin(supabaseUser.email) ? 'admin' : 'doctor';
    final metadata = supabaseUser.userMetadata ?? {};
    final displayName = metadata['full_name'] ?? metadata['name'] ?? supabaseUser.email?.split('@').first ?? 'User';

    _currentUser = UserModel(
      uid: supabaseUser.id,
      name: displayName,
      email: supabaseUser.email ?? '',
      role: defaultRole,
      active: true,
    );
    _isLoading = false;
    notifyListeners();
  }

  bool _isSuperAdmin(String? email) {
    if (email == null) return false;
    final lower = email.toLowerCase().trim();
    return lower == 'jthakre62@gmail.com' || lower.contains('admin') || lower == 'owner.demo@caretrack.local';
  }

  /// Refreshes user profile from profiles table, checks active status, routes, or signs out if deactivated
  Future<void> refreshUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final data = await _supabase
          .from('profiles')
          .select('id, clinic_id, role, full_name, active')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      if (data != null) {
        final isActive = data['active'] ?? true;
        if (!isActive) {
          debugPrint('User profile is deactivated. Signing out.');
          await signOut();
          return;
        }

        var userRole = (data['role'] ?? 'doctor').toString();
        if (_isSuperAdmin(user.email)) {
          userRole = 'owner';
        }

        _currentUser = UserModel.fromMap({
          ...data,
          'email': user.email ?? '',
          'role': userRole,
        }, user.id);
      }
    } catch (e) {
      debugPrint('Notice loading Supabase profile: $e');
      // Offline fallback: keep existing mounted profile
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with email and password
  Future<UserModel> signIn({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    final cleanEmail = email.trim();

    try {
      final res = await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      ).timeout(const Duration(seconds: 4));

      final authUser = res.user;
      if (authUser == null) {
        throw Exception('Sign in failed. No user returned.');
      }

      _mountInitialUser(authUser);
      await refreshUserProfile();

      if (_currentUser != null && !_currentUser!.active) {
        await signOut();
        throw Exception('Your account is deactivated. Please contact your clinic owner.');
      }

      return _currentUser!;
    } catch (e) {
      // Offline fallback
      final offlineUser = OfflineStore().authenticateOffline(cleanEmail, password);
      if (offlineUser != null) {
        _currentUser = offlineUser;
        _isLoading = false;
        notifyListeners();
        return offlineUser;
      }

      _isLoading = false;
      notifyListeners();
      throw Exception(SupabaseConfig.formatError(e));
    }
  }

  /// Sign up new user
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final effectiveRole = _isSuperAdmin(cleanEmail) ? 'owner' : role;

    try {
      final res = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'full_name': cleanName,
          'role': effectiveRole,
        },
      ).timeout(const Duration(seconds: 4));

      final authUser = res.user;
      final uid = authUser?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

      final newUser = UserModel(
        uid: uid,
        name: cleanName,
        email: cleanEmail,
        phone: phone?.trim(),
        role: effectiveRole,
        active: true,
      );

      // Register in local store
      OfflineStore().addDoctor(
        uid: uid,
        name: cleanName,
        email: cleanEmail,
        password: password,
        phone: phone,
      );

      _currentUser = newUser;
      _isLoading = false;
      notifyListeners();
      return newUser;
    } catch (e) {
      // Offline fallback
      final localUid = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final offlineUser = UserModel(
        uid: localUid,
        name: cleanName,
        email: cleanEmail,
        phone: phone?.trim(),
        role: effectiveRole,
        active: true,
        createdAt: DateTime.now(),
      );

      OfflineStore().addDoctor(
        uid: localUid,
        name: cleanName,
        email: cleanEmail,
        password: password,
        phone: phone,
      );

      _currentUser = offlineUser;
      _isLoading = false;
      notifyListeners();
      return offlineUser;
    }
  }

  Future<UserModel> signInWithGoogle() async {
    throw Exception('Google Sign-In is disabled for Supabase HIPAA/DPDP pilot configuration.');
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
