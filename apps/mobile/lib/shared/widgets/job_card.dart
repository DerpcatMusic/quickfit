/// JobCard Widget - Platform-adaptive smart card.
library;

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/job.dart';
import 'sos_badge.dart';

/// Main job card with platform-specific "Native" rendering.
/// - Android: Material 3 Tonal Card
/// - iOS: Cupertino Glass Surface
class JobCard extends StatefulWidget {
  const JobCard({
    super.key,
    required this.job,
    this.onClaim,
    this.onDismiss,
    this.onTap,
    this.isLoading = false,
    this.pendingStatus, // 'pending' | 'syncing' | 'completed' | 'failed'
  });

  final Job job;
  final VoidCallback? onClaim;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;
  final bool isLoading;
  final String? pendingStatus;

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  double _dragOffset = 0;
  bool _isDragging = false;
  static const _claimThreshold = 100.0;

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Build status indicator based on pending status
  Widget _buildStatusIndicator(AppColors colors) {
    if (widget.pendingStatus == 'pending') {
      return Icon(
        LucideIcons.cloudOff,
        color: colors.urgentText,
        size: 32,
      );
    } else if (widget.pendingStatus == 'syncing') {
      return const CircularProgressIndicator.adaptive();
    } else if (widget.pendingStatus == 'completed') {
      return Icon(
        LucideIcons.checkCircle,
        color: colors.successText,
        size: 32,
      );
    } else if (widget.pendingStatus == 'failed') {
      return Icon(
        LucideIcons.xCircle,
        color: colors.urgentText,
        size: 32,
      );
    }
    return const CircularProgressIndicator.adaptive();
  }

  /// Build status text based on pending status
  Widget _buildStatusText(AppColors colors) {
    String text;
    Color color;

    switch (widget.pendingStatus) {
      case 'pending':
        text = 'Waiting for connection...';
        color = colors.urgentText;
        break;
      case 'syncing':
        text = 'Syncing...';
        color = colors.cobaltAccent;
        break;
      case 'completed':
        text = 'Synced!';
        color = colors.successText;
        break;
      case 'failed':
        text = 'Failed - will retry';
        color = colors.urgentText;
        break;
      default:
        text = 'Loading...';
        color = colors.cobaltAccent;
    }

    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-50, 150);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset > _claimThreshold && widget.onClaim != null) {
      HapticFeedback.mediumImpact();
      widget.onClaim!();
    }

    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final category = FitnessCategory.fromId(widget.job.category);
    final claimProgress = (_dragOffset / _claimThreshold).clamp(0.0, 1.0);

    return Stack(
      children: [
        // Claim indicator background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Color.lerp(
                colors.successBackground,
                colors.successBorder,
                claimProgress,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.successBorder),
            ),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsetsDirectional.only(start: 24),
            child: Row(
              children: [
                Icon(
                  claimProgress >= 1
                      ? LucideIcons.checkCircle2
                      : LucideIcons.arrowRight,
                  color: colors.successText,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  claimProgress >= 1 ? 'Release to Claim!' : 'Swipe to Claim',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.successText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Main card
        GestureDetector(
          onHorizontalDragUpdate:
              widget.isLoading ? null : _onHorizontalDragUpdate,
          onHorizontalDragEnd: widget.isLoading ? null : _onHorizontalDragEnd,
          onTap: widget.onTap,
          child: AnimatedValues(
            duration:
                _isDragging ? Duration.zero : const Duration(milliseconds: 200),
            offset: _dragOffset,
            child: _buildPlatformCard(context, isDark, category),
          ),
        ),

        // Loading / Pending overlay
        if (widget.isLoading || widget.pendingStatus != null)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colors.cardBackground.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusIndicator(colors),
                    const SizedBox(height: 12),
                    _buildStatusText(colors),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the platform-specific card container
  Widget _buildPlatformCard(
      BuildContext context, bool isDark, FitnessCategory? category) {
    final colors = context.colors;

    // CONTENT
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, category),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.job.studioName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                icon: _isIOS ? CupertinoIcons.calendar : LucideIcons.calendar,
                text: _formatDateTime(widget.job.startTime, widget.job.endTime),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                icon: _isIOS
                    ? CupertinoIcons.map_pin_ellipse
                    : LucideIcons.mapPin,
                text: widget.job.formattedDistance,
              ),
              if (widget.job.notes != null && widget.job.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  icon: _isIOS
                      ? CupertinoIcons.chat_bubble_2
                      : LucideIcons.messageSquare,
                  text: widget.job.notes!,
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
        _buildFooter(context),
      ],
    );

    if (_isIOS) {
      // iOS: Native Glass SDK (CupertinoPopupSurface)
      return CupertinoPopupSurface(
        isSurfacePainted: true, // Default glass
        child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.5),
            ),
            child: content),
      );
    } else {
      // Android: Material 3 Card
      return Container(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.job.isSos ? colors.urgentBorder : colors.cardBorder,
            width: widget.job.isSos ? 2 : 1,
          ),
        ),
        child: content,
      );
    }
  }

  Widget _buildHeader(BuildContext context, FitnessCategory? category) {
    final theme = Theme.of(context);
    final categoryColor = category?.color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // Solid top strip for category
        color: categoryColor.withValues(alpha: 0.1),
        borderRadius: _isIOS
            ? const BorderRadius.vertical(
                top: Radius.circular(0)) // PopupSurface handles radius
            : const BorderRadius.vertical(top: Radius.circular(11)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(category?.emoji ?? '🏃',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  category?.nameEn ?? widget.job.category,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          TimeRemainingBadge(timeRemaining: widget.job.timeUntilStart),
          if (widget.job.isSos) ...[
            const SizedBox(width: 8),
            const SosBadge(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String text,
    int maxLines = 1,
  }) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colors.mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.mutedText,
              fontWeight: FontWeight.w500,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isIOS
            ? CupertinoColors.systemFill.resolveFrom(context)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: _isIOS
            ? BorderRadius.zero
            : const BorderRadius.vertical(bottom: Radius.circular(11)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Posted ${timeago.format(widget.job.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedText),
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.job.isBoosted)
                    BoostedRateBadge(
                      originalRate: widget.job.baseRate.toInt(),
                      boostedRate: widget.job.currentRate.toInt(),
                    ),
                  Text(
                    widget.job.formattedRate,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800, // Uber Bold
                      color: theme.colorScheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              if (_isIOS)
                CupertinoButton.filled(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  minimumSize: Size.zero,
                  onPressed: widget.onClaim,
                  child: const Text('Claim',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                )
              else
                FilledButton(
                  onPressed: widget.onClaim,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: const Text('CLAIM'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime start, DateTime end) {
    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('HH:mm');
    return '${dateFormat.format(start)} • ${timeFormat.format(start)} - ${timeFormat.format(end)}';
  }
}

// Wrapper to animate translation
class AnimatedValues extends StatelessWidget {
  const AnimatedValues(
      {super.key,
      required this.child,
      required this.duration,
      required this.offset});
  final Widget child;
  final Duration duration;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      transform: Matrix4.translationValues(offset, 0, 0),
      child: child,
    );
  }
}

/// Compact job card for lists.
class JobCardCompact extends StatelessWidget {
  const JobCardCompact({
    super.key,
    required this.job,
    this.onTap,
  });

  final Job job;
  final VoidCallback? onTap;

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final category = FitnessCategory.fromId(job.category);
    final categoryColor = category?.color ?? theme.colorScheme.primary;

    final content = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(category?.emoji ?? '🏃',
                style: const TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.studioName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (job.isSos) ...[
                    const SizedBox(width: 6),
                    const SosBadge()
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('HH:mm').format(job.startTime)} • ${job.formattedDistance}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.mutedText),
              ),
            ],
          ),
        ),
        Text(
          job.formattedRate,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: _isIOS
          ? CupertinoPopupSurface(
              child: Padding(padding: const EdgeInsets.all(12), child: content),
            )
          : Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.cardBorder),
              ),
              child: content,
            ),
    );
  }
}
