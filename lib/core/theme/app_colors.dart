import 'package:flutter/material.dart';

/// Sustainable recycling-inspired colour palette for ScrapWise.
class AppColors {
  AppColors._();

  // Primary – deep forest green
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF60AD5E);
  static const Color primaryDark = Color(0xFF005005);
  static const Color onPrimary = Colors.white;

  // Secondary – warm amber (recycling energy)
  static const Color secondary = Color(0xFFFF8F00);
  static const Color secondaryLight = Color(0xFFFFBF47);
  static const Color secondaryDark = Color(0xFFC56000);
  static const Color onSecondary = Colors.black;

  // Surface & background
  static const Color surface = Color(0xFFF9FBF7);
  static const Color surfaceVariant = Color(0xFFE8F5E9);
  static const Color background = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1B1E1A);
  static const Color onBackground = Color(0xFF1B1E1A);

  // Error
  static const Color error = Color(0xFFB00020);
  static const Color onError = Colors.white;

  // Neutral shades
  static const Color grey50 = Color(0xFFF5F5F5);
  static const Color grey100 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey800 = Color(0xFF424242);

  // Text
  static const Color textPrimary = Color(0xFF1B1E1A);
  static const Color textSecondary = Color(0xFF4A4D49);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnDark = Colors.white;

  // Gradient for splash / landing
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
  );
}
