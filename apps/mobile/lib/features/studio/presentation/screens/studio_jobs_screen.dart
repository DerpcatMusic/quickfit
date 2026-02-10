// Studio Jobs Screen - Shows studio's posted jobs
// lib/features/studio/presentation/screens/studio_jobs_screen.dart

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import 'package:quickfit/core/router/app_router.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/shared/widgets/adaptive_app_bar.dart';
import 'package:quickfit/shared/widgets/adaptive_dialog.dart' as qf_dialog;
import 'package:quickfit/core/utils/platform.dart';

/// Screen displaying all jobs posted by the current studio.
class StudioJobsScreen extends ConsumerStatefulWidget {
  const StudioJobsScreen({super.key});

  @override
  ConsumerState<StudioJobsScreen> createState() => _StudioJobsScreenState();
}

class _StudioJobsScreenState extends ConsumerState<StudioJobsScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result =
          await ConvexClient.instance.query('jobs:getStudioJobs', {});

      if (result.isNotEmpty && result != 'null') {
        final data = json.decode(result) as List;
        if (mounted) {
          setState(() {
            _jobs = data.cast<Map<String, dynamic>>();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _jobs = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load jobs: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _respondToClaim(String claimId, bool accept) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:respondToClaim',
        args: {'claimId': claimId, 'accept': accept},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Claim accepted!' : 'Claim rejected'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadJobs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _cancelJob(String jobId) async {
    final isCupertino = isCupertinoPlatform(context);
    final confirm = await qf_dialog.showAdaptiveDialog<bool>(
      context,
      title: const Text('Cancel Job?'),
      content: const Text('This action cannot be undone.'),
      actions: isCupertino
          ? [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, true),
                isDestructiveAction: true,
                child: const Text('Yes, Cancel'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Cancel'),
              ),
            ],
    );

    if (confirm != true) return;

    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:cancelJob',
        args: {'jobId': jobId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job cancelled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadJobs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final isCupertino = isCupertinoPlatform(context);

    return Scaffold(
      appBar: adaptiveAppBar(
        context,
        title: 'My Jobs',
        actions: [
          if (isCupertino)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadJobs,
              child: const Icon(CupertinoIcons.refresh),
            )
          else
            IconButton(
              onPressed: _loadJobs,
              icon: const Icon(LucideIcons.refreshCw),
              tooltip: 'Refresh',
            ),
          if (isCupertino)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.go(AppRoutes.studioPostJob),
              child: const Icon(CupertinoIcons.add),
            ),
        ],
      ),
      floatingActionButton: isCupertino
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.studioPostJob),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Post Job'),
            ),
      body: _buildBody(theme, colors),
    );
  }

  Widget _buildBody(ThemeData theme, AppColors colors) {
    final isCupertino = isCupertinoPlatform(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            isCupertino
                ? CupertinoButton.filled(
                    onPressed: _loadJobs,
                    child: const Text('Retry'),
                  )
                : FilledButton(onPressed: _loadJobs, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.briefcase,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text(
              'No jobs posted yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Post a job to find instructors',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            isCupertino
                ? CupertinoButton.filled(
                    onPressed: () => context.go(AppRoutes.studioPostJob),
                    child: const Text('Post Your First Job'),
                  )
                : FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.studioPostJob),
                    icon: const Icon(LucideIcons.plus),
                    label: const Text('Post Your First Job'),
                  ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJobs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          final job = _jobs[index];
          return _JobCard(
            job: job,
            colors: colors,
            onAccept: () {
              final claimId = job['claimId'] as String?;
              if (claimId != null) _respondToClaim(claimId, true);
            },
            onReject: () {
              final claimId = job['claimId'] as String?;
              if (claimId != null) _respondToClaim(claimId, false);
            },
            onCancel: () => _cancelJob(job['_id'] as String),
            onTap: () => context
                .push(AppRoutes.jobDetail.replaceFirst(':id', job['_id'])),
          );
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.colors,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    required this.onTap,
  });

  final Map<String, dynamic> job;
  final AppColors colors;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final status = job['status'] as String? ?? 'open';
    final title = job['title'] as String? ?? 'Untitled';
    final category = job['category'] as String? ?? '';
    final startTime = job['startTime'] as num?;
    final currentRate = (job['currentRate'] as num?)?.toDouble() ?? 0;
    final sosBoost = job['sosBoostApplied'] as bool? ?? false;
    final claimedInstructor = job['claimedInstructor'] as Map<String, dynamic>?;

    final statusColor = _getStatusColor(status, theme);
    final statusLabel = _getStatusLabel(status);

    final dateStr = startTime != null
        ? DateFormat('EEE, MMM d • HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(startTime.toInt()))
        : 'No date';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          if (status == 'open' || status == 'claimed') {
            onCancel();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: ShapeDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: statusColor.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date & Category
              Row(
                children: [
                  Icon(LucideIcons.calendar,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(dateStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Rate
              Row(
                children: [
                  Text('ILS ${currentRate.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  if (sosBoost) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.urgentBorder,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.zap,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'SOS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // Claimed instructor info
              if (claimedInstructor != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          (claimedInstructor['name'] as String?)
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              'I',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              claimedInstructor['name'] as String? ??
                                  'Instructor',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (claimedInstructor['isVerified'] == true)
                              Row(
                                children: [
                                  Icon(LucideIcons.badgeCheck,
                                      size: 14,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text('Verified',
                                      style: theme.textTheme.labelSmall),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (status == 'claimed')
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.check),
                              color: Colors.green,
                              onPressed: onAccept,
                              tooltip: 'Accept',
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.x),
                              color: theme.colorScheme.error,
                              onPressed: onReject,
                              tooltip: 'Reject',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'open':
        return Colors.blue;
      case 'claimed':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.outline;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'claimed':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }
}
