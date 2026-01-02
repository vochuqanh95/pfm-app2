import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF4A90E2); // Blue
  static const Color secondary = Color(0xFF50E3C2); // Green/Teal

  // Background Colors
  static const Color backgroundLight = Color(0xFFF7F8FC);
  static const Color backgroundDark = Color(0xFF102219);

  // Card Colors
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBackgroundDark = Color(0xFF1E1E1E);

  // Text Colors
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE94E77);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Category Colors
  static const List<Color> categoryColors = [
    Color(0xFF87CEEB), // Light Blue
    Color(0xFFFFB6C1), // Pink
    Color(0xFF98FB98), // Light Green
    Color(0xFFD8BFD8), // Thistle
    Color(0xFFFFDAB9), // Peach
    Color(0xFFFFA07A), // Light Salmon
    Color(0xFF87CEFA), // Light Sky Blue
    Color(0xFFDDA0DD), // Plum
    Color(0xFFB0E0E6), // Powder Blue
    Color(0xFFF0E68C), // Khaki
  ];

  // Wallet Type Colors
  static const Color walletCash = Color(0xFF4CAF50);
  static const Color walletBank = Color(0xFF2196F3);
  static const Color walletCard = Color(0xFF9C27B0);
  static const Color walletEWallet = Color(0xFFFF9800);

  // Chart Colors
  static const Color chartGreen = Color(0xFF50E3C2);
  static const Color chartBlue = Color(0xFF4A90E2);
  static const Color chartRed = Color(0xFFE94E77);
  static const Color chartYellow = Color(0xFFFFD166);
  static const Color chartPurple = Color(0xFF9C6ADE);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Opacity Colors
  static Color primaryLight = primary.withValues(alpha: 0.1);
  static Color secondaryLight = secondary.withValues(alpha: 0.1);
  static Color errorLight = error.withValues(alpha: 0.1);
  static Color warningLight = warning.withValues(alpha: 0.1);
}
