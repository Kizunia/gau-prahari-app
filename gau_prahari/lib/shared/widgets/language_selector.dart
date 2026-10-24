import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/locale_controller.dart';

/// Compact language selector widget that allows users to switch the app language.
///
/// Displays available languages as a dropdown button suitable for placing
/// in an AppBar or settings area.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = context.watch<LocaleController>();
    final currentCode = localeController.locale.languageCode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentCode,
          isDense: true,
          icon: const Icon(
            Icons.language_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items: LocaleController.availableLocales.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: entry.key == currentCode
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: entry.key == currentCode
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (code) {
            if (code != null) {
              localeController.setLocale(Locale(code));
            }
          },
        ),
      ),
    );
  }
}
