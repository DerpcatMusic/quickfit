/// Job List Screen - Instructor view with swipe-to-claim.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/job_card.dart';
import '../../../shared/widgets/sos_badge.dart';
import '../providers/jobs_provider.dart';
import '../../auth/providers/auth_provider.dart';
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
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filter Jobs',
                        style: Theme.of(context).textTheme.titleLarge),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = null;
                          _minRate = 0;
                        });
                        this.setState(() {
                          _selectedCategory = null;
                          _minRate = 0;
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Category',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FitnessCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat.id;
                    return ChoiceChip(
                      label: Text(cat.nameEn),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(
                            () => _selectedCategory = selected ? cat.id : null);
                        this.setState(
                            () => _selectedCategory = selected ? cat.id : null);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text('Minimum Rate: ₪${_minRate.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _minRate,
                  min: 0,
                  max: 300,
                  divisions: 6,
                  label: '₪${_minRate.toInt()}',
                  onChanged: (val) {
                    setState(() => _minRate = val);
                    this.setState(() => _minRate = val);
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle2, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      Text('Job claimed! ${job.studioName} will be notified.'),
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

    return SliverAppBar(
      floating: true,
      title: const Text('Available Jobs'),
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
                'Something went wrong',
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
              FilledButton.icon(
                onPressed: _onRefresh,
                icon: const Icon(LucideIcons.refreshCw),
                label: const Text('Try Again'),
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
                'No jobs available',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back soon or expand your search radius in settings.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.mutedText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _onRefresh,
                icon: const Icon(LucideIcons.refreshCw),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobsList(BuildContext context, JobsState jobsState) {
    var filteredJobs = jobsState.jobs;

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
              title: 'Urgent Jobs',
              count: sosJobs.length,
              isUrgent: true,
            ),
            const SizedBox(height: 12),
            ...sosJobs.map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: JobCard(
                    job: job,
                    isLoading: _claimingJobId == job.id,
                    pendingStatus: jobsState.getPendingOperation(job.id)?.status,
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
              title: 'Available Jobs',
              count: regularJobs.length,
            ),
            const SizedBox(height: 12),
            ...regularJobs.map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: JobCard(
                    job: job,
                    isLoading: _claimingJobId == job.id,
                    pendingStatus: jobsState.getPendingOperation(job.id)?.status,
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
              'Pull down to refresh',
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
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.searchX, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No jobs match your filters',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                  _minRate = 0;
                });
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
