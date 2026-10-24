/// Global constants for Gau-Prahari application.
///
/// User-facing translatable strings (appName, appSubtitle, appVersion)
/// have been moved to the JSON localization files under assets/lang/.
/// Use `AppLocalizations.of(context).translate('appName')` instead.
class AppConstants {
  AppConstants._();

  // Backend configuration (configurable for local dev vs production)
  static const String defaultApiBaseUrl =
      'http://10.0.2.2:8000'; // Android emulator to host
  static const String predictEndpoint = '/api/v1/analysis/predict';

  // Session keys for SharedPreferences
  static const String prefUserKey = 'gau_prahari_current_user';
  static const String prefIsLoggedInKey = 'gau_prahari_is_logged_in';
}
