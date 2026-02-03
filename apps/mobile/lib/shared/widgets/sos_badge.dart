/// SOS Badge Widget - Urgent job indicator with solid Material design.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';

/// Badge indicating an urgent/SOS job.
class SosBadge extends StatelessWidget {
  const SosBadge({
    super.key,
    this.large = false,
    this.animate = true,
  });

  final bool large;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: colors.urgentBackground,
        border: Border.all(color: colors.urgentBorder),
        borderRadius: BorderRadius.circular(large ? 8 : 6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt,
            size: large ? 16 : 12,
            color: colors.urgentText,
          ),
          SizedBox(width: large ? 4 : 2),
          Text(
            'SOS',
            style: TextStyle(
              color: colors.urgentText,
              fontSize: large ? 14 : 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

    if (animate) {
      badge = badge
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.05, 1.05),
            duration: 800.ms,
            curve: Curves.easeInOut,
          );
    }

    return badge;
  }
}

/// Badge showing time remaining until job starts.
class TimeRemainingBadge extends StatelessWidget {
  const TimeRemainingBadge({
    super.key,
    required this.timeRemaining,
  });

  final Duration timeRemaining;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final hours = timeRemaining.inHours;
    final minutes = timeRemaining.inMinutes % 60;

    String text;
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (timeRemaining.isNegative) {
      text = 'Started';
      bgColor = colors.cardBorder;
      borderColor = colors.cardBorder;
      textColor = colors.mutedText;
    } else if (hours < 1) {
      // Urgent - less than 1 hour
      text = '${minutes}m';
      bgColor = colors.urgentBackground;
      borderColor = colors.urgentBorder;
      textColor = colors.urgentText;
    } else if (hours < 3) {
      // Warning - less than 3 hours
      text = '${hours}h ${minutes}m';
      bgColor = theme.colorScheme.tertiaryContainer;
      borderColor = theme.colorScheme.tertiary;
      textColor = theme.colorScheme.onTertiaryContainer;
    } else {
      // OK - more than 3 hours
      text = '${hours}h';
      bgColor = colors.successBackground;
      borderColor = colors.successBorder;
      textColor = colors.successText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Badge showing the boost percentage for SOS jobs.
class BoostedRateBadge extends StatelessWidget {
  const BoostedRateBadge({
    super.key,
    required this.originalRate,
    required this.boostedRate,
  });

  final int originalRate;
  final int boostedRate;

  @override
  Widget build(BuildContext context) {
    if (boostedRate <= originalRate) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final theme = Theme.of(context);
    final boostPercent =
        ((boostedRate - originalRate) / originalRate * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.successBackground,
        border: Border.all(color: colors.successBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_up,
            size: 12,
            color: colors.successText,
          ),
          const SizedBox(width: 2),
          Text(
            '+$boostPercent%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.successText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
