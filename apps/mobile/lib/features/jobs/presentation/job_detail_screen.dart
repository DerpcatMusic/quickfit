// Job Detail Screen - Shared view for studios and instructors
// lib/features/jobs/presentation/job_detail_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/convex_service.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import '../providers/jobs_provider.dart';
import 'package:quickfit/shared/widgets/adaptive_app_bar.dart';
import 'package:quickfit/shared/widgets/adaptive_dialog.dart' as qf_dialog;
import 'package:quickfit/core/utils/platform.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  // 2026 STABILIZATION: Removed _loadJobDetails as we use reactive providers

  Future<void> _claimJob() async {
    final success =
        await ref.read(jobsProvider.notifier).claimJob(widget.jobId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim request queued!')),
      );
    }
  }

  Future<void> _withdrawClaim() async {
    final success =
        await ref.read(jobsProvider.notifier).withdrawClaim(widget.jobId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal request queued.')),
      );
    }
  }

  Future<void> _handleRespondToClaim(bool accept, String? claimId) async {
    if (claimId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active claim found.')),
      );
      return;
    }

    try {
      await ConvexService.instance.respondToClaim(
        claimId: claimId,
        accept: accept,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(accept ? 'Claim accepted!' : 'Claim rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  Future<void> _handleCancelJob() async {
    try {
      await ConvexService.instance.cancelJob(widget.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job cancelled.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final authState = ref.watch(authProvider);
    final isStudio = authState.role == 'studio';
    final isCupertino = isCupertinoPlatform(context);

    // 2026 STABILIZATION: Ensure provider name matches generated riverpod code
    final streamingJob = ref.watch(streamingJobProvider(widget.jobId));

    return streamingJob.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: adaptiveAppBar(context, title: 'Job Details'),
        body: Center(child: Text('Error: $err')),
      ),
      data: (job) {
        if (job == null) {
          return Scaffold(
            appBar: adaptiveAppBar(context, title: 'Job Details'),
            body: const Center(child: Text('Job not found')),
          );
        }

        final status = job['status'] as String;
        final isSos = job['sosBoostApplied'] as bool? ?? false;
        final startTime = job['startTime'] as num;
        final endTime = job['endTime'] as num;
        final startDate =
            DateTime.fromMillisecondsSinceEpoch(startTime.toInt());
        final endDate = DateTime.fromMillisecondsSinceEpoch(endTime.toInt());
        final duration = job['durationMinutes'] as int? ??
            endDate.difference(startDate).inMinutes;
        final rate = (job['currentRate'] as num?)?.toDouble() ??
            (job['baseRate'] as num?)?.toDouble() ??
            0.0;

        // Pending state for optimistic feedback
        final jobsState = ref.watch(jobsProvider);
        final isPending = jobsState.isJobPending(widget.jobId);

        // Metadata for actions
        final userRole = job['userRole'] as String? ?? 'viewer';
        final canClaimAsPrimary = job['canClaimAsPrimary'] as bool? ?? false;
        final canClaimAsBackup = job['canClaimAsBackup'] as bool? ?? false;
        final claimId = job['claimId'] as String?;

        return Scaffold(
          appBar: adaptiveAppBar(
            context,
            title: 'Job Details',
            actions: [
              if (isStudio &&
                  (status == 'open' ||
                      status == 'claimed' ||
                      status == 'backup_claimed'))
                IconButton(
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: () => _confirmCancel(context),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge & SOS
                Row(
                  children: [
                    _buildStatusBadge(status),
                    if (isSos) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.urgentBackground,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.urgentBorder),
                        ),
                        child: Text(
                          'SOS BOOST',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.urgentText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  job['title'] ?? 'Fitness Class',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  job['studioName'] ?? 'Studio',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: colors.mutedText),
                ),
                const Divider(height: 48),

                // Details Grid
                _buildDetailRow(LucideIcons.calendar, 'Date',
                    DateFormat('EEEE, MMM d, yyyy').format(startDate)),
                const SizedBox(height: 16),
                _buildDetailRow(LucideIcons.clock, 'Time',
                    '${DateFormat.Hm().format(startDate)} ($duration min)'),
                const SizedBox(height: 16),
                _buildDetailRow(
                    LucideIcons.mapPin, 'Location', job['address'] ?? 'Israel'),
                const SizedBox(height: 16),
                _buildDetailRow(
                  LucideIcons.banknote,
                  'Rate',
                  'ILS ${rate.toStringAsFixed(0)}',
                  valueColor: colors.successText,
                ),
                const Divider(height: 48),

                // Description / Notes
                Text('Requirements & Notes',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                    job['description'] ??
                        job['notes'] ??
                        'No special requirements listed.',
                    style: theme.textTheme.bodyLarge),

                // Instructor Actions
                if (!isStudio) ...[
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: isCupertino
                        ? CupertinoButton.filled(
                            onPressed: (isPending ||
                                    (!canClaimAsPrimary && !canClaimAsBackup))
                                ? null
                                : _claimJob,
                            child: isPending
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(canClaimAsBackup
                                    ? 'Claim as Backup'
                                    : 'Claim this Job'),
                          )
                        : FilledButton(
                            onPressed: (isPending ||
                                    (!canClaimAsPrimary && !canClaimAsBackup))
                                ? null
                                : _claimJob,
                            child: isPending
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text(canClaimAsBackup
                                    ? 'Claim as Backup'
                                    : 'Claim this Job'),
                          ),
                  ),
                  if (canClaimAsBackup) ...[
                    const SizedBox(height: 12),
                    Center(
                        child: Text(
                            'This job is claimed, but you can join as a backup.',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: colors.mutedText))),
                  ],
                ],

                // Studio Management
                if (isStudio &&
                    (status == 'claimed' || status == 'backup_claimed') &&
                    job['claimedInstructor'] != null) ...[
                  const Divider(height: 48),
                  Text('Claimed By',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildInstructorCard(theme, colors, job['claimedInstructor']),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: isCupertino
                            ? CupertinoButton(
                                onPressed: () =>
                                    _handleRespondToClaim(false, claimId),
                                color: CupertinoColors.systemGrey5,
                                child: Text(
                                  'Reject Claim',
                                  style: TextStyle(
                                      color: theme.colorScheme.error),
                                ),
                              )
                            : OutlinedButton(
                                onPressed: () =>
                                    _handleRespondToClaim(false, claimId),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.colorScheme.error),
                                child: const Text('Reject Claim'),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: isCupertino
                            ? CupertinoButton.filled(
                                onPressed: () =>
                                    _handleRespondToClaim(true, claimId),
                                child: const Text('Accept Claim'),
                              )
                            : FilledButton(
                                onPressed: () =>
                                    _handleRespondToClaim(true, claimId),
                                child: const Text('Accept Claim'),
                              ),
                      ),
                    ],
                  ),
                ],

                // Withdraw/Cancel Role Specific
                if (!isStudio &&
                    (userRole == 'primary' || userRole == 'backup')) ...[
                  const SizedBox(height: 48),
                  Center(
                    child: Text(
                      userRole == 'primary'
                          ? 'You are the primary instructor.'
                          : 'You are an assigned backup.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: userRole == 'primary'
                            ? colors.successText
                            : colors.urgentText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: isCupertino
                        ? CupertinoButton(
                            onPressed: isPending ? null : _withdrawClaim,
                            color: CupertinoColors.systemGrey5,
                            child: isPending
                                ? const Text('Processing...')
                                : const Text('Cancel Claim'),
                          )
                        : OutlinedButton(
                            onPressed: isPending ? null : _withdrawClaim,
                            child: isPending
                                ? const Text('Processing...')
                                : const Text('Cancel Claim'),
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'open':
        color = Colors.blue;
        break;
      case 'claimed':
        color = Colors.orange;
        break;
      case 'backup_claimed':
        color = Colors.deepOrange;
        break;
      case 'confirmed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(status.replaceFirst('_', ' ').toUpperCase(),
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.grey[600])),
            Text(value,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600, color: valueColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildInstructorCard(
      ThemeData theme, AppColors colors, Map<String, dynamic> instructor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: instructor['photoUrl'] != null
                ? NetworkImage(instructor['photoUrl'])
                : null,
            child: instructor['photoUrl'] == null
                ? const Icon(LucideIcons.user)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(instructor['name'] ?? 'Unknown',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (instructor['isVerified'] == true)
                  Row(
                    children: [
                      Icon(LucideIcons.badgeCheck,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text('Verified Professional',
                          style: theme.textTheme.labelSmall),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    final isCupertino = isCupertinoPlatform(context);
    qf_dialog.showAdaptiveDialog<void>(
      context,
      title: const Text('Cancel Job?'),
      content: const Text(
        'Are you sure you want to cancel this job? This cannot be undone.',
      ),
      actions: isCupertino
          ? [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep It'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(context);
                  _handleCancelJob();
                },
                isDestructiveAction: true,
                child: const Text('Cancel Job'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep it'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleCancelJob();
                },
                child: const Text(
                  'Cancel Job',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
    );
  }
}
