import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/features/profile/presentation/widgets/profile_primitives.dart';

class ProfileAccountBlock extends StatelessWidget {
  const ProfileAccountBlock({
    super.key,
    required this.title,
    required this.displayName,
    required this.displayNameTitle,
    required this.email,
    required this.emailTitle,
    required this.phone,
    required this.phoneTitle,
    required this.address,
    required this.homeAddressTitle,
    required this.isInstructor,
    required this.workRadiusLabel,
    required this.workRadiusTitle,
    required this.isBusy,
    this.onEditDisplayName,
    this.onEmailActions,
    this.onEditAddress,
    this.onEditRadius,
  });

  final String title;
  final String displayName;
  final String displayNameTitle;
  final String email;
  final String emailTitle;
  final String phone;
  final String phoneTitle;
  final String address;
  final String homeAddressTitle;
  final bool isInstructor;
  final String workRadiusLabel;
  final String workRadiusTitle;
  final bool isBusy;
  final VoidCallback? onEditDisplayName;
  final VoidCallback? onEmailActions;
  final VoidCallback? onEditAddress;
  final VoidCallback? onEditRadius;

  @override
  Widget build(BuildContext context) {
    final entries = <_ProfileAccountEntry>[
      _ProfileAccountEntry(
        icon: LucideIcons.user,
        title: displayNameTitle,
        value: displayName,
        onTap: isBusy ? null : onEditDisplayName,
      ),
      _ProfileAccountEntry(
        icon: LucideIcons.mail,
        title: emailTitle,
        value: email,
        onTap: onEmailActions,
      ),
      if (phone.isNotEmpty)
        _ProfileAccountEntry(
          icon: LucideIcons.phone,
          title: phoneTitle,
          value: phone,
        ),
      _ProfileAccountEntry(
        icon: LucideIcons.mapPin,
        title: homeAddressTitle,
        value: address,
        onTap: isBusy ? null : onEditAddress,
      ),
      if (isInstructor)
        _ProfileAccountEntry(
          icon: LucideIcons.mapPin,
          title: workRadiusTitle,
          value: workRadiusLabel,
          onTap: isBusy ? null : onEditRadius,
        ),
    ];

    return ProfileSectionCard(
      title: title,
      children: [
        for (var i = 0; i < entries.length; i++)
          ProfileTile(
            icon: entries[i].icon,
            title: entries[i].title,
            trailing: _ProfileTrailingText(
              text: entries[i].value,
              isActionable: entries[i].onTap != null,
            ),
            onTap: entries[i].onTap,
            showDivider: i != entries.length - 1,
          ),
      ],
    );
  }
}

class _ProfileTrailingText extends StatelessWidget {
  const _ProfileTrailingText({
    required this.text,
    this.isActionable = false,
  });

  final String text;
  final bool isActionable;

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
          color: isActionable ? theme.colorScheme.primary : colors.mutedText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProfileAccountEntry {
  const _ProfileAccountEntry({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
}
