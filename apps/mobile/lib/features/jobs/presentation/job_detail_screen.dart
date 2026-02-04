// Job Detail Screen - Shared view for studios and instructors
// lib/features/jobs/presentation/job_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/convex_service.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import '../providers/jobs_provider.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  Map<String, dynamic>? _job;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJobDetails();
  }

  Future<void> _loadJobDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ConvexService.instance.getJobById(widget.jobId);

      if (data != null) {
        if (mounted) {
          setState(() {
            _job = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Job not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _claimJob() async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:claimJob',
        args: {'jobId': widget.jobId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job claimed successfully!')),
        );
        _loadJobDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to claim job: $e')),
        );
      }
    }
  }

  Future<void> _handleRespondToClaim(bool accept) async {
    final claimId = _job?['claimId'] as String?;
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
        _loadJobDetails();
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

  Future<void> _handleWithdrawClaim() async {
    try {
      final success =
          await ref.read(jobsProvider.notifier).withdrawClaim(widget.jobId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim withdrawn.')),
        );
        _loadJobDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to withdraw: $e')),
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

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadJobDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final job = _job!;
    final status = job['status'] as String;
    final isSos = job['isSos'] as bool? ?? false;
    final startTime = job['startTime'] as num;
    final endTime = job['endTime'] as num;
    final startDate = DateTime.fromMillisecondsSinceEpoch(startTime.toInt());
    final endDate = DateTime.fromMillisecondsSinceEpoch(endTime.toInt());
    final duration = job['durationMinutes'] as int? ??
        endDate.difference(startDate).inMinutes;
    final rate = (job['currentRate'] as num).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          if (isStudio && (status == 'open' || status == 'claimed'))
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            _buildDetailRow(
              LucideIcons.calendar,
              'Date',
              DateFormat('EEEE, MMM d, yyyy').format(startDate),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              LucideIcons.clock,
              'Time',
              '${DateFormat.Hm().format(startDate)} ($duration min)',
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              LucideIcons.mapPin,
              'Location',
              job['address'] ?? 'Israel',
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              LucideIcons.banknote,
              'Rate',
              '₪${rate.toStringAsFixed(0)}',
              valueColor: colors.successText,
            ),
            const Divider(height: 48),

            // Description / Notes
            Text(
              'Requirements & Notes',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              job['notes'] ?? 'No special requirements listed.',
              style: theme.textTheme.bodyLarge,
            ),

            if (!isStudio && status == 'open') ...[
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _claimJob,
                  child: const Text('Claim this Job'),
                ),
              ),
            ],

            if (isStudio &&
                status == 'claimed' &&
                job['claimedInstructor'] != null) ...[
              const Divider(height: 48),
              Text(
                'Claimed By',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildInstructorCard(theme, colors, job['claimedInstructor']),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleRespondToClaim(false),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error),
                      child: const Text('Reject Claim'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _handleRespondToClaim(true),
                      child: const Text('Accept Claim'),
                    ),
                  ),
                ],
              ),
            ],

            if (!isStudio &&
                status == 'claimed' &&
                job['claimedBy'] == authState.convexUserId) ...[
              const SizedBox(height: 48),
              Center(
                child: Text(
                  'You have claimed this job.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colors.mutedText),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _handleWithdrawClaim,
                  child: const Text('Cancel Claim'),
                ),
              ),
            ],
          ],
        ),
      ),
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
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
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
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                )),
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
                Text(
                  instructor['name'] ?? 'Unknown',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
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
          IconButton(
            icon: const Icon(LucideIcons.chevronRight),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Instructor profile view coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Job?'),
        content: const Text(
            'Are you sure you want to cancel this job? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleCancelJob();
            },
            child:
                const Text('Cancel Job', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
