/// QuickFit Application Colors
///
/// Implements a "Stark/Avant-Garde" palette:
/// - True Black / True White backgrounds
/// - High-voltage Cobalt Blue accent
/// - Minimal greys for structure
library;

import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.cardBackground,
    required this.cardBorder,
    required this.mutedText,
    required this.divider,
    required this.cobaltAccent,
    required this.glassFrost,
    required this.successBackground,
    required this.successBorder,
    required this.successText,
    required this.urgentBackground,
    required this.urgentBorder,
    required this.urgentText,
    required this.surfaceSubtle,
  });

  final Color cardBackground;
  final Color cardBorder;
  final Color mutedText;
  final Color divider;
  final Color cobaltAccent;
  final Color glassFrost;

  // Semantic: Success flow
  final Color successBackground;
  final Color successBorder;
  final Color successText;

  // Semantic: Urgent/SOS flow
  final Color urgentBackground;
  final Color urgentBorder;
  final Color urgentText;

  // Utility
  final Color surfaceSubtle;

  @override
  ThemeExtension<AppColors> copyWith({
    Color? cardBackground,
    Color? cardBorder,
    Color? mutedText,
    Color? divider,
    Color? cobaltAccent,
    Color? glassFrost,
    Color? successBackground,
    Color? successBorder,
    Color? successText,
    Color? urgentBackground,
    Color? urgentBorder,
    Color? urgentText,
    Color? surfaceSubtle,
  }) {
    return AppColors(
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      mutedText: mutedText ?? this.mutedText,
      divider: divider ?? this.divider,
      cobaltAccent: cobaltAccent ?? this.cobaltAccent,
      glassFrost: glassFrost ?? this.glassFrost,
      successBackground: successBackground ?? this.successBackground,
      successBorder: successBorder ?? this.successBorder,
      successText: successText ?? this.successText,
      urgentBackground: urgentBackground ?? this.urgentBackground,
      urgentBorder: urgentBorder ?? this.urgentBorder,
      urgentText: urgentText ?? this.urgentText,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cobaltAccent: Color.lerp(cobaltAccent, other.cobaltAccent, t)!,
      glassFrost: Color.lerp(glassFrost, other.glassFrost, t)!,
      successBackground:
          Color.lerp(successBackground, other.successBackground, t)!,
      successBorder: Color.lerp(successBorder, other.successBorder, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      urgentBackground:
          Color.lerp(urgentBackground, other.urgentBackground, t)!,
      urgentBorder: Color.lerp(urgentBorder, other.urgentBorder, t)!,
      urgentText: Color.lerp(urgentText, other.urgentText, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
    );
  }

  static const light = AppColors(
    cardBackground: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE5E5E5),
    mutedText: Color(0xFF6B7280),
    divider: Color(0xFFF3F4F6),
    cobaltAccent: Color(0xFF2D5BFF),
    glassFrost: Color(0xCCFFFFFF),
    successBackground: Color(0xFFECFDF5),
    successBorder: Color(0xFF10B981),
    successText: Color(0xFF065F46),
    urgentBackground: Color(0xFFFEF2F2),
    urgentBorder: Color(0xFFEF4444),
    urgentText: Color(0xFF991B1B),
    surfaceSubtle: Color(0xFFF9FAFB),
  );

  static const dark = AppColors(
    cardBackground: Color(0xFF18181B),
    cardBorder: Color(0xFF27272A),
    mutedText: Color(0xFFA1A1AA),
    divider: Color(0xFF27272A),
    cobaltAccent: Color(0xFF2D5BFF),
    glassFrost: Color(0xCC000000),
    successBackground: Color(0xFF064E3B),
    successBorder: Color(0xFF10B981),
    successText: Color(0xFFD1FAE5),
    urgentBackground: Color(0xFF7F1D1D),
    urgentBorder: Color(0xFFEF4444),
    urgentText: Color(0xFFFEE2E2),
    surfaceSubtle: Color(0xFF09090B),
  );
}

/// Extension to access [AppColors] from [BuildContext]
extension AppColorsExtension on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
