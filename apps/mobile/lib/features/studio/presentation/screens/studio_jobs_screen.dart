import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:quickfit/core/router/app_routes.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/core/utils/platform.dart';
import 'package:quickfit/features/jobs/providers/studio_jobs_provider.dart';
import 'package:quickfit/l10n/app_localizations.dart';
import 'package:quickfit/shared/widgets/adaptive_app_bar.dart';
import 'package:quickfit/shared/widgets/adaptive_dialog.dart' as qf_dialog;
import 'package:quickfit/shared/widgets/studio_billing_sheet.dart';

class StudioJobsScreen extends ConsumerStatefulWidget {
  const StudioJobsScreen({super.key});

  @override
  ConsumerState<StudioJobsScreen> createState() => _StudioJobsScreenState();
}

class _StudioJobsScreenState extends ConsumerState<StudioJobsScreen> {
  Future<void> _openStudioBillingSheet() async {
    await StudioBillingSheet.show(context);
  }

  Future<void> _respondToClaim(String claimId, bool accept) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:respondToClaim',
        args: {'claimId': claimId, 'accept': accept},
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? l10n.studioJobsClaimAccepted
                : l10n.studioJobsClaimRejected,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await ref.read(studioJobsProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.mapErrorWithMessage(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _cancelJob(String jobId) async {
    final l10n = AppLocalizations.of(context)!;
    final isCupertino = isCupertinoPlatform(context);
    final confirm = await qf_dialog.showAdaptiveDialog<bool>(
      context,
      title: Text(l10n.studioJobsCancelTitle),
      content: Text(l10n.studioJobsCancelBody),
      actions: isCupertino
          ? [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.studioJobsCancelNo),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, true),
                isDestructiveAction: true,
                child: Text(l10n.studioJobsCancelYes),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.studioJobsCancelNo),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.studioJobsCancelYes),
              ),
            ],
    );

    if (confirm != true) return;

    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:cancelJob',
        args: {'jobId': jobId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.studioJobsCancelled),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await ref.read(studioJobsProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.mapErrorWithMessage(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioJobsProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final isCupertino = isCupertinoPlatform(context);

    return Scaffold(
      appBar: adaptiveAppBar(
        context,
        title: l10n.studioJobsTitle,
        actions: [
          if (isCupertino)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _openStudioBillingSheet,
              child: const Icon(CupertinoIcons.doc_text),
            )
          else
            IconButton(
              onPressed: _openStudioBillingSheet,
              icon: const Icon(LucideIcons.receipt),
              tooltip: 'Billing & Invoicing',
            ),
          if (isCupertino)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => ref.read(studioJobsProvider.notifier).refresh(),
              child: const Icon(CupertinoIcons.refresh),
            )
          else
            IconButton(
              onPressed: () => ref.read(studioJobsProvider.notifier).refresh(),
              icon: const Icon(LucideIcons.refreshCw),
              tooltip: l10n.studioJobsRefresh,
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
              label: Text(l10n.studioJobsPostJob),
            ),
      body: _buildBody(state, theme, colors),
    );
  }

  Widget _buildBody(StudioJobsState state, ThemeData theme, AppColors colors) {
    final l10n = AppLocalizations.of(context)!;
    final isCupertino = isCupertinoPlatform(context);

    if (state.isLoading && state.jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(l10n.studioJobsLoadFailed(state.error!),
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            isCupertino
                ? CupertinoButton.filled(
                    onPressed: () =>
                        ref.read(studioJobsProvider.notifier).refresh(),
                    child: Text(l10n.retry),
                  )
                : FilledButton(
                    onPressed: () =>
                        ref.read(studioJobsProvider.notifier).refresh(),
                    child: Text(l10n.retry),
                  ),
          ],
        ),
      );
    }

    if (state.jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.briefcase,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text(
              l10n.studioJobsEmptyTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.studioJobsEmptyBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            isCupertino
                ? CupertinoButton.filled(
                    onPressed: () => context.go(AppRoutes.studioPostJob),
                    child: Text(l10n.studioJobsPostFirstJob),
                  )
                : FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.studioPostJob),
                    icon: const Icon(LucideIcons.plus),
                    label: Text(l10n.studioJobsPostFirstJob),
                  ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(studioJobsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.jobs.length,
        itemBuilder: (context, index) {
          final record = state.jobs[index];
          return _JobCard(
            record: record,
            colors: colors,
            onAccept: () {
              final claimId = record.claimId;
              if (claimId != null) _respondToClaim(claimId, true);
            },
            onReject: () {
              final claimId = record.claimId;
              if (claimId != null) _respondToClaim(claimId, false);
            },
            onCancel: () => _cancelJob(record.job.id),
            onTap: () => context
                .push(AppRoutes.jobDetail.replaceFirst(':id', record.job.id)),
          );
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.record,
    required this.colors,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    required this.onTap,
  });

  final StudioJobRecord record;
  final AppColors colors;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final job = record.job;
    final status = job.status;
    final statusColor = _getStatusColor(status, theme);
    final statusLabel = _getStatusLabel(status, l10n);
    final claimedInstructor = record.claimedInstructor;
    final instructorFallbackInitial =
        l10n.studioJobsInstructorFallback.isNotEmpty
            ? l10n.studioJobsInstructorFallback.substring(0, 1).toUpperCase()
            : '?';

    final dateStr = DateFormat('EEE, MMM d â€¢ HH:mm').format(job.startTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: () {
          if (status == 'open' ||
              status == 'claimed' ||
              status == 'backup_claimed') {
            onCancel();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
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
              Row(
                children: [
                  Icon(LucideIcons.calendar,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      job.category,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    l10n.studioJobsRate(job.currentRate.toStringAsFixed(0)),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (job.isSos) ...[
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
                            l10n.sosLabel,
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
                        backgroundImage: claimedInstructor.photoUrl != null
                            ? NetworkImage(claimedInstructor.photoUrl!)
                            : null,
                        child: claimedInstructor.photoUrl == null
                            ? Text(
                                claimedInstructor.name.isNotEmpty
                                    ? claimedInstructor.name
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : instructorFallbackInitial,
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              claimedInstructor.name.isNotEmpty
                                  ? claimedInstructor.name
                                  : l10n.studioJobsInstructorFallback,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (claimedInstructor.isVerified)
                              Row(
                                children: [
                                  Icon(LucideIcons.badgeCheck,
                                      size: 14,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(l10n.studioJobsVerified,
                                      style: theme.textTheme.labelSmall),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (record.canRespondToClaim)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.check),
                              color: Colors.green,
                              onPressed: onAccept,
                              tooltip: l10n.studioJobsAccept,
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.x),
                              color: theme.colorScheme.error,
                              onPressed: onReject,
                              tooltip: l10n.studioJobsReject,
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
      case 'backup_claimed':
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

  String _getStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'open':
        return l10n.studioJobsStatusOpen;
      case 'claimed':
      case 'backup_claimed':
        return l10n.studioJobsStatusPending;
      case 'confirmed':
        return l10n.studioJobsStatusConfirmed;
      case 'completed':
        return l10n.studioJobsStatusCompleted;
      case 'cancelled':
        return l10n.studioJobsStatusCancelled;
      default:
        return status.toUpperCase();
    }
  }
}
