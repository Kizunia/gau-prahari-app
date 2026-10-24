import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

/// Concrete implementation of [AuthRepository] using local session persistence.
class AuthRepositoryImpl implements AuthRepository {
  final SharedPreferences? _prefs;

  AuthRepositoryImpl({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  // Pre-configured hackathon/field demo users
  static final List<UserModel> _demoUsers = [
    const UserModel(
      id: 'USR-101',
      name: 'Dr. Rajesh Sharma',
      identifier: 'vet@gauprahari.org',
      role: 'Field Veterinarian',
    ),
    const UserModel(
      id: 'USR-102',
      name: 'Ramesh Patel',
      identifier: 'farmer@gauprahari.org',
      role: 'Dairy Farm Supervisor',
    ),
    const UserModel(
      id: 'USR-103',
      name: 'SIH Evaluator',
      identifier: 'admin@gauprahari.org',
      role: 'System Administrator',
    ),
  ];

  @override
  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    // Simulate slight network latency for realistic UX
    await Future.delayed(const Duration(milliseconds: 600));

    final trimmedId = identifier.trim().toLowerCase();

    // Check against demo accounts or accept standard demo format
    UserModel? matchedUser;
    try {
      matchedUser = _demoUsers.firstWhere(
        (u) => u.identifier.toLowerCase() == trimmedId,
      );
    } catch (_) {
      matchedUser = null;
    }

    // Default fallback: allow any valid identifier with password length >= 4
    if (matchedUser == null) {
      if (password.trim().length < 4) {
        throw Exception(
          'Invalid password. Password must be at least 4 characters.',
        );
      }
      matchedUser = UserModel(
        id: 'USR-${DateTime.now().millisecondsSinceEpoch % 10000}',
        name: trimmedId.split('@').first.toUpperCase(),
        identifier: trimmedId,
        role: 'Dairy Officer',
      );
    }

    // Persist user session
    final prefs = await _getPrefs();
    await prefs.setString(AppConstants.prefUserKey, matchedUser.toJsonString());
    await prefs.setBool(AppConstants.prefIsLoggedInKey, true);

    return matchedUser;
  }

  @override
  Future<void> logout() async {
    final prefs = await _getPrefs();
    await prefs.remove(AppConstants.prefUserKey);
    await prefs.setBool(AppConstants.prefIsLoggedInKey, false);
  }

  @override
  Future<User?> getCurrentUser() async {
    final prefs = await _getPrefs();
    final userJson = prefs.getString(AppConstants.prefUserKey);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        return UserModel.fromJsonString(userJson);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<bool> isLoggedIn() async {
    final prefs = await _getPrefs();
    return prefs.getBool(AppConstants.prefIsLoggedInKey) ?? false;
  }
}
