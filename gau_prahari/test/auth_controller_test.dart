import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/auth/domain/entities/user.dart';
import 'package:gau_prahari/features/auth/domain/repositories/auth_repository.dart';
import 'package:gau_prahari/features/auth/presentation/controllers/auth_controller.dart';

class FakeAuthRepository implements AuthRepository {
  User? _user;
  bool _loggedIn = false;

  @override
  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    if (password == 'fail') {
      throw Exception('Invalid credentials provided');
    }
    _user = User(
      id: 'USR-001',
      name: 'Ramesh',
      identifier: identifier,
      role: 'Dairy Farmer',
    );
    _loggedIn = true;
    return _user!;
  }

  @override
  Future<void> logout() async {
    _user = null;
    _loggedIn = false;
  }

  @override
  Future<User?> getCurrentUser() async => _user;

  @override
  Future<bool> isLoggedIn() async => _loggedIn;
}

void main() {
  group('AuthController Tests', () {
    late FakeAuthRepository repository;
    late AuthController controller;

    setUp(() {
      repository = FakeAuthRepository();
      controller = AuthController(authRepository: repository);
    });

    test('Initial status is unauthenticated after checkAuthStatus with no session', () async {
      expect(controller.status, AuthStatus.initial);
      await controller.checkAuthStatus();
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.isAuthenticated, false);
      expect(controller.currentUser, isNull);
    });

    test('Login succeeds with valid credentials and sets authenticated status', () async {
      final success = await controller.login(
        identifier: 'farmer@gauprahari.org',
        password: 'validpassword',
      );

      expect(success, true);
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.isAuthenticated, true);
      expect(controller.currentUser?.identifier, 'farmer@gauprahari.org');
      expect(controller.errorMessage, isNull);
    });

    test('Login fails with invalid credentials and sets error status', () async {
      final success = await controller.login(
        identifier: 'farmer@gauprahari.org',
        password: 'fail',
      );

      expect(success, false);
      expect(controller.status, AuthStatus.error);
      expect(controller.isAuthenticated, false);
      expect(controller.errorMessage, contains('Invalid credentials'));
    });

    test('Logout clears current user and sets unauthenticated status', () async {
      await controller.login(
        identifier: 'farmer@gauprahari.org',
        password: 'validpassword',
      );
      expect(controller.isAuthenticated, true);

      await controller.logout();
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.isAuthenticated, false);
      expect(controller.currentUser, isNull);
    });
  });
}
