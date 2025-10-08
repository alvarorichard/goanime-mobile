import 'package:flutter/material.dart';

/// GoAnime Color Palette - Streaming Platform Design
///
/// Design Philosophy (Inspired by Netflix, Disney+, HBO Max):
/// - Base: Pure Black - Premium streaming platform aesthetic
/// - Primary: Cyan/Teal - Technology, innovation, interactive elements
/// - Secondary: Deep Purple - Premium content, mystery, fantasy
/// - Accent: Pink/Magenta - Energy, action, calls-to-action
/// - Focus: Clean, minimal, content-first approach
///
/// This palette follows modern streaming service design language:
/// maximizing contrast for content visibility while using vibrant
/// accent colors for navigation and interaction.
class AppColors {
  AppColors._();

  // Primary Colors - Main brand identity (Cyan accents)
  static const Color primary = Color(0xFF00BCD4); // Cyan 500
  static const Color primaryLight = Color(0xFF4DD0E1); // Cyan 300
  static const Color primaryDark = Color(0xFF0097A7); // Cyan 700
  static const Color primaryGlow = Color(0xFF00E5FF); // Cyan A400

  // Secondary Colors - Supporting elements (Purple accents)
  static const Color secondary = Color(0xFF7C4DFF); // Deep Purple A200
  static const Color secondaryLight = Color(0xFFB47CFF); // Deep Purple A100
  static const Color secondaryDark = Color(0xFF651FFF); // Deep Purple A400

  // Accent Colors - Call to actions and highlights (Pink accents)
  static const Color accent = Color(0xFFFF4081); // Pink A200
  static const Color accentLight = Color(0xFFFF80AB); // Pink A100
  static const Color accentDark = Color(0xFFF50057); // Pink A400

  // Background Colors - Pure Black Base (Netflix/Disney+ style)
  static const Color background = Color(0xFF000000); // Pure Black
  static const Color backgroundLight = Color(0xFF0A0A0A); // Almost Black
  static const Color surface = Color(0xFF141414); // Dark Gray (Netflix cards)
  static const Color surfaceLight = Color(0xFF1E1E1E); // Elevated surface
  static const Color surfaceHover = Color(0xFF282828); // Hover state

  // Text Colors - High contrast on black
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure white
  static const Color textSecondary = Color(0xFFB3B3B3); // Light gray (Netflix style)
  static const Color textTertiary = Color(0xFF808080); // Medium gray
  static const Color textDisabled = Color(0xFF4D4D4D); // Dark gray

  // Status Colors
  static const Color success = Color(0xFF4CAF50); // Green 500
  static const Color warning = Color(0xFFFFC107); // Amber 500
  static const Color error = Color(0xFFF44336); // Red 500
  static const Color info = Color(0xFF2196F3); // Blue 500

  // Feature-specific Colors
  static const Color qualityTag = Color(0xFF9C27B0); // Purple 500
  static const Color speedTag = Color(0xFF2196F3); // Blue 500
  static const Color cloudTag = Color(0xFF4CAF50); // Green 500
  static const Color liveIndicator = Color(0xFFFF5252); // Red A200

  // Gradient Presets
  static const List<Color> primaryGradient = [
    Color(0xFF00BCD4), // Cyan
    Color(0xFF0097A7), // Darker Cyan
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF7C4DFF), // Deep Purple
    Color(0xFF651FFF), // Darker Deep Purple
  ];

  static const List<Color> accentGradient = [
    Color(0xFFFF4081), // Pink
    Color(0xFFF50057), // Darker Pink
  ];

  static const List<Color> heroGradient = [
    Color(0xFF00BCD4), // Cyan
    Color(0xFF7C4DFF), // Deep Purple
  ];

  // Utility methods
  static LinearGradient getPrimaryGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: primaryGradient);
  }

  static LinearGradient getSecondaryGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: secondaryGradient);
  }

  static LinearGradient getHeroGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: heroGradient);
  }

  // Shadow colors with opacity
  static Color get primaryShadow => primary.withValues(alpha: 0.3);
  static Color get secondaryShadow => secondary.withValues(alpha: 0.3);
  static Color get accentShadow => accent.withValues(alpha: 0.3);
}
