import 'package:flutter/material.dart';
import 'package:quickfit/core/theme/app_colors.dart';

class InstructorStatsCard extends StatelessWidget {
  const InstructorStatsCard({
    super.key,
    required this.totalJobs,
    required this.earnings,
    required this.visibleJobsCount,
  });

  final int totalJobs;
  final double earnings;
  final int visibleJobsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                label: 'Total Jobs',
                value: '$totalJobs',
                icon: Icons.history,
              ),
            ),
            Container(width: 1, height: 40, color: colors.divider),
            Expanded(
              child: _StatItem(
                label: 'Earnings',
                value: 'ILS ${earnings.toStringAsFixed(0)}',
                icon: Icons.payments_outlined,
              ),
            ),
            Container(width: 1, height: 40, color: colors.divider),
            Expanded(
              child: _StatItem(
                label: 'Visible',
                value: '$visibleJobsCount',
                icon: Icons.map,
                highlight: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label, value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlight ? theme.colorScheme.primary : null,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
