import 'package:flutter/material.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final totalJobsLabel = l10n?.totalJobsLabel ?? 'Total Jobs';
    final earningsLabel = l10n?.earningsLabel ?? 'Earnings';
    final visibleLabel = l10n?.visibleLabel ?? 'Visible';
    final earningsValue = l10n != null
        ? l10n.currencyAmount(l10n.currencyILS, earnings.toStringAsFixed(0))
        : 'ILS ${earnings.toStringAsFixed(0)}';

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
                label: totalJobsLabel,
                value: '$totalJobs',
                icon: Icons.history,
              ),
            ),
            Container(width: 1, height: 40, color: colors.divider),
            Expanded(
              child: _StatItem(
                label: earningsLabel,
                value: earningsValue,
                icon: Icons.payments_outlined,
              ),
            ),
            Container(width: 1, height: 40, color: colors.divider),
            Expanded(
              child: _StatItem(
                label: visibleLabel,
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
