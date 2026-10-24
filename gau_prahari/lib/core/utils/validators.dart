import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

/// Utility class for form validations.
///
/// Validators accept [BuildContext] to provide localized error messages.
class Validators {
  Validators._();

  static String? validateIdentifier(String? value, BuildContext context) {
    final t = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return t.translate('validatorIdentifierRequired');
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return t.translate('validatorIdentifierMinLength');
    }
    return null;
  }

  static String? validatePassword(String? value, BuildContext context) {
    final t = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return t.translate('validatorPasswordRequired');
    }
    if (value.length < 4) {
      return t.translate('validatorPasswordMinLength');
    }
    return null;
  }

  static String? validateRequired(
    String? value,
    String fieldName,
    BuildContext context,
  ) {
    final t = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return t.translate(
        'validatorFieldRequired',
        args: {'fieldName': fieldName},
      );
    }
    return null;
  }
}
