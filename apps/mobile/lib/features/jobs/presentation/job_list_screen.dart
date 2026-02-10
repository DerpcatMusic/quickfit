/// Job List Screen - Instructor view with swipe-to-claim.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:quickfit/l10n/app_localizations.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/platform.dart';
import '../../../shared/widgets/job_card.dart';
import '../../../shared/widgets/sos_badge.dart';
import '../providers/jobs_provider.dart';
import '../../../core/constants/categories.dart';

/// Main screen for instructors to browse available jobs.
class JobListScreen extends ConsumerStatefulWidget {
  const JobListScreen({super.key});

  @override
  ConsumerState<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends ConsumerState<JobListScreen> {
  final _scrollController = ScrollController();
  String? _claimingJobId;
  String? _selectedCategory;
  double _minRate = 0;

  void _showFilters() {
    if (isCupertinoPlatform(context)) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoPopupSurface(
          child: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: _buildFilterContent(
                  context,
                  setState,
                  isCupertino: true,
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(context).viewInsets.bottom + 48,
            ),
            child: _buildFilterContent(
              context,
              setState,
              isCupertino: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterContent(
    BuildContext context,
    void Function(VoidCallback fn) setSheetState, {
    required bool isCupertino,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.filterJobsTitle, style: theme.textTheme.titleLarge),
            isCupertino
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setSheetState(() {
                        _selectedCategory = null;
                        _minRate = 0;
                      });
                      setState(() {
                        _selectedCategory = null;
                        _minRate = 0;
                      });
                    },
                    child: Text(l10n.reset),
                  )
                : TextButton(
                    onPressed: () {
                      setSheetState(() {
                        _selectedCategory = null;
                        _minRate = 0;
                      });
                      setState(() {
                        _selectedCategory = null;
                        _minRate = 0;
                      });
                    },
                    child: Text(l10n.reset),
                  ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          l10n.categoryLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FitnessCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat.id;
            if (isCupertino) {
              return CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                onPressed: () {
                  setSheetState(() =>
                      _selectedCategory = isSelected ? null : cat.id);
                  setState(() =>
                      _selectedCategory = isSelected ? null : cat.id);
                },
                child: Text(
                  cat.nameEn,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
              );
            }
            return ChoiceChip(
              label: Text(cat.nameEn),
              selected: isSelected,
              onSelected: (selected) {
                setSheetState(
                    () => _selectedCategory = selected ? cat.id : null);
                setState(() => _selectedCategory = selected ? cat.id : null);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.minimumRateLabelWithValue(
            _minRate.toInt().toString(),
            l10n.currencyILS,
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        isCupertino
            ? CupertinoSlider(
                value: _minRate,
                min: 0,
                max: 300,
                divisions: 6,
                onChanged: (val) {
                  setSheetState(() => _minRate = val);
                  setState(() => _minRate = val);
                },
              )
            : Slider(
                value: _minRate,
                min: 0,
                max: 300,
                divisions: 6,
                label: l10n.currencyAmount(
                  l10n.currencyILS,
                  _minRate.toInt().toString(),
                ),
                onChanged: (val) {
                  setSheetState(() => _minRate = val);
                  setState(() => _minRate = val);
                },
              ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: isCupertino
              ? CupertinoButton.filled(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.applyFilters),
                )
              : FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.applyFilters),
                ),
        ),
      ],
    );
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await LocationService.instance.updateLocation();
    await ref.read(jobsProvider.notifier).refresh();
  }

  Future<void> _claimJob(Job job) async {
    setState(() => _claimingJobId = job.id);

    final success = await ref.read(jobsProvider.notifier).claimJob(job.id);

    if (mounted) {
      setState(() => _claimingJobId = null);

      if (success) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle2, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.jobClaimedNotification(job.studioName),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildAppBar(context),
            if (jobsState.isLoading)
              _buildLoadingState(context)
            else if (jobsState.error != null)
              _buildErrorState(context, jobsState.error!)
            else if (jobsState.jobs.isEmpty)
              _buildEmptyState(context)
            else
              _buildJobsList(context, jobsState),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (isCupertinoPlatform(context)) {
      return CupertinoSliverNavigationBar(
        largeTitle: Text(l10n.availableJobsTitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                await LocationService.instance.updateLocation();
                _onRefresh();
              },
              child: const Icon(CupertinoIcons.location),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showFilters,
              child: Icon(
                CupertinoIcons.slider_horizontal_3,
                color: (_selectedCategory != null || _minRate > 0)
                    ? theme.colorScheme.primary
                    : colors.mutedText,
              ),
            ),
          ],
        ),
      );
    }

    return SliverAppBar(
      floating: true,
      title: Text(l10n.availableJobsTitle),
      actions: [
        IconButton(
          icon: Icon(LucideIcons.mapPin, color: colors.mutedText),
          onPressed: () async {
            await LocationService.instance.updateLocation();
            _onRefresh();
          },
        ),
        IconButton(
          icon: Icon(
            LucideIcons.sliders,
            color: (_selectedCategory != null || _minRate > 0)
                ? theme.colorScheme.primary
                : colors.mutedText,
          ),
          onPressed: _showFilters,
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final colors = context.colors;

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Shimmer.fromColors(
              baseColor: colors.cardBorder,
              highlightColor: colors.cardBackground,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.cardBorder),
                ),
              ),
            ),
          ),
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final isCupertino = isCupertinoPlatform(context);
    final l10n = AppLocalizations.of(context)!;

    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.alertCircle,
                size: 64,
                color: colors.urgentText,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.somethingWentWrong,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.mutedText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              isCupertino
                  ? CupertinoButton.filled(
                      onPressed: _onRefresh,
                      child: Text(l10n.tryAgain),
                    )
                  : FilledButton.icon(
                      onPressed: _onRefresh,
                      icon: const Icon(LucideIcons.refreshCw),
                      label: Text(l10n.tryAgain),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final isCupertino = isCupertinoPlatform(context);
    final l10n = AppLocalizations.of(context)!;

    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.briefcase,
                  size: 48,
                  color: colors.mutedText,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.noJobsAvailable,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noJobsAvailableHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.mutedText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              isCupertino
                  ? CupertinoButton(
                      onPressed: _onRefresh,
                      color: CupertinoColors.systemGrey5,
                      child: Text(l10n.refresh),
                    )
                  : OutlinedButton.icon(
                      onPressed: _onRefresh,
                      icon: const Icon(LucideIcons.refreshCw),
                      label: Text(l10n.refresh),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobsList(BuildContext context, JobsState jobsState) {
    var filteredJobs = jobsState.jobs;
    final l10n = AppLocalizations.of(context)!;

    if (_selectedCategory != null) {
      filteredJobs =
          filteredJobs.where((j) => j.category == _selectedCategory).toList();
    }

    if (_minRate > 0) {
      filteredJobs =
          filteredJobs.where((j) => j.currentRate >= _minRate).toList();
    }

    final sosJobs = filteredJobs.where((j) => j.isSos).toList();
    final regularJobs = filteredJobs.where((j) => !j.isSos).toList();

    if (filteredJobs.isEmpty) {
      return _buildEmptyFiltersState(context);
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // SOS Jobs section
          if (sosJobs.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              icon: LucideIcons.zap,
              title: l10n.urgentJobsTitle,
              count: sosJobs.length,
              isUrgent: true,
            ),
            const SizedBox(height: 12),
            ...sosJobs.map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: JobCard(
                    job: job,
                    isLoading: _claimingJobId == job.id,
                    pendingStatus:
                        jobsState.getPendingOperation(job.id)?.status,
                    onClaim: () => _claimJob(job),
                    onTap: () => context
                        .push(AppRoutes.jobDetail.replaceFirst(':id', job.id)),
                  ),
                )),
            const SizedBox(height: 24),
          ],

          // Regular jobs section
          if (regularJobs.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              icon: LucideIcons.briefcase,
              title: l10n.availableJobsTitle,
              count: regularJobs.length,
            ),
            const SizedBox(height: 12),
            ...regularJobs.map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: JobCard(
                    job: job,
                    isLoading: _claimingJobId == job.id,
                    pendingStatus:
                        jobsState.getPendingOperation(job.id)?.status,
                    onClaim: () => _claimJob(job),
                    onTap: () => context
                        .push(AppRoutes.jobDetail.replaceFirst(':id', job.id)),
                  ),
                )),
          ],

          // Pull to refresh hint
          const SizedBox(height: 32),
          Center(
            child: Text(
              l10n.pullToRefresh,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.mutedText,
                  ),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    bool isUrgent = false,
  }) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Row(
      children: [
        if (isUrgent)
          const SosBadge(large: true)
        else
          Icon(icon, size: 20, color: colors.mutedText),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isUrgent ? colors.urgentBackground : colors.cardBorder,
            borderRadius: BorderRadius.circular(12),
            border: isUrgent ? Border.all(color: colors.urgentBorder) : null,
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isUrgent ? colors.urgentText : colors.mutedText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFiltersState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.searchX, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(l10n.noJobsMatchFilters,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                  _minRate = 0;
                });
              },
              child: Text(l10n.clearFilters),
            ),
          ],
        ),
      ),
    );
  }
}
