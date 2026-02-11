import 'dart:async';

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
import 'package:quickfit/features/auth/providers/auth_provider.dart';
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

  Future<void> _refreshJobs() {
    return ref.read(studioJobsProvider.notifier).refresh();
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
      await _refreshJobs();
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
      await _refreshJobs();
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

  Future<void> _completeJob(String jobId) async {
    final l10n = AppLocalizations.of(context)!;
    final isCupertino = isCupertinoPlatform(context);
    final confirm = await qf_dialog.showAdaptiveDialog<bool>(
      context,
      title: Text(l10n.studioJobsCompleteConfirmTitle),
      content: Text(l10n.studioJobsCompleteConfirmBody),
      actions: isCupertino
          ? [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.studioJobsCancelNo),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.studioJobsCompleteConfirmAction),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.studioJobsCancelNo),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.studioJobsCompleteConfirmAction),
              ),
            ],
    );
    if (confirm != true) return;

    final success = await ref.read(studioJobsProvider.notifier).completeJob(jobId);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.studioJobsCompleteSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _refreshJobs();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.studioJobsCompleteFailure),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioJobsProvider);
    final auth = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context)!;
    final isCupertino = isCupertinoPlatform(context);
    final canUseStudioJobs = auth.isAuthenticated && auth.role == 'studio';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                tooltip: l10n.studioJobsBillingTooltip,
              ),
            if (isCupertino)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _refreshJobs,
                child: const Icon(CupertinoIcons.refresh),
              )
            else
              IconButton(
                onPressed: _refreshJobs,
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
        body: _StudioJobsBody(
          state: state,
          canUseStudioJobs: canUseStudioJobs,
          onRefresh: _refreshJobs,
          onOpenBilling: _openStudioBillingSheet,
          onAcceptClaim: (claimId) => _respondToClaim(claimId, true),
          onRejectClaim: (claimId) => _respondToClaim(claimId, false),
          onCancelJob: _cancelJob,
          onCompleteJob: _completeJob,
        ),
      ),
    );
  }
}

class _StudioJobsBody extends StatelessWidget {
  const _StudioJobsBody({
    required this.state,
    required this.canUseStudioJobs,
    required this.onRefresh,
    required this.onOpenBilling,
    required this.onAcceptClaim,
    required this.onRejectClaim,
    required this.onCancelJob,
    required this.onCompleteJob,
  });

  final StudioJobsState state;
  final bool canUseStudioJobs;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenBilling;
  final Future<void> Function(String claimId) onAcceptClaim;
  final Future<void> Function(String claimId) onRejectClaim;
  final Future<void> Function(String jobId) onCancelJob;
  final Future<void> Function(String jobId) onCompleteJob;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final activeJobs = state.activeJobs;
    final historyJobs = state.completedJobs;

    if (!canUseStudioJobs) {
      return _StatePanel(
        icon: LucideIcons.logIn,
        title: l10n.studioAuthRequiredTitle,
        body: l10n.studioAuthRequiredBodyJobs,
        actionText: l10n.authGoToLogin,
        onAction: () => context.go(AppRoutes.login),
      );
    }

    if (state.isLoading && state.jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.jobs.isEmpty) {
      return _StatePanel(
        icon: LucideIcons.alertCircle,
        title: l10n.studioJobsLoadFailed(state.error!),
        actionText: l10n.retry,
        onAction: onRefresh,
      );
    }

    if (state.jobs.isEmpty) {
      return _StatePanel(
        icon: LucideIcons.briefcase,
        title: l10n.studioJobsEmptyTitle,
        body: l10n.studioJobsEmptyBody,
        actionText: l10n.studioJobsPostFirstJob,
        onAction: () => context.go(AppRoutes.studioPostJob),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _JobsSummaryCard(
            activeCount: activeJobs.length,
            historyCount: historyJobs.length,
            onOpenBilling: onOpenBilling,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.cardBorder),
          ),
          child: TabBar(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: theme.colorScheme.onSurface,
            unselectedLabelColor: context.colors.mutedText,
            tabs: [
              Tab(text: l10n.studioJobsTabActiveWithCount(activeJobs.length)),
              Tab(text: l10n.studioJobsTabHistoryWithCount(historyJobs.length)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            children: [
              _JobsListView(
                jobs: activeJobs,
                onRefresh: onRefresh,
                onAcceptClaim: onAcceptClaim,
                onRejectClaim: onRejectClaim,
                onCancelJob: onCancelJob,
                onCompleteJob: onCompleteJob,
              ),
              _JobsListView(
                jobs: historyJobs,
                onRefresh: onRefresh,
                onAcceptClaim: onAcceptClaim,
                onRejectClaim: onRejectClaim,
                onCancelJob: onCancelJob,
                onCompleteJob: onCompleteJob,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JobsSummaryCard extends StatelessWidget {
  const _JobsSummaryCard({
    required this.activeCount,
    required this.historyCount,
    required this.onOpenBilling,
  });

  final int activeCount;
  final int historyCount;
  final VoidCallback onOpenBilling;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.surfaceContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _SummaryPill(
                  label: l10n.studioJobsSummaryActive,
                  value: activeCount.toString(),
                ),
                const SizedBox(width: 8),
                _SummaryPill(
                  label: l10n.studioJobsSummaryHistory,
                  value: historyCount.toString(),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onOpenBilling,
            icon: const Icon(LucideIcons.receipt, size: 16),
            label: Text(l10n.studioJobsSummaryPayments),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: context.colors.mutedText,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.actionText,
    required this.onAction,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String actionText;
  final FutureOr<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCupertino = isCupertinoPlatform(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: context.colors.mutedText),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (body != null) ...[
                const SizedBox(height: 6),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.colors.mutedText,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (isCupertino)
                CupertinoButton.filled(
                  onPressed: onAction,
                  child: Text(actionText),
                )
              else
                FilledButton(
                  onPressed: onAction,
                  child: Text(actionText),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobsListView extends StatelessWidget {
  const _JobsListView({
    required this.jobs,
    required this.onRefresh,
    required this.onAcceptClaim,
    required this.onRejectClaim,
    required this.onCancelJob,
    required this.onCompleteJob,
  });

  final List<StudioJobRecord> jobs;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String claimId) onAcceptClaim;
  final Future<void> Function(String claimId) onRejectClaim;
  final Future<void> Function(String jobId) onCancelJob;
  final Future<void> Function(String jobId) onCompleteJob;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            Center(child: Text(l10n.studioJobsSectionEmpty)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final record = jobs[index];
          return _JobCard(
            record: record,
            onAccept: () {
              final claimId = record.claimId;
              if (claimId != null) onAcceptClaim(claimId);
            },
            onReject: () {
              final claimId = record.claimId;
              if (claimId != null) onRejectClaim(claimId);
            },
            onCancel: () => onCancelJob(record.job.id),
            onComplete: () => onCompleteJob(record.job.id),
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
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    required this.onComplete,
    required this.onTap,
  });

  final StudioJobRecord record;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final job = record.job;
    final status = job.status;
    final statusStyle = _statusStyle(status, theme, context.colors, l10n);
    final claimedInstructor = record.claimedInstructor;
    final instructorFallbackInitial =
        l10n.studioJobsInstructorFallback.isNotEmpty
            ? l10n.studioJobsInstructorFallback.substring(0, 1).toUpperCase()
            : '?';

    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateStr = DateFormat.yMMMEd(locale).add_Hm().format(job.startTime);

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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusChip(
                      label: statusStyle.label, color: statusStyle.color),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(LucideIcons.calendar,
                      size: 14, color: context.colors.mutedText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dateStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.colors.mutedText),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      job.category,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    l10n.studioJobsRate(job.currentRate.toStringAsFixed(0)),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (job.isSos) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colors.urgentBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: context.colors.urgentBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.zap,
                              size: 11, color: context.colors.urgentText),
                          const SizedBox(width: 4),
                          Text(
                            l10n.sosLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: context.colors.urgentText,
                              fontWeight: FontWeight.w700,
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
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.cardBorder),
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
                      const SizedBox(width: 10),
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
                              color: theme.colorScheme.primary,
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
              if (status == 'confirmed') ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(LucideIcons.checkCircle2, size: 16),
                    label: Text(l10n.studioJobsCompleteConfirmAction),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _JobStatusStyle _statusStyle(
    String status,
    ThemeData theme,
    AppColors colors,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case 'open':
        return _JobStatusStyle(
          color: theme.colorScheme.primary,
          label: l10n.studioJobsStatusOpen,
        );
      case 'claimed':
      case 'backup_claimed':
        return _JobStatusStyle(
          color: Colors.orange.shade700,
          label: l10n.studioJobsStatusPending,
        );
      case 'confirmed':
        return _JobStatusStyle(
          color: theme.colorScheme.primary,
          label: l10n.studioJobsStatusConfirmed,
        );
      case 'completed':
        return _JobStatusStyle(
          color: colors.successBorder,
          label: l10n.studioJobsStatusCompleted,
        );
      case 'cancelled':
        return _JobStatusStyle(
          color: theme.colorScheme.error,
          label: l10n.studioJobsStatusCancelled,
        );
      default:
        return _JobStatusStyle(
          color: theme.colorScheme.outline,
          label: status.toUpperCase(),
        );
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _JobStatusStyle {
  const _JobStatusStyle({required this.color, required this.label});

  final Color color;
  final String label;
}
