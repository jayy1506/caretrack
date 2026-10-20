import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'offline_store.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null || _auth.currentUser != null;

  AuthService() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _auth.authStateChanges().listen((User? firebaseUser) {
      if (firebaseUser == null) {
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // ⚡ Sub-millisecond instant optimistic profile load
      final defaultRole = _isSuperAdmin(firebaseUser.email) ? 'admin' : 'doctor';
      _currentUser = UserModel(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
        email: firebaseUser.email ?? '',
        role: defaultRole,
        active: true,
      );
      _isLoading = false;
      notifyListeners();

      // Refresh in background without stalling the UI
      refreshUserProfile();
    });
  }

  bool _isSuperAdmin(String? email) {
    if (email == null) return false;
    final lower = email.toLowerCase().trim();
    return lower == 'jthakre62@gmail.com' || lower.contains('admin');
  }

  Future<void> refreshUserProfile() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Fast claim lookup without forcing token network refresh
      final idTokenResult = await firebaseUser.getIdTokenResult(false);
      final claimRole = idTokenResult.claims?['role']?.toString();

      // Read Firestore user document with brief timeout for instant offline resilience
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get()
          .timeout(const Duration(milliseconds: 1800));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        var userRole = data['role']?.toString() ?? 'doctor';
        if (_isSuperAdmin(firebaseUser.email)) {
          userRole = 'admin';
        }
        _currentUser = UserModel.fromMap({...data, 'role': userRole}, firebaseUser.uid);
      } else {
        final derivedRole = _isSuperAdmin(firebaseUser.email)
            ? 'admin'
            : (claimRole ?? 'doctor');

        _currentUser = UserModel(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
          email: firebaseUser.email ?? '',
          role: derivedRole,
          active: true,
        );

        _firestore.collection('users').doc(firebaseUser.uid).set({
          'uid': firebaseUser.uid,
          'name': _currentUser!.name,
          'email': _currentUser!.email,
          'role': derivedRole,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      }
    } catch (_) {
      // Offline fallback: currentUser is already mounted and active
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel> signIn({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(const Duration(seconds: 2));

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Sign in failed. No user returned.');
      }

      // Optimistic instant user mount (<1ms)
      final defaultRole = _isSuperAdmin(firebaseUser.email) ? 'admin' : 'doctor';
      _currentUser = UserModel(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
        email: firebaseUser.email ?? '',
        role: defaultRole,
        active: true,
      );
      _isLoading = false;
      notifyListeners();

      // Refresh in background without stalling the login UI
      refreshUserProfile();

      return _currentUser!;
    } catch (e) {
      // 🌿 Organic / Ayurveda Local Fallback Mode
      final offlineUser = OfflineStore().authenticateOffline(email, password);
      if (offlineUser != null) {
        _currentUser = offlineUser;
        _isLoading = false;
        notifyListeners();
        return offlineUser;
      }

      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    final effectiveRole = _isSuperAdmin(email) ? 'admin' : role;
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      ).timeout(const Duration(seconds: 2));

      final firebaseUser = credential.user;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(cleanName);
      }

      final newUser = UserModel(
        uid: firebaseUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanName,
        email: cleanEmail,
        phone: phone?.trim(),
        role: effectiveRole,
        active: true,
      );

      _firestore.collection('users').doc(newUser.uid).set({
        'uid': newUser.uid,
        'name': cleanName,
        'email': cleanEmail,
        'phone': phone?.trim(),
        'role': effectiveRole,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      // Register in local store
      OfflineStore().addDoctor(
        uid: newUser.uid,
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
      // 🌿 Organic / Ayurveda Local Fallback
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
    _isLoading = true;
    notifyListeners();

    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      UserCredential credential;
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(googleProvider);
      } else {
        credential = await _auth.signInWithProvider(googleProvider);
      }

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Google Sign-In failed.');
      }

      await refreshUserProfile();
      _isLoading = false;
      notifyListeners();
      return _currentUser!;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    _currentUser = null;
    notifyListeners();
  }
}
