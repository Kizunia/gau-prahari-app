import 'package:flutter/material.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Enum representing the state of authentication.
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Controller managing authentication state and user sessions.
class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthStatus _status = AuthStatus.initial;
  User? _currentUser;
  String? _errorMessage;

  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _currentUser != null;

  /// Check persisted session on app launch
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final isLoggedIn = await _authRepository.isLoggedIn();
      if (isLoggedIn) {
        _currentUser = await _authRepository.getCurrentUser();
        if (_currentUser != null) {
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  /// Perform user login
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.login(
        identifier: identifier,
        password: password,
      );
      _currentUser = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Register a new account with email/password and role
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.register(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      _currentUser = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Start an isolated demo session
  Future<bool> loginDemo({required String role}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.loginDemo(role: role);
      _currentUser = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Perform user logout
  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authRepository.logout();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Clear any active error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
