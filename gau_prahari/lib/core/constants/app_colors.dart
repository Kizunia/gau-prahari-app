import 'package:flutter/material.dart';

/// Centralized color palette for the Gau-Prahari application.
/// Incorporates earthy greens, clean neutrals, and alert indicators.
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryDark = Color(0xFF0F4214);
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color primaryAccent = Color(0xFF2E7D32);

  // Secondary & Accent Colors
  static const Color secondary = Color(0xFFD97706); // Warm amber
  static const Color secondaryLight = Color(0xFFFEF3C7);

  // Neutral Backgrounds & Surfaces
  static const Color background = Color(0xFFF8FAF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F3);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textLight = Color(0xFFFFFFFF);

  // Status & Feedback Colors
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);

  // Borders & Dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderFocused = Color(0xFF1B5E20);
}
