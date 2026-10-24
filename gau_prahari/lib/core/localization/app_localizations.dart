import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'en_fallback.dart';

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
  Map<String, String> _localizedStrings = enFallback;

  AppLocalizations(this.locale) {
    if (locale.languageCode == 'en') {
      _localizedStrings = enFallback;
    }
  }

  /// Custom constructor with pre-loaded translations, useful for testing and offline mocking.
  AppLocalizations.fromMap(this.locale, this._localizedStrings);

  /// Convenience accessor from any widget BuildContext.
  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (instance != null) return instance;
    return AppLocalizations.fromMap(const Locale('en'), enFallback);
  }

  /// Load the JSON translation file for the current locale.
  Future<bool> load() async {
    if (locale.languageCode == 'en') {
      _localizedStrings = enFallback;
      return true;
    }
    try {
      final jsonString = await rootBundle.loadString(
        'assets/lang/app_${locale.languageCode}.json',
      ).timeout(const Duration(milliseconds: 200));
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings = jsonMap.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      return true;
    } catch (_) {
      // In widget tests or offline mock bundles, safely fall back to bundled dictionary
      _localizedStrings = enFallback;
      return true;
    }
  }

  /// Translate a key to the current locale's string.
  ///
  /// Supports placeholder interpolation: pass [args] as a map of
  /// `{placeholder}` → `value` pairs. E.g.:
  /// ```dart
  /// t.translate('collarTelemetryDescription', args: {'cowId': 'COW-104'})
  /// ```
  String translate(String key, {Map<String, String>? args}) {
    String value = _localizedStrings[key] ?? enFallback[key] ?? key;
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

  /// Localizes a cow's health/test status.
  String translateStatus(String rawStatus) {
    final clean = rawStatus.trim().toLowerCase();
    if (clean.contains('ready')) return translate('statusReadyForTest');
    if (clean.contains('collar')) return translate('statusCollarHistoryAvailable');
    if (clean.contains('needs milk')) return translate('statusNeedsMilkTest');
    if (clean.contains('testing')) return translate('statusTesting');
    if (clean.contains('at risk') || clean.contains('risk')) return translate('statusAtRisk');
    return rawStatus;
  }

  /// Localizes a cow's breed.
  String translateBreed(String rawBreed) {
    final clean = rawBreed.trim().toLowerCase();
    if (clean.contains('gir') || clean.contains('sahiwal')) return translate('breedGirSahiwal');
    if (clean.contains('murrah') || clean.contains('buffalo')) return translate('breedMurrahBuffalo');
    if (clean.contains('tharparkar')) return translate('breedTharparkar');
    if (clean.contains('sindhi')) return translate('breedRedSindhi');
    if (clean.contains('indigenous')) return translate('breedIndigenous');
    return rawBreed;
  }

  /// Localizes a cow's lactation stage.
  String translateLactation(String rawLactation) {
    final clean = rawLactation.trim().toLowerCase();
    if (clean.contains('early')) return translate('lactationEarly');
    if (clean.contains('mid')) return translate('lactationMid');
    if (clean.contains('fresh')) return translate('lactationFresh');
    if (clean.contains('late')) return translate('lactationLate');
    return rawLactation;
  }

  /// Localizes a user's role.
  String translateRole(String rawRole) {
    final clean = rawRole.trim().toLowerCase();
    if (clean.contains('vet')) return translate('roleFieldVet');
    if (clean.contains('farmer')) return translate('roleDairyFarmer');
    if (clean.contains('supervisor')) return translate('roleFarmSupervisor');
    if (clean.contains('evaluator')) return translate('roleEvaluator');
    if (clean.contains('admin')) return translate('roleSystemAdmin');
    return rawRole;
  }

  /// Localizes an AI mastitis diagnostic factor string.
  String translateFactor(String rawFactor) {
    if (locale.languageCode == 'en') {
      return rawFactor;
    }
    if (rawFactor.contains('Somatic Cell Count')) {
      final match = RegExp(r'\(([\d,]+)\s*cells').firstMatch(rawFactor);
      final val = match?.group(1) ?? '250,000+';
      return translate('factorScc', args: {'value': val});
    }
    if (rawFactor.contains('Conductivity')) {
      final match = RegExp(r'\(([\d\.]+)\s*mS').firstMatch(rawFactor);
      final val = match?.group(1) ?? '5.8+';
      return translate('factorConductivity', args: {'value': val});
    }
    if (rawFactor.contains('Alkaline pH')) {
      final match = RegExp(r'\(([\d\.]+)\s*>').firstMatch(rawFactor);
      final val = match?.group(1) ?? '6.80+';
      return translate('factorAlkalinePh', args: {'value': val});
    }
    if (rawFactor.contains('Acidic pH')) {
      final match = RegExp(r'\(([\d\.]+)\s*<').firstMatch(rawFactor);
      final val = match?.group(1) ?? '6.50-';
      return translate('factorAcidicPh', args: {'value': val});
    }
    if (rawFactor.contains('Milk Temperature')) {
      final match = RegExp(r'\(([\d\.]+)\s*°C').firstMatch(rawFactor);
      final val = match?.group(1) ?? '37.8+';
      return translate('factorTemp', args: {'value': val});
    }
    if (rawFactor.contains('physiological baseline') || rawFactor.contains('physical milk')) {
      return translate('factorNormal');
    }
    return rawFactor;
  }

  /// Localizes the clinical recommendation based on risk level or text pattern.
  String translateRecommendation(String rawRecommendation, [String? riskLevel]) {
    if (locale.languageCode == 'en') {
      return rawRecommendation;
    }
    final level = (riskLevel ?? '').toUpperCase();
    if (level == 'HIGH' || rawRecommendation.toLowerCase().contains('isolate')) {
      return translate('recommendedActionHigh');
    }
    if (level == 'MODERATE' || rawRecommendation.toLowerCase().contains('subclinical')) {
      return translate('recommendedActionModerate');
    }
    if (level == 'LOW' || rawRecommendation.toLowerCase().contains('healthy')) {
      return translate('recommendedActionLow');
    }
    return rawRecommendation;
  }

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
    if (locale.languageCode == 'en') {
      return SynchronousFuture<AppLocalizations>(localizations);
    }
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
