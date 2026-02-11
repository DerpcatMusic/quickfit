import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/features/profile/presentation/widgets/profile_primitives.dart';
import 'package:quickfit/features/profile/presentation/widgets/profile_studio_billing_block.dart';

class ProfileSettingsBlock extends StatelessWidget {
  const ProfileSettingsBlock({
    super.key,
    required this.title,
    required this.linkedAccountsTitle,
    required this.linkedAccountsSummary,
    required this.showAddPassword,
    required this.addPasswordTitle,
    required this.addPasswordSubtitle,
    this.onAddPassword,
    required this.notificationsTitle,
    required this.notificationsSummary,
    this.onOpenNotifications,
    required this.languageTitle,
    required this.languageSummary,
    this.onOpenLanguage,
    this.studioBillingBlock,
    required this.redoOnboardingTitle,
    this.onRedoOnboarding,
    required this.helpSupportTitle,
    this.onShowHelp,
    required this.termsTitle,
    this.onShowTerms,
    required this.privacyTitle,
    this.onShowPrivacy,
  });

  final String title;

  final String linkedAccountsTitle;
  final String linkedAccountsSummary;

  final bool showAddPassword;
  final String addPasswordTitle;
  final String addPasswordSubtitle;
  final VoidCallback? onAddPassword;

  final String notificationsTitle;
  final String notificationsSummary;
  final VoidCallback? onOpenNotifications;

  final String languageTitle;
  final String languageSummary;
  final VoidCallback? onOpenLanguage;

  final ProfileStudioBillingBlock? studioBillingBlock;

  final String redoOnboardingTitle;
  final VoidCallback? onRedoOnboarding;

  final String helpSupportTitle;
  final VoidCallback? onShowHelp;

  final String termsTitle;
  final VoidCallback? onShowTerms;

  final String privacyTitle;
  final VoidCallback? onShowPrivacy;

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: title,
      children: [
        ProfileTile(
          icon: LucideIcons.link,
          title: linkedAccountsTitle,
          trailing: _ProfileTrailingText(text: linkedAccountsSummary),
        ),
        if (showAddPassword)
          ProfileTile(
            icon: LucideIcons.keyRound,
            title: addPasswordTitle,
            subtitle: addPasswordSubtitle,
            onTap: onAddPassword,
          ),
        ProfileTile(
          icon: LucideIcons.bell,
          title: notificationsTitle,
          trailing: _ProfileTrailingText(text: notificationsSummary),
          onTap: onOpenNotifications,
        ),
        ProfileTile(
          icon: LucideIcons.globe,
          title: languageTitle,
          trailing: _ProfileTrailingText(text: languageSummary),
          onTap: onOpenLanguage,
        ),
        if (studioBillingBlock != null) studioBillingBlock!,
        ProfileTile(
          icon: LucideIcons.refreshCw,
          title: redoOnboardingTitle,
          onTap: onRedoOnboarding,
        ),
        ProfileTile(
          icon: LucideIcons.helpCircle,
          title: helpSupportTitle,
          onTap: onShowHelp,
        ),
        ProfileTile(
          icon: LucideIcons.fileText,
          title: termsTitle,
          onTap: onShowTerms,
        ),
        ProfileTile(
          icon: LucideIcons.shield,
          title: privacyTitle,
          onTap: onShowPrivacy,
          showDivider: false,
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
