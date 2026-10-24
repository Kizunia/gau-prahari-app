import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import 'auth_repository_impl.dart';

/// Real production implementation of [AuthRepository] backed by Firebase Authentication
/// and Cloud Firestore, with complete isolation for demo sessions.
class FirebaseAuthRepository implements AuthRepository {
  final fb_auth.FirebaseAuth? _explicitAuth;
  final FirebaseFirestore? _explicitFirestore;
  final SharedPreferences? _prefs;
  final AuthRepository _demoFallback;

  FirebaseAuthRepository({
    fb_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    SharedPreferences? prefs,
    AuthRepository? demoFallback,
  })  : _explicitAuth = firebaseAuth,
        _explicitFirestore = firestore,
        _prefs = prefs,
        _demoFallback = demoFallback ?? AuthRepositoryImpl(prefs: prefs);

  fb_auth.FirebaseAuth get _auth =>
      _explicitAuth ?? fb_auth.FirebaseAuth.instance;

  FirebaseFirestore get _firestore =>
      _explicitFirestore ?? FirebaseFirestore.instance;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final cleanRole =
        role.toLowerCase().contains('vet') ? 'veterinarian' : 'farmer';
    final cleanEmail = email.trim().toLowerCase();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw Exception('User registration failed. No credential returned.');
      }

      await fbUser.updateDisplayName(name.trim());

      // Create authoritative user profile in Cloud Firestore 'users' collection
      final userDoc = _firestore.collection('users').doc(fbUser.uid);
      await userDoc.set({
        'uid': fbUser.uid,
        'name': name.trim(),
        'email': cleanEmail,
        'role': cleanRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear any previous demo state
      final prefs = await _getPrefs();
      await prefs.remove(AppConstants.prefUserKey);
      await prefs.setBool(AppConstants.prefIsLoggedInKey, true);

      return UserModel(
        id: fbUser.uid,
        name: name.trim(),
        identifier: cleanEmail,
        role: cleanRole,
        isDemo: false,
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth register error [${e.code}]: ${e.message}');
      throw Exception(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('Registration error: $e');
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  @override
  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    final cleanEmail = identifier.trim().toLowerCase();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw Exception('Authentication failed. No user found.');
      }

      // Read authoritative profile and role from Firestore
      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      String role = 'farmer';
      String name = fbUser.displayName ?? cleanEmail.split('@').first;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        role = (data['role'] as String?)?.toLowerCase() ?? 'farmer';
        name = (data['name'] as String?) ?? name;
      } else {
        // Fallback: create Firestore profile if missing
        await _firestore.collection('users').doc(fbUser.uid).set({
          'uid': fbUser.uid,
          'name': name,
          'email': cleanEmail,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Clear any prior demo session
      final prefs = await _getPrefs();
      await prefs.remove(AppConstants.prefUserKey);
      await prefs.setBool(AppConstants.prefIsLoggedInKey, true);

      return UserModel(
        id: fbUser.uid,
        name: name,
        identifier: cleanEmail,
        role: role,
        isDemo: false,
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth login error [${e.code}]: ${e.message}');
      throw Exception(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('Login error: $e');
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  @override
  Future<User> loginDemo({required String role}) async {
    // Isolated demo mode: sign out of Firebase and delegate to local demo repository
    try {
      await _auth.signOut();
    } catch (_) {}
    return _demoFallback.loginDemo(role: role);
  }

  @override
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out of Firebase Auth: $e');
    }
    await _demoFallback.logout();
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final fbUser = _auth.currentUser;
      if (fbUser != null) {
        try {
          final doc =
              await _firestore.collection('users').doc(fbUser.uid).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            return UserModel(
              id: fbUser.uid,
              name: (data['name'] as String?) ?? fbUser.displayName ?? 'User',
              identifier: fbUser.email ?? '',
              role: (data['role'] as String?)?.toLowerCase() ?? 'farmer',
              isDemo: false,
            );
          }
        } catch (e) {
          debugPrint('Error fetching user profile from Firestore: $e');
        }
        return UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? fbUser.email?.split('@').first ?? 'User',
          identifier: fbUser.email ?? '',
          role: 'farmer',
          isDemo: false,
        );
      }
    } catch (_) {
      // In tests where Firebase is not initialized, fallback to demo repository
    }

    // Check for active demo session
    return _demoFallback.getCurrentUser();
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      if (_auth.currentUser != null) {
        return true;
      }
    } catch (_) {}
    return _demoFallback.isLoggedIn();
  }

  String _mapFirebaseAuthError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in or use another email.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet connection.';
      case 'user-disabled':
        return 'This user account has been disabled. Please contact support.';
      default:
        return e.message ??
            'Authentication error (${e.code}). Please try again.';
    }
  }
}
