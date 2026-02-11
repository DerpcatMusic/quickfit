/// QuickFit App Theme Configuration
///
/// Material 3 theme with cobalt-forward branding and crisp surfaces.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Main theme configuration for QuickFit app.
class AppTheme {
  AppTheme._();

  /// Primary brand color - Electric Cobalt.
  static const Color primarySeedColor = Color(0xFF2D5BFF);

  /// Role-specific seed colors (can be used for subtle tinting if needed)
  static const Color instructorSeedColor = Color(0xFF2D5BFF);
  static const Color studioSeedColor = Color(0xFF8F00FF); // Electric Purple

  static Color getSeedColor(String? role) {
    if (role?.toLowerCase() == 'studio') {
      return studioSeedColor;
    }
    return primarySeedColor;
  }

  /// Strict Geometric Shape - 12px Radius (No Squircles)
  static const OutlinedBorder geometricShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12.0)),
  );

  /// Rounded shape for smaller components (chips/badges)
  static const OutlinedBorder pillShape = StadiumBorder();

  /// Generates theme data for the given brightness.
  static ThemeData getThemeData(
    ColorScheme? dynamicColorScheme,
    Brightness brightness, {
    String? role,
  }) {
    final isDark = brightness == Brightness.dark;
    var appColors = isDark ? AppColors.dark : AppColors.light;

    // Determine primary color based on role
    final primaryColor = getSeedColor(role);

    // Override cobaltAccent with the role-specific primary color
    appColors = appColors.copyWith(cobaltAccent: primaryColor) as AppColors;

    // Build color scheme - Force high contrast
    ColorScheme scheme;
    if (dynamicColorScheme != null) {
      scheme = dynamicColorScheme.copyWith(
        primary: appColors.cobaltAccent,
        secondary: appColors.cobaltAccent,
      );
    } else {
      scheme = ColorScheme.fromSeed(
        seedColor: appColors.cobaltAccent,
        brightness: brightness,
        primary: appColors.cobaltAccent,
      );
    }

    // Override surface colors for stark look
    scheme = scheme.copyWith(
      surface: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF), // True Black/White
      onSurface: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF111111),
      surfaceContainer: isDark
          ? const Color(0xFF18181B)
          : const Color(0xFFF4F4F5), // Zinc 900/100
      surfaceContainerHighest:
          isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
      outline: appColors.cardBorder,
      outlineVariant: appColors.divider,
    );

    final textTheme = (isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamily: 'Noto Sans Hebrew',
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Noto Sans Hebrew',
      fontFamilyFallback: const <String>['Noto Sans', 'Roboto', 'sans-serif'],
      textTheme: textTheme,
      extensions: [appColors],
      platform: defaultTargetPlatform,
      cupertinoOverrideTheme: getCupertinoTheme(
        brightness,
        role: role,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      // Scaffold - Solid
      scaffoldBackgroundColor: scheme.surface,

      // AppBar - Minimal
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700, // Bolder
          color: scheme.onSurface,
          letterSpacing: -0.5, // Tight
        ),
      ),

      // Cards - Bordered, No Shadow (Uber Style)
      cardTheme: CardThemeData(
        shape: geometricShape.copyWith(
          side: BorderSide(color: appColors.cardBorder, width: 1),
        ),
        elevation: 0,
        color: appColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // Filled buttons - Cobalt
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: geometricShape,
          backgroundColor: appColors.cobaltAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Elevated buttons - Tonal
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: geometricShape,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 0,
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined buttons - Sharp
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: geometricShape,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: BorderSide(color: appColors.cardBorder, width: 1),
          foregroundColor: scheme.onSurface,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: geometricShape,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          foregroundColor: appColors.cobaltAccent,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Input decoration - Architectural
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appColors.cobaltAccent, width: 2),
        ),
        filled: true,
        fillColor: dateInputFill(isDark),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: appColors.mutedText),
        hintStyle: TextStyle(color: appColors.mutedText.withValues(alpha: 0.7)),
      ),

      // Bottom navigation - Clean
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        selectedItemColor: appColors.cobaltAccent,
        unselectedItemColor: appColors.mutedText,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
      ),

      // Navigation bar (M3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        indicatorColor: appColors.cobaltAccent.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: appColors.cobaltAccent);
          }
          return IconThemeData(color: appColors.mutedText);
        }),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: appColors.divider,
        thickness: 1,
        space: 1,
      ),

      // Dialog - Sharp
      dialogTheme: DialogThemeData(
        shape: geometricShape,
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        titleTextStyle:
            textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),

      // Bottom sheet - Sharp top
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surfaceContainer,
      ),

      // FAB - Cobalt Circle or Rounded Square
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16)), // Slightly rounder than cards
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: appColors.cobaltAccent,
        foregroundColor: Colors.white,
      ),
    );
  }

  static CupertinoThemeData getCupertinoTheme(
    Brightness brightness, {
    String? role,
  }) {
    final isDark = brightness == Brightness.dark;
    var appColors = isDark ? AppColors.dark : AppColors.light;
    final primaryColor = getSeedColor(role);
    appColors = appColors.copyWith(cobaltAccent: primaryColor) as AppColors;

    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: appColors.cobaltAccent,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF),
      barBackgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF),
      textTheme: const CupertinoTextThemeData(),
    );
  }

  static Color dateInputFill(bool isDark) =>
      isDark ? const Color(0xFF18181B) : const Color(0xFFF9FAFB);

  /// Gets a harmonized category color (Desaturated)
  static Color getCategoryColor(BuildContext context, String categoryId) {
    // Return Cobalt for everything to maintain strict brand,
    // OR return very specific desaturated functional colors.
    // For now, sticking to the "Stark" theme:
    return context.colors.cobaltAccent;
  }
}
