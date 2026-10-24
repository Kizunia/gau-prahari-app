import '../entities/user.dart';

/// Abstract repository defining the contract for authentication operations.
abstract class AuthRepository {
  /// Authenticates a user with identifier (email/ID) and password.
  Future<User> login({required String identifier, required String password});

  /// Registers a new real account with Firebase Authentication and Firestore profile.
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String role,
  });

  /// Starts an isolated demo session without creating cloud accounts.
  Future<User> loginDemo({required String role});

  /// Logs out the currently authenticated user and clears local session.
  Future<void> logout();

  /// Retrieves the currently cached/stored user if session is active.
  Future<User?> getCurrentUser();

  /// Checks whether an authenticated session exists.
  Future<bool> isLoggedIn();
}
