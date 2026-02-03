import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A platform-adaptive surface that uses Glass Morphism (Blur) on iOS
/// and Solid/Tonal opacity on Android (Material Expressive).
class GlassPane extends StatelessWidget {
  const GlassPane({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding,
    this.margin,
    this.blurAmount = 10.0,
    this.androidOpacity = 1.0,
    this.iosOpacity = 0.7,
    this.border,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blurAmount;

  /// Opacity for Android (Solid/Tonal look)
  final double androidOpacity;

  /// Opacity for iOS (Glass look)
  final double iosOpacity;

  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    // On Web, we often want the Glass look if it simulates "desktop/app" feel,
    // but for now let's stick to platform rules.

    final appColors = theme.extension<AppColors>();
    final bgColor = theme.colorScheme.surfaceContainer;
    final effectiveBorder = border ??
        Border.all(
            color: appColors?.cardBorder ?? Colors.grey.withValues(alpha: 0.2));

    if (isIOS) {
      // iOS: Backdrop Filter Glass
      return Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: iosOpacity),
                borderRadius: borderRadius,
                border: effectiveBorder,
              ),
              child: child,
            ),
          ),
        ),
      );
    } else {
      // Android: Solid/Tonal (Material Expressive)
      // We use a solid container (maybe with slight transparency if androidOpacity < 1)
      // but generally Material 3 prefers solid surfaces with tonal elevation.
      return Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          // If androidOpacity is 1.0, it's solid. If less, it's transparent solid.
          color: androidOpacity < 1.0
              ? bgColor.withValues(alpha: androidOpacity)
              : bgColor,
          borderRadius: borderRadius,
          border: effectiveBorder,
        ),
        child: child,
      );
    }
  }
}
