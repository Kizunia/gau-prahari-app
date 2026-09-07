/// Global constants for Gau-Prahari application.
class AppConstants {
  AppConstants._();

  static const String appName = 'Gau-Prahari';
  static const String appSubtitle = 'Early Bovine Mastitis Forecasting';
  static const String appVersion = 'v1.0.0 (Round II)';

  // Backend configuration (configurable for local dev vs production)
  static const String defaultApiBaseUrl = 'http://10.0.2.2:8000'; // Android emulator to host
  static const String predictEndpoint = '/api/v1/analysis/predict';

  // Session keys for SharedPreferences
  static const String prefUserKey = 'gau_prahari_current_user';
  static const String prefIsLoggedInKey = 'gau_prahari_is_logged_in';
}
