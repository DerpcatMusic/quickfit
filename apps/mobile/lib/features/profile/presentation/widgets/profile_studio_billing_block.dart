import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/features/profile/presentation/widgets/profile_primitives.dart';

class ProfileStudioBillingBlock extends StatelessWidget {
  const ProfileStudioBillingBlock({
    super.key,
    required this.pricingTitle,
    required this.pricingSubtitle,
    required this.pricingSummary,
    required this.onOpenPricing,
    required this.billingTitle,
    required this.billingSubtitle,
    required this.billingSummary,
    required this.onOpenBilling,
    this.publicJobsTitle,
    this.publicJobsSubtitle,
    this.publicJobsSummary,
    this.onOpenPublicJobs,
    this.showDividerAfterBlock = true,
  });

  final String pricingTitle;
  final String pricingSubtitle;
  final String pricingSummary;
  final VoidCallback? onOpenPricing;

  final String billingTitle;
  final String billingSubtitle;
  final String billingSummary;
  final VoidCallback? onOpenBilling;

  final String? publicJobsTitle;
  final String? publicJobsSubtitle;
  final String? publicJobsSummary;
  final VoidCallback? onOpenPublicJobs;

  final bool showDividerAfterBlock;

  @override
  Widget build(BuildContext context) {
    final entries = <_StudioSettingsEntry>[
      _StudioSettingsEntry(
        icon: LucideIcons.trendingUp,
        title: pricingTitle,
        subtitle: pricingSubtitle,
        summary: pricingSummary,
        onTap: onOpenPricing,
      ),
      _StudioSettingsEntry(
        icon: LucideIcons.creditCard,
        title: billingTitle,
        subtitle: billingSubtitle,
        summary: billingSummary,
        onTap: onOpenBilling,
      ),
      if (publicJobsTitle != null &&
          publicJobsSubtitle != null &&
          publicJobsSummary != null &&
          onOpenPublicJobs != null)
        _StudioSettingsEntry(
          icon: LucideIcons.briefcase,
          title: publicJobsTitle!,
          subtitle: publicJobsSubtitle!,
          summary: publicJobsSummary!,
          onTap: onOpenPublicJobs,
        ),
    ];

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          ProfileTile(
            icon: entries[i].icon,
            title: entries[i].title,
            subtitle: entries[i].subtitle,
            trailing: _ProfileTrailingText(text: entries[i].summary),
            onTap: entries[i].onTap,
            showDivider: i != entries.length - 1 || showDividerAfterBlock,
          ),
      ],
    );
  }
}

class _ProfileTrailingText extends StatelessWidget {
  const _ProfileTrailingText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.mutedText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StudioSettingsEntry {
  const _StudioSettingsEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.summary,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String summary;
  final VoidCallback? onTap;
}
