/// App Scaffold - Bottom navigation shell with solid Material design.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';

/// Scaffold wrapper with bottom navigation for main app screens.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.role,
    required this.child,
  });

  final String role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNavBar(role: role),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final location = GoRouterState.of(context).matchedLocation;
    final items = role == 'instructor' ? _instructorNavItems : _studioNavItems;
    final currentIndex = _getCurrentIndex(location, items);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: colors.divider),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;

              return _NavItem(
                icon: item.icon,
                activeIcon: item.activeIcon,
                label: item.label,
                isSelected: isSelected,
                onTap: () => context.go(item.route),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  int _getCurrentIndex(String location, List<_NavItemData> items) {
    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i].route)) {
        return i;
      }
    }
    return 0;
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : colors.mutedText,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : colors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
}

// Instructor navigation items
const _instructorNavItems = [
  _NavItemData(
    icon: LucideIcons.briefcase,
    activeIcon: LucideIcons.briefcase,
    label: 'Jobs',
    route: AppRoutes.instructorJobs,
  ),
  _NavItemData(
    icon: LucideIcons.calendar,
    activeIcon: LucideIcons.calendar,
    label: 'Schedule',
    route: AppRoutes.instructorSchedule,
  ),
  _NavItemData(
    icon: LucideIcons.map,
    activeIcon: LucideIcons.map,
    label: 'Map',
    route: AppRoutes.instructorMap,
  ),
  _NavItemData(
    icon: LucideIcons.user,
    activeIcon: LucideIcons.user,
    label: 'Profile',
    route: AppRoutes.instructorProfile,
  ),
];

// Studio navigation items
const _studioNavItems = [
  _NavItemData(
    icon: LucideIcons.clipboardList,
    activeIcon: LucideIcons.clipboardList,
    label: 'My Jobs',
    route: AppRoutes.studioJobs,
  ),
  _NavItemData(
    icon: LucideIcons.plusCircle,
    activeIcon: LucideIcons.plusCircle,
    label: 'Post Job',
    route: AppRoutes.studioPostJob,
  ),
  _NavItemData(
    icon: LucideIcons.user,
    activeIcon: LucideIcons.user,
    label: 'Profile',
    route: AppRoutes.studioProfile,
  ),
];
