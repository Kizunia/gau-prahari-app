import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// Centralized manager for Firebase initialization.
class FirebaseInitializer {
  static bool _isInitialized = false;

  /// Returns true if Firebase has successfully initialized.
  static bool get isInitialized => _isInitialized;

  /// Initialize Firebase using platform-specific [DefaultFirebaseOptions].
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isInitialized = true;
      debugPrint('Firebase successfully initialized for project: ${Firebase.app().options.projectId}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Firebase initialization failed: $e');
      debugPrint(stackTrace.toString());
      _isInitialized = false;
      return false;
    }
  }
}
