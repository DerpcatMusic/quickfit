// Profile Screen - User profile and settings
// lib/features/profile/presentation/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:quickfit/core/constants/app_constants.dart';
import 'package:quickfit/core/constants/categories.dart';
import 'package:quickfit/core/router/app_router.dart';
import 'package:quickfit/core/services/location_service.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:quickfit/core/theme/app_colors.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late Set<String> _selectedCategories;
  double _radiusKm = AppConstants.defaultRadiusKm;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _nameController =
        TextEditingController(text: authState.user?.displayName ?? '');
    _phoneController = TextEditingController(text: authState.phone ?? '');
    _addressController =
        TextEditingController(text: authState.homeAddress ?? '');
    _selectedCategories = Set.from(authState.categories ?? []);
    _radiusKm = authState.radiusKm ?? AppConstants.defaultRadiusKm;
    _initData();
  }

  void _initData() {
    final authState = ref.read(authProvider);
    _radiusKm = authState.radiusKm ?? AppConstants.defaultRadiusKm;
    _selectedCategories = Set.from(authState.categories ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            latitude: _lat,
            longitude: _lng,
            radiusKm: _radiusKm,
            categories: _selectedCategories.toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = authState.role;
    final isVerified = authState.isVerified;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildHeader(
                context, authState, Theme.of(context).extension<AppColors>()!),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_isEditing)
                  _buildEditForm(theme)
                else ...[
                  if (role == 'instructor') ...[
                    _buildVerificationCard(context, isVerified),
                    const SizedBox(height: 16),
                  ],
                  _buildAccountSection(user, role, theme),
                  const SizedBox(height: 16),
                  _buildCategoriesSection(role, theme),
                  const SizedBox(height: 16),
                  _buildSettingsSection(theme),
                  const SizedBox(height: 16),
                  _buildSignOutSection(theme),
                ],
                const SizedBox(height: 32),
                _buildVersionInfo(),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isEditing ? _buildSaveBar(theme) : null,
    );
  }

  Widget _buildEditForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Profile Info'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(LucideIcons.user),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(LucideIcons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TypeAheadField<Map<String, dynamic>>(
                  controller: _addressController,
                  builder: (context, controller, focusNode) => TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Home Address',
                      prefixIcon: Icon(LucideIcons.mapPin),
                    ),
                  ),
                  suggestionsCallback: (pattern) async {
                    return await LocationService.instance
                        .getAutocompleteSuggestions(pattern);
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      leading: const Icon(LucideIcons.mapPin, size: 18),
                      title: Text(suggestion['description']!),
                    );
                  },
                  onSelected: (suggestion) async {
                    final address = suggestion['description']!;
                    _addressController.text = address;
                    final pos = await LocationService.instance
                        .getLatLngFromAddress(address);
                    if (pos != null) {
                      _lat = pos.latitude;
                      _lng = pos.longitude;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Search Radius'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Maximum Distance', style: theme.textTheme.bodyLarge),
                    Text(
                      '${_radiusKm.toStringAsFixed(1)} km',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _radiusKm.clamp(0.5, 50.0),
                  min: 0.5,
                  max: 50.0,
                  divisions: 99,
                  onChanged: (value) {
                    setState(() {
                      _radiusKm = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Expertise'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FitnessCategory.values.map((cat) {
            final isSelected = _selectedCategories.contains(cat.id);
            return FilterChip(
              label: Text('${cat.emoji} ${cat.nameEn}'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(cat.id);
                  } else {
                    _selectedCategories.remove(cat.id);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSaveBar(ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _isSaving ? null : _saveProfile,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Changes'),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
    );
  }

  Widget _buildAccountSection(User? user, String? role, ThemeData theme) {
    return _buildSection(
      title: 'Account',
      children: [
        _buildMenuItem(
          icon: LucideIcons.user,
          title: 'Display Name',
          trailing: Text(user?.displayName ?? 'Not set',
              style: TextStyle(color: Colors.grey[600])),
        ),
        _buildMenuItem(
          icon: LucideIcons.mail,
          title: 'Email',
          trailing: Text(user?.email ?? 'Not set',
              style: TextStyle(color: Colors.grey[600])),
        ),
        if (role == 'instructor')
          _buildMenuItem(
            icon: LucideIcons.mapPin,
            title: 'Work Radius',
            trailing: Text('${_radiusKm.round()} km',
                style: TextStyle(color: Colors.grey[600])),
          ),
      ],
    );
  }

  Widget _buildCategoriesSection(String? role, ThemeData theme) {
    return _buildSection(
      title: role == 'instructor' ? 'Teaching Categories' : 'Class Types',
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FitnessCategory.values.take(3).map((cat) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.emoji),
                    const SizedBox(width: 4),
                    Text(cat.nameEn,
                        style: TextStyle(
                            color: cat.color, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(ThemeData theme) {
    final authNotifier = ref.read(authProvider.notifier);
    final hasPassword = authNotifier.hasEmailPasswordLinked;
    final providers = authNotifier.linkedProviders;

    return _buildSection(
      title: 'Settings',
      children: [
        // Show linked providers
        _buildMenuItem(
          icon: LucideIcons.link,
          title: 'Linked Accounts',
          trailing: Text(
            providers.isNotEmpty ? providers.join(', ') : 'None',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        // Add Password option for users who don't have it
        if (!hasPassword)
          _buildMenuItem(
            icon: LucideIcons.keyRound,
            title: 'Add Password',
            subtitle: 'Enable email login',
            onTap: () => _showAddPasswordDialog(context),
          ),
        _buildMenuItem(
            icon: LucideIcons.bell, title: 'Notifications', onTap: () {}),
        _buildMenuItem(
          icon: LucideIcons.refreshCw,
          title: 'Redo Onboarding',
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Redo Onboarding?'),
                content: const Text(
                    'This will let you choose your role and profile data again.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Redo'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              await ref.read(authProvider.notifier).resetOnboarding();
            }
          },
        ),
        _buildMenuItem(
            icon: LucideIcons.globe,
            title: 'Language',
            trailing:
                Text('English', style: TextStyle(color: Colors.grey[600])),
            onTap: () {}),
        _buildMenuItem(
            icon: LucideIcons.helpCircle,
            title: 'Help & Support',
            onTap: () {}),
        _buildMenuItem(
            icon: LucideIcons.fileText,
            title: 'Terms of Service',
            onTap: () {}),
        _buildMenuItem(
            icon: LucideIcons.shield, title: 'Privacy Policy', onTap: () {}),
      ],
    );
  }

  Widget _buildSignOutSection(ThemeData theme) {
    return _buildSection(
      children: [
        _buildMenuItem(
          icon: LucideIcons.logOut,
          title: 'Sign Out',
          titleColor: Colors.red,
          onTap: () async => await ref.read(authProvider.notifier).signOut(),
        ),
      ],
    );
  }

  Widget _buildVersionInfo() {
    return Center(
      child: Text('Quickfit v1.0.0',
          style: TextStyle(color: Colors.grey[400], fontSize: 12)),
    );
  }

  Widget _buildHeader(
      BuildContext context, AuthState authState, AppColors colors) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: colors.divider),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _showAccountSwitcher(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        authState.role == 'studio'
                            ? 'Studio Account'
                            : 'Instructor Profile',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.chevronDown,
                          size: 16, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.settings),
                onPressed: () {
                  // Settings logic
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: authState.user?.photoURL != null
                    ? NetworkImage(authState.user!.photoURL!)
                    : null,
                child: authState.user?.photoURL == null
                    ? Icon(LucideIcons.user,
                        size: 40, color: theme.colorScheme.onPrimaryContainer)
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authState.user?.displayName ?? 'Anonymous User',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      authState.user?.email ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAccountSwitcher(BuildContext context) {
    final colors = context.colors;
    final authState = ref.read(authProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildAccountItem(
              context,
              name: authState.user?.displayName ?? 'Current Account',
              email: authState.user?.email ?? '',
              isSelected: true,
              onTap: () => Navigator.pop(context),
            ),
            _buildAccountItem(
              context,
              name: 'Add Account',
              icon: LucideIcons.plus,
              isSelected: false,
              onTap: () {
                Navigator.pop(context);
                // Trigger add account flow
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountItem(
    BuildContext context, {
    required String name,
    String? email,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: icon != null
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        child: icon != null
            ? Icon(icon, size: 20, color: theme.colorScheme.onSurface)
            : Text(name[0],
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: email != null ? Text(email) : null,
      trailing: isSelected
          ? Icon(LucideIcons.checkCircle2, color: theme.colorScheme.primary)
          : null,
    );
  }

  Widget _buildVerificationCard(BuildContext context, bool isVerified) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isVerified ? Colors.green[100] : Colors.orange[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVerified ? LucideIcons.badgeCheck : LucideIcons.alertCircle,
              color: isVerified ? Colors.green[700] : Colors.orange[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? 'Verified Instructor' : 'Verification Pending',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isVerified ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isVerified
                      ? 'Your credentials have been verified'
                      : 'Upload your certification to get verified',
                  style: TextStyle(
                    fontSize: 12,
                    color: isVerified ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
          if (!isVerified)
            TextButton(
              onPressed: () => context.push(AppRoutes.verification),
              child: const Text('Verify'),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    String? title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[100]!),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: titleColor ?? Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      color: titleColor ?? Colors.black87,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (onTap != null && trailing == null)
              Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /// Show dialog to add password for Google-only users.
  Future<void> _showAddPasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final authState = ref.read(authProvider);
    final email = authState.user?.email ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a password to allow signing in with email ($email)',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(LucideIcons.lock),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(LucideIcons.lock),
                ),
                validator: (value) {
                  if (value != passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add Password'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(authProvider.notifier).linkEmailPassword(
            email: email,
            password: passwordController.text,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Password added! You can now sign in with email.'
                : 'Failed to add password',
          ),
        ),
      );
      if (success) {
        setState(() {}); // Refresh UI
      }
    }

    passwordController.dispose();
    confirmController.dispose();
  }
}
