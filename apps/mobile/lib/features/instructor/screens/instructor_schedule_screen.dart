// Instructor Schedule Screen - Shows confirmed jobs calendar
// lib/features/instructor/screens/instructor_schedule_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import 'package:quickfit/core/theme/app_colors.dart';

/// Instructor's schedule showing confirmed jobs.
class InstructorScheduleScreen extends ConsumerStatefulWidget {
  const InstructorScheduleScreen({super.key});

  @override
  ConsumerState<InstructorScheduleScreen> createState() =>
      _InstructorScheduleScreenState();
}

class _InstructorScheduleScreenState
    extends ConsumerState<InstructorScheduleScreen> {
  List<Map<String, dynamic>> _confirmedJobs = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);

    try {
      final result =
          await ConvexClient.instance.query('jobs:getInstructorSchedule', {});

      if (result.isNotEmpty && result != 'null') {
        final data = json.decode(result) as List;
        if (mounted) {
          setState(() {
            _confirmedJobs = data.cast<Map<String, dynamic>>();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _confirmedJobs = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _jobsForSelectedDate {
    return _confirmedJobs.where((job) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          IconButton(
            onPressed: _loadSchedule,
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekStrip(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildJobsList(theme, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(ThemeData theme) {
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

            final jobCount = _confirmedJobs.where((job) {
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

  Widget _buildJobsList(ThemeData theme, AppColors colors) {
    final jobs = _jobsForSelectedDate;

    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.calendarOff,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No classes scheduled',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              DateFormat.yMMMMd().format(_selectedDate),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.mutedText,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return _ScheduleCard(job: job, colors: colors);
      },
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.job, required this.colors});

  final Map<String, dynamic> job;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final startTime = job['startTime'] as num?;
    final durationMinutes = (job['durationMinutes'] as num?)?.toInt() ?? 60;
    final title = job['title'] as String? ?? 'Class';
    final studioName = job['studioName'] as String? ?? 'Studio';
    final address = job['address'] as String? ?? '';
    final rate = (job['currentRate'] as num?)?.toDouble() ?? 0;

    final startDateTime = startTime != null
        ? DateTime.fromMillisecondsSinceEpoch(startTime.toInt())
        : DateTime.now();
    final endDateTime = startDateTime.add(Duration(minutes: durationMinutes));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time column
            Column(
              children: [
                Text(
                  DateFormat.Hm().format(startDateTime),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  width: 2,
                  height: 24,
                  color: theme.colorScheme.primary,
                ),
                Text(
                  DateFormat.Hm().format(endDateTime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.mutedText,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Details column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(LucideIcons.building2,
                          size: 14, color: colors.mutedText),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          studioName,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(LucideIcons.mapPin,
                            size: 14, color: colors.mutedText),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.mutedText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Rate
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.successBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '₪${rate.toStringAsFixed(0)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.successText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
