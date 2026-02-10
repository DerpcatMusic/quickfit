// Instructor Schedule Screen - Shows confirmed jobs calendar
// lib/features/instructor/screens/instructor_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/shared/widgets/adaptive_app_bar.dart';
import '../widgets/schedule_timeline.dart';
import '../providers/schedule_provider.dart';

/// Instructor's schedule showing confirmed jobs.
class InstructorScheduleScreen extends ConsumerStatefulWidget {
  const InstructorScheduleScreen({super.key});

  @override
  ConsumerState<InstructorScheduleScreen> createState() =>
      _InstructorScheduleScreenState();
}

class _InstructorScheduleScreenState
    extends ConsumerState<InstructorScheduleScreen> {
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _getJobsForSelectedDate(
      List<Map<String, dynamic>> allJobs) {
    return allJobs.where((job) {
      final startTime = job['startTime'] as num?;
      if (startTime == null) return false;
      final jobDate = DateTime.fromMillisecondsSinceEpoch(startTime.toInt());
      return jobDate.year == _selectedDate.year &&
          jobDate.month == _selectedDate.month &&
          jobDate.day == _selectedDate.day;
    }).toList()
      ..sort((a, b) {
        final aTime = a['startTime'] as num? ?? 0;
        final bTime = b['startTime'] as num? ?? 0;
        return aTime.compareTo(bTime);
      });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    final scheduleState = ref.watch(scheduleProvider);
    final jobs = _getJobsForSelectedDate(scheduleState.jobs);

    return Scaffold(
      appBar: adaptiveAppBar(
        context,
        title: 'My Schedule',
        actions: [
          if (scheduleState.isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: () => ref.read(scheduleProvider.notifier).refresh(),
              icon: const Icon(LucideIcons.refreshCw),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekStrip(theme, scheduleState.jobs),
          Expanded(
            child: jobs.isEmpty && !scheduleState.isLoading
                ? Center(
                    child: Text(
                      'No jobs for this day',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.mutedText,
                      ),
                    ),
                  )
                : _buildJobsList(theme, colors, jobs),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(ThemeData theme, List<Map<String, dynamic>> allJobs) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(7, (index) {
            final day = startOfWeek.add(Duration(days: index));
            final isSelected = day.day == _selectedDate.day &&
                day.month == _selectedDate.month &&
                day.year == _selectedDate.year;
            final isToday = day.day == now.day &&
                day.month == now.month &&
                day.year == now.year;

            final jobCount = allJobs.where((job) {
              final startTime = job['startTime'] as num?;
              if (startTime == null) return false;
              final jobDate =
                  DateTime.fromMillisecondsSinceEpoch(startTime.toInt());
              return jobDate.day == day.day &&
                  jobDate.month == day.month &&
                  jobDate.year == day.year;
            }).length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => setState(() => _selectedDate = day),
                child: Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : isToday
                            ? theme.colorScheme.primaryContainer
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat.E().format(day).substring(0, 2),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${day.day}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (jobCount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildJobsList(
      ThemeData theme, AppColors colors, List<Map<String, dynamic>> jobs) {
    return ScheduleTimeline(
      selectedDate: _selectedDate,
      jobs: jobs,
      onJobTap: (jobId) {
        // Handle job tap
      },
    );
  }
}
