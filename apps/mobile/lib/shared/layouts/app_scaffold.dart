/// App Scaffold - Bottom navigation shell with solid Material design.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/platform.dart';

/// Scaffold wrapper with bottom navigation for main app screens.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.role,
    required this.navigationShell,
  });

  final String role;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomNavBar(
        role: role,
        navigationShell: navigationShell,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.role,
    required this.navigationShell,
  });

  final String role;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final isCupertino = isCupertinoPlatform(context);
    // Navigation shell gives us the current index directly
    final currentIndex = navigationShell.currentIndex;
    final items = role == 'instructor' ? _instructorNavItems : _studioNavItems;

    if (isCupertino) {
      return CupertinoTabBar(
        currentIndex: currentIndex,
        backgroundColor: theme.colorScheme.surfaceContainer,
        activeColor: theme.colorScheme.primary,
        inactiveColor: colors.mutedText,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == currentIndex,
        ),
        items: items
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.cupertinoIcon),
                activeIcon: Icon(item.cupertinoActiveIcon),
                label: item.label,
              ),
            )
            .toList(),
      );
    }

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
                onTap: () => navigationShell.goBranch(
                  index,
                  initialLocation: index == currentIndex,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
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
    required this.cupertinoIcon,
    required this.cupertinoActiveIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final IconData cupertinoIcon;
  final IconData cupertinoActiveIcon;
  final String label;
  final String route;
}

// Instructor navigation items
const _instructorNavItems = [
  _NavItemData(
    icon: LucideIcons.briefcase,
    activeIcon: LucideIcons.briefcase,
    cupertinoIcon: CupertinoIcons.briefcase,
    cupertinoActiveIcon: CupertinoIcons.briefcase_fill,
    label: 'Jobs',
    route: AppRoutes.instructorJobs,
  ),
  _NavItemData(
    icon: LucideIcons.calendar,
    activeIcon: LucideIcons.calendar,
    cupertinoIcon: CupertinoIcons.calendar,
    cupertinoActiveIcon: CupertinoIcons.calendar,
    label: 'Schedule',
    route: AppRoutes.instructorSchedule,
  ),
  _NavItemData(
    icon: LucideIcons.map,
    activeIcon: LucideIcons.map,
    cupertinoIcon: CupertinoIcons.map,
    cupertinoActiveIcon: CupertinoIcons.map_fill,
    label: 'Map',
    route: AppRoutes.instructorMap,
  ),
  _NavItemData(
    icon: LucideIcons.user,
    activeIcon: LucideIcons.user,
    cupertinoIcon: CupertinoIcons.person,
    cupertinoActiveIcon: CupertinoIcons.person_fill,
    label: 'Profile',
    route: AppRoutes.instructorProfile,
  ),
];

// Studio navigation items
const _studioNavItems = [
  _NavItemData(
    icon: LucideIcons.clipboardList,
    activeIcon: LucideIcons.clipboardList,
    cupertinoIcon: CupertinoIcons.doc_text,
    cupertinoActiveIcon: CupertinoIcons.doc_text_fill,
    label: 'My Jobs',
    route: AppRoutes.studioJobs,
  ),
  _NavItemData(
    icon: LucideIcons.plusCircle,
    activeIcon: LucideIcons.plusCircle,
    cupertinoIcon: CupertinoIcons.add_circled,
    cupertinoActiveIcon: CupertinoIcons.add_circled_solid,
    label: 'Post Job',
    route: AppRoutes.studioPostJob,
  ),
  _NavItemData(
    icon: LucideIcons.user,
    activeIcon: LucideIcons.user,
    cupertinoIcon: CupertinoIcons.person,
    cupertinoActiveIcon: CupertinoIcons.person_fill,
    label: 'Profile',
    route: AppRoutes.studioProfile,
  ),
];
