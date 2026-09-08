import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';

/// Controller that manages the active locale and persists the user's
/// language preference to SharedPreferences.
class LocaleController extends ChangeNotifier {
  static const String _prefKey = 'gau_prahari_locale';

  Locale _locale = const Locale('en');

  LocaleController();

  Locale get locale => _locale;

  /// Available languages with their display names.
  static const Map<String, String> availableLocales = {
    'en': 'English',
    'hi': 'हिन्दी',
    'mr': 'मराठी',
  };

  /// Load the saved locale from SharedPreferences.
  /// Call this once during app initialization.
  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefKey);
    if (savedCode != null && AppLocalizations.isSupported(Locale(savedCode))) {
      _locale = Locale(savedCode);
      notifyListeners();
    }
  }

  /// Switch to a new locale and persist it.
  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    if (!AppLocalizations.isSupported(newLocale)) return;

    _locale = newLocale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, newLocale.languageCode);
  }
}
