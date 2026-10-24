import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'default_english.dart';

/// Custom localization class that loads translations from JSON asset files.
///
/// Usage in widgets:
/// ```dart
/// final t = AppLocalizations.of(context);
/// Text(t.translate('signIn'));
/// Text(t.translate('collarTelemetryDescription', args: {'cowId': cow.id}));
/// ```
class AppLocalizations {
  final Locale locale;
  Map<String, String> _localizedStrings = defaultEnglish;

  AppLocalizations(this.locale);

  /// Convenience accessor from any widget BuildContext.
  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    if (instance != null) return instance;
    final fallback = AppLocalizations(const Locale('en'));
    fallback._localizedStrings = defaultEnglish;
    return fallback;
  }

  /// Load the JSON translation file for the current locale.
  Future<bool> load() async {
    final jsonString = await rootBundle.loadString(
      'assets/lang/app_${locale.languageCode}.json',
    );
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings = jsonMap.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    return true;
  }

  /// Translate a key to the current locale's string.
  ///
  /// Supports placeholder interpolation: pass [args] as a map of
  /// `{placeholder}` → `value` pairs. E.g.:
  /// ```dart
  /// t.translate('collarTelemetryDescription', args: {'cowId': 'COW-104'})
  /// ```
  String translate(String key, {Map<String, String>? args}) {
    String value = _localizedStrings[key] ?? defaultEnglish[key] ?? key;
    if (args != null) {
      args.forEach((placeholder, replacement) {
        value = value.replaceAll('{$placeholder}', replacement);
      });
    }
    return value;
  }

  /// Short alias for [translate].
  String t(String key, {Map<String, String>? args}) =>
      translate(key, args: args);

  /// The list of supported locales in this app.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
  ];

  /// Check if a locale is supported.
  static bool isSupported(Locale locale) {
    return supportedLocales
        .map((l) => l.languageCode)
        .contains(locale.languageCode);
  }

  /// The delegate that Flutter uses to load our localizations.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

/// Delegate that loads [AppLocalizations] for the requested locale.
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.isSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
