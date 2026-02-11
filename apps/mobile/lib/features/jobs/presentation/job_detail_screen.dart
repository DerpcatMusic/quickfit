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
import 'package:quickfit/l10n/app_localizations.dart';

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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.jobDetailClaimQueued)),
      );
    }
  }

  Future<void> _withdrawClaim() async {
    final success =
        await ref.read(jobsProvider.notifier).withdrawClaim(widget.jobId);
    if (success && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.jobDetailWithdrawalQueued)),
      );
    }
  }

  Future<void> _handleRespondToClaim(bool accept, String? claimId) async {
    final l10n = AppLocalizations.of(context)!;
    if (claimId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.jobDetailNoActiveClaim)),
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
          SnackBar(content: Text(accept
              ? l10n.studioJobsClaimAccepted
              : l10n.jobDetailClaimRejected)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.jobDetailActionFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _handleCancelJob() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ConvexService.instance.cancelJob(widget.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.jobDetailCancelled)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.jobDetailCancelFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _handleCompleteJob() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ConvexService.instance.completeJob(widget.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.jobDetailCompleteSuccessSnack)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.jobDetailCompleteFailureSnack(e.toString()))),
        );
      }
    }
  }

  Future<void> _handleSubmitRating({
    required String toUserId,
    required String targetLabel,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final commentController = TextEditingController();
    double selectedRating = 5;

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(l10n.jobDetailRateDialogTitle(targetLabel)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.jobDetailRatePrompt,
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: selectedRating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: selectedRating.toStringAsFixed(0),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRating = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: l10n.jobDetailRateCommentHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.submit),
                ),
              ],
            );
          },
        );
      },
    );

    if (submit != true) {
      commentController.dispose();
      return;
    }

    try {
      await ConvexService.instance.submitRating(
        jobId: widget.jobId,
        toUserId: toUserId,
        rating: selectedRating,
        comment: commentController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.jobDetailRatingSubmittedSnack)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.jobDetailRatingFailedSnack(e.toString()))),
        );
      }
    } finally {
      commentController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        appBar: adaptiveAppBar(context, title: l10n.jobDetailTitle),
        body: Center(child: Text(l10n.mapErrorWithMessage(err.toString()))),
      ),
      data: (job) {
        if (job == null) {
          return Scaffold(
            appBar: adaptiveAppBar(context, title: l10n.jobDetailTitle),
            body: Center(child: Text(l10n.jobDetailNotFound)),
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
            title: l10n.jobDetailTitle,
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
                          l10n.jobDetailSosBoost,
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
                  job['title'] ?? l10n.jobDetailDefaultTitle,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  job['studioName'] ?? l10n.jobDetailDefaultStudio,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: colors.mutedText),
                ),
                const Divider(height: 48),

                // Details Grid
                _buildDetailRow(LucideIcons.calendar, l10n.jobDetailDate,
                    DateFormat('EEEE, MMM d, yyyy').format(startDate)),
                const SizedBox(height: 16),
                _buildDetailRow(LucideIcons.clock, l10n.jobDetailTime,
                    '${DateFormat.Hm().format(startDate)} ($duration min)'),
                const SizedBox(height: 16),
                _buildDetailRow(
                    LucideIcons.mapPin,
                    l10n.jobDetailLocation,
                    job['address'] ?? l10n.jobDetailDefaultLocation),
                const SizedBox(height: 16),
                _buildDetailRow(
                  LucideIcons.banknote,
                  l10n.jobDetailRate,
                  l10n.studioJobsRate(rate.toStringAsFixed(0)),
                  valueColor: colors.successText,
                ),
                const Divider(height: 48),

                // Description / Notes
                Text(l10n.jobDetailRequirements,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                    job['description'] ??
                        job['notes'] ??
                        l10n.jobDetailNoRequirements,
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
                                    ? l10n.jobDetailClaimBackup
                                    : l10n.jobDetailClaimPrimary),
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
                                    ? l10n.jobDetailClaimBackup
                                    : l10n.jobDetailClaimPrimary),
                          ),
                  ),
                  if (canClaimAsBackup) ...[
                    const SizedBox(height: 12),
                    Center(
                        child: Text(
                            l10n.jobDetailBackupHint,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: colors.mutedText))),
                  ],
                ],

                // Studio Management
                if (isStudio &&
                    (status == 'claimed' || status == 'backup_claimed') &&
                    job['claimedInstructor'] != null) ...[
                  const Divider(height: 48),
                  Text(l10n.jobDetailClaimedBy,
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
                                  l10n.jobDetailRejectClaim,
                                  style: TextStyle(
                                      color: theme.colorScheme.error),
                                ),
                              )
                            : OutlinedButton(
                                onPressed: () =>
                                    _handleRespondToClaim(false, claimId),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.colorScheme.error),
                                child: Text(l10n.jobDetailRejectClaim),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: isCupertino
                            ? CupertinoButton.filled(
                                onPressed: () =>
                                    _handleRespondToClaim(true, claimId),
                                child: Text(l10n.jobDetailAcceptClaim),
                              )
                            : FilledButton(
                                onPressed: () =>
                                    _handleRespondToClaim(true, claimId),
                                child: Text(l10n.jobDetailAcceptClaim),
                              ),
                      ),
                    ],
                  ),
                ],

                if (isStudio && status == 'confirmed') ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: isCupertino
                        ? CupertinoButton.filled(
                            onPressed: _handleCompleteJob,
                            child: Text(l10n.studioJobsCompleteConfirmAction),
                          )
                        : FilledButton.icon(
                            onPressed: _handleCompleteJob,
                            icon: const Icon(LucideIcons.checkCircle2),
                            label: Text(l10n.studioJobsCompleteConfirmAction),
                          ),
                  ),
                ],

                if (status == 'completed' &&
                    ((isStudio && (job['claimedBy'] as String?) != null) ||
                        (!isStudio && userRole == 'primary'))) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: isCupertino
                        ? CupertinoButton.filled(
                            onPressed: () {
                              final toUserId = isStudio
                                  ? (job['claimedBy'] as String?)
                                  : (job['studioId'] as String?);
                              if (toUserId == null) return;
                              _handleSubmitRating(
                                toUserId: toUserId,
                                targetLabel: isStudio
                                    ? l10n.jobDetailRateTargetInstructor
                                    : l10n.jobDetailRateTargetStudio,
                              );
                            },
                            child: Text(l10n.jobDetailRateCounterpartCta),
                          )
                        : FilledButton.icon(
                            onPressed: () {
                              final toUserId = isStudio
                                  ? (job['claimedBy'] as String?)
                                  : (job['studioId'] as String?);
                              if (toUserId == null) return;
                              _handleSubmitRating(
                                toUserId: toUserId,
                                targetLabel: isStudio
                                    ? l10n.jobDetailRateTargetInstructor
                                    : l10n.jobDetailRateTargetStudio,
                              );
                            },
                            icon: const Icon(LucideIcons.star),
                            label: Text(l10n.jobDetailRateCounterpartCta),
                          ),
                  ),
                ],

                // Withdraw/Cancel Role Specific
                if (!isStudio &&
                    (userRole == 'primary' || userRole == 'backup')) ...[
                  const SizedBox(height: 48),
                  Center(
                    child: Text(
                      userRole == 'primary'
                          ? l10n.jobDetailPrimaryRole
                          : l10n.jobDetailBackupRole,
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
                                ? Text(l10n.jobDetailProcessing)
                                : Text(l10n.jobDetailCancelClaim),
                          )
                        : OutlinedButton(
                            onPressed: isPending ? null : _withdrawClaim,
                            child: isPending
                                ? Text(l10n.jobDetailProcessing)
                                : Text(l10n.jobDetailCancelClaim),
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
                Text(instructor['name'] ?? AppLocalizations.of(context)!.jobDetailUnknown,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (instructor['isVerified'] == true)
                  Row(
                    children: [
                      Icon(LucideIcons.badgeCheck,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(AppLocalizations.of(context)!.jobDetailVerifiedProfessional,
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
    final l10n = AppLocalizations.of(context)!;
    final isCupertino = isCupertinoPlatform(context);
    qf_dialog.showAdaptiveDialog<void>(
      context,
      title: Text(l10n.jobDetailCancelTitle),
      content: Text(l10n.jobDetailCancelBody),
      actions: isCupertino
          ? [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.jobDetailKeepIt),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(context);
                  _handleCancelJob();
                },
                isDestructiveAction: true,
                child: Text(l10n.jobDetailCancelCta),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.jobDetailKeepIt),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleCancelJob();
                },
                child: Text(l10n.jobDetailCancelCta,
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
    );
  }
}
