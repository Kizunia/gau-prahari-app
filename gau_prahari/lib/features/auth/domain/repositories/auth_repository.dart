import '../entities/user.dart';

/// Abstract repository defining the contract for authentication operations.
abstract class AuthRepository {
  /// Authenticates a user with identifier (email/ID) and password.
  Future<User> login({
    required String identifier,
    required String password,
  });

  /// Logs out the currently authenticated user and clears local session.
  Future<void> logout();

  /// Retrieves the currently cached/stored user if session is active.
  Future<User?> getCurrentUser();

  /// Checks whether an authenticated session exists.
  Future<bool> isLoggedIn();
}
