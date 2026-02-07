import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ScheduleTimeline extends StatelessWidget {
  const ScheduleTimeline({
    super.key,
    required this.selectedDate,
    required this.jobs,
    required this.onJobTap,
  });

  final DateTime selectedDate;
  final List<Map<String, dynamic>> jobs;
  final Function(String jobId) onJobTap;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return _buildEmptyState(context);
    }

    // Determine platform style
    final isIOS = !kIsWeb && Platform.isIOS;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Stack(
        children: [
          // Background Time Grid
          Column(
            children: List.generate(18, (index) {
              final hour = index + 6; // Start from 6 AM
              return _buildTimeSlot(context, hour);
            }),
          ),

          // Job Cards Overlay
          ...jobs.map((job) {
            return _buildJobCard(context, job, isIOS);
          }),

          // Current Time Indicator (if today)
          if (_isToday(selectedDate)) _buildCurrentTimeIndicator(context),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildTimeSlot(BuildContext context, int hour) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Container(
      height: 80, // Height per hour
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.cardBorder.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$hour:00',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.mutedText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(
      BuildContext context, Map<String, dynamic> job, bool isIOS) {
    final startTime = job['startTime'] as num?;
    if (startTime == null) return const SizedBox.shrink();

    final startDateTime =
        DateTime.fromMillisecondsSinceEpoch(startTime.toInt());
    final durationMinutes = (job['durationMinutes'] as num?)?.toInt() ?? 60;

    // Calculate positioning
    // 6 AM is 0 offset. Each hour is 80px.
    final startHour = startDateTime.hour;
    final startMinute = startDateTime.minute;

    if (startHour < 6) {
      return const SizedBox.shrink(); // Skip jobs before 6 AM for now
    }

    final topOffset = ((startHour - 6) * 80.0) + ((startMinute / 60) * 80.0);
    final height = (durationMinutes / 60) * 80.0;

    return Positioned(
      top: topOffset,
      left: 70, // After time label
      right: 16,
      height: height - 4, // Slight gap
      child: GestureDetector(
        onTap: () => onJobTap(job['id']),
        child: isIOS
            ? _buildIOSCard(context, job)
            : _buildAndroidCard(context, job),
      ),
    );
  }

  Widget _buildIOSCard(BuildContext context, Map<String, dynamic> job) {
    final theme = Theme.of(context);
    final title = job['title'] as String? ?? 'Class';
    final studioName = job['studioName'] as String? ?? 'Studio';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  studioName,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAndroidCard(BuildContext context, Map<String, dynamic> job) {
    final theme = Theme.of(context);
    final title = job['title'] as String? ?? 'Class';
    final studioName = job['studioName'] as String? ?? 'Studio';

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              studioName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer
                    .withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(BuildContext context) {
    final now = DateTime.now();
    if (now.hour < 6) return const SizedBox.shrink();

    final topOffset = ((now.hour - 6) * 80.0) + ((now.minute / 60) * 80.0);

    return Positioned(
      top: topOffset,
      left: 60,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Use a fun visual here in the future
          Icon(Icons.calendar_today_outlined,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No classes scheduled',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Take a break or find a new gig!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
