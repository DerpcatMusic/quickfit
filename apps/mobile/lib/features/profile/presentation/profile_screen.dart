import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:quickfit/core/constants/app_constants.dart';
import 'package:quickfit/core/constants/categories.dart';
import 'package:quickfit/core/providers/settings_provider.dart';
import 'package:quickfit/core/router/app_routes.dart';
import 'package:quickfit/core/services/convex_service.dart';
import 'package:quickfit/core/services/location_service.dart';
import 'package:quickfit/core/services/notification_service.dart';
import 'package:quickfit/core/services/settings_service.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/core/utils/platform.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/features/profile/presentation/models/profile_settings_draft.dart';
import 'package:quickfit/features/profile/presentation/widgets/profile_primitives.dart';
import 'package:quickfit/features/jobs/providers/studio_jobs_provider.dart';
import 'package:quickfit/l10n/app_localizations.dart';
import 'package:quickfit/shared/widgets/studio_billing_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  Set<String> _selectedCategories = <String>{};
  double _radiusKm = AppConstants.defaultRadiusKm;
  double? _lat;
  double? _lng;
  String _resolvedAddress = '';
  ProfileSettingsDraft _settingsDraft = ProfileSettingsDraft.defaults();
  String? _authFingerprint;
  bool _isBillingLoading = false;
  bool _billingLoaded = false;
  List<Map<String, dynamic>> _billingIntegrations = const [];
  bool _isStudioPricingLoading = false;
  bool _studioPricingLoaded = false;
  double _studioDefaultBaseRate = 120;
  List<Map<String, dynamic>> _studioLeadTimeRules = const [
    {'maxHoursBeforeStart': 6.0, 'boostPercent': 10.0},
    {'maxHoursBeforeStart': 3.0, 'boostPercent': 15.0},
  ];

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();

    _hydrateFromAuth(ref.read(authProvider), force: true);
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _disposeTransientController(TextEditingController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  bool _shouldClearDraftLocationForAddressInput({
    required String input,
    required String resolvedAddress,
  }) {
    final typed = input.trim();
    final resolved = resolvedAddress.trim();
    if (typed.isEmpty) return true;
    if (resolved.isEmpty) return false;
    return typed != resolved;
  }

  void _hydrateFromAuth(AuthState authState, {bool force = false}) {
    final fingerprint = [
      authState.user?.uid ?? '',
      authState.name ?? '',
      authState.user?.displayName ?? '',
      authState.phone ?? '',
      authState.homeAddress ?? '',
      authState.radiusKm?.toString() ?? '',
      (authState.categories ?? const <String>[]).join(','),
      authState.latitude?.toString() ?? '',
      authState.longitude?.toString() ?? '',
    ].join('|');

    if (!force) {
      if (_isEditing) return;
      if (_authFingerprint == fingerprint) return;
    }

    _authFingerprint = fingerprint;
    _nameController.text = authState.name ?? authState.user?.displayName ?? '';
    _phoneController.text = authState.phone ?? '';
    final normalizedAddress = (authState.homeAddress ?? '').trim();
    _addressController.text = normalizedAddress;
    _selectedCategories =
        Set<String>.from(authState.categories ?? const <String>[]);
    _radiusKm = authState.radiusKm ?? AppConstants.defaultRadiusKm;
    _lat = authState.latitude;
    _lng = authState.longitude;
    _resolvedAddress =
        normalizedAddress.isNotEmpty && _lat != null && _lng != null
            ? normalizedAddress
            : '';
  }

  Future<void> _loadSettings() async {
    final cached = ref.read(settingsProvider).value;
    final loaded = cached ?? await SettingsService.instance.load();
    final auth = ref.read(authProvider);
    final merged = loaded.copyWith(
      notificationsEnabled:
          auth.notificationsEnabled ?? loaded.notificationsEnabled,
      regularJobAlerts: auth.regularJobAlerts ?? loaded.regularJobAlerts,
      sosJobAlerts: auth.sosJobAlerts ?? loaded.sosJobAlerts,
      languageCode: auth.languageCode ?? loaded.languageCode,
    );
    final changedFromLocal =
        merged.notificationsEnabled != loaded.notificationsEnabled ||
            merged.regularJobAlerts != loaded.regularJobAlerts ||
            merged.sosJobAlerts != loaded.sosJobAlerts ||
            merged.languageCode != loaded.languageCode;
    if (changedFromLocal) {
      await ref.read(settingsProvider.notifier).saveSettings(merged);
      await NotificationService.instance.applySettings(merged);
    }
    if (!mounted) return;
    setState(() {
      _settingsDraft = ProfileSettingsDraft.fromSettings(merged);
    });
  }

  Future<void> _loadBillingIntegrations() async {
    if (_isBillingLoading) return;
    setState(() => _isBillingLoading = true);
    try {
      final rows = await ConvexService.instance.getMyInvoicingIntegrations();
      if (!mounted) return;
      setState(() {
        _billingIntegrations = rows;
        _billingLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      // Avoid repeated timeout loops on every rebuild; user can still open
      // billing sheet to retry explicitly.
      setState(() {
        _billingIntegrations = const [];
        _billingLoaded = true;
      });
    } finally {
      if (mounted) setState(() => _isBillingLoading = false);
    }
  }

  String _billingSummaryText() {
    return StudioBillingSheet.summaryFromIntegrations(_billingIntegrations);
  }

  Future<void> _openStudioBillingSheet() async {
    await StudioBillingSheet.show(
      context,
      onUpdated: _loadBillingIntegrations,
    );
  }

  List<Map<String, dynamic>> _normalizeStudioPricingRules(
    List<Map<String, dynamic>> rules,
  ) {
    final normalized = rules
        .map((rule) => {
              'maxHoursBeforeStart':
                  ((rule['maxHoursBeforeStart'] as num?) ?? 0).toDouble(),
              'boostPercent': ((rule['boostPercent'] as num?) ?? 0).toDouble(),
            })
        .where((rule) => rule['maxHoursBeforeStart']! > 0)
        .toList(growable: false)
      ..sort((a, b) => a['maxHoursBeforeStart']!.compareTo(
            b['maxHoursBeforeStart']!,
          ));
    if (normalized.isEmpty) {
      return const [
        {'maxHoursBeforeStart': 6.0, 'boostPercent': 10.0},
        {'maxHoursBeforeStart': 3.0, 'boostPercent': 15.0},
      ];
    }
    return normalized.take(3).toList(growable: false);
  }

  Future<void> _loadStudioPricingSettings() async {
    if (_isStudioPricingLoading) return;
    setState(() => _isStudioPricingLoading = true);
    try {
      final payload = await ConvexService.instance.getMyStudioPricingSettings();
      if (!mounted) return;
      if (payload == null) {
        setState(() {
          _studioPricingLoaded = true;
        });
        return;
      }
      final defaultBaseRate =
          (payload['defaultBaseRate'] as num?)?.toDouble() ?? 120;
      final rules = ((payload['leadTimeSurgeRules'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
      setState(() {
        _studioDefaultBaseRate = defaultBaseRate;
        _studioLeadTimeRules = _normalizeStudioPricingRules(rules);
        _studioPricingLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _studioPricingLoaded = true;
      });
    } finally {
      if (mounted) setState(() => _isStudioPricingLoading = false);
    }
  }

  String _studioPricingSummaryText() {
    final compactRules = _studioLeadTimeRules
        .map((rule) {
          final hours = ((rule['maxHoursBeforeStart'] as num?) ?? 0).round();
          final boost = ((rule['boostPercent'] as num?) ?? 0).round();
          return _l10n.profileStudioPricingRuleCompact(hours, boost);
        })
        .join(', ');
    return _l10n.profileStudioPricingSummary(
      _studioDefaultBaseRate.toStringAsFixed(0),
      compactRules,
    );
  }

  Future<void> _openStudioPricingSheet() async {
    final defaultRateController = TextEditingController(
      text: _studioDefaultBaseRate.toStringAsFixed(0),
    );
    var rulesDraft = _studioLeadTimeRules
        .map((rule) => Map<String, dynamic>.from(rule))
        .toList(growable: true);
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.profileStudioPricingTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: defaultRateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _l10n.profileStudioPricingDefaultRate,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < rulesDraft.length; i++) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _l10n.profileStudioPricingRuleHours,
                        ),
                        initialValue:
                            ((rulesDraft[i]['maxHoursBeforeStart'] as num?) ?? 0)
                                .toStringAsFixed(1),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed == null) return;
                          rulesDraft[i]['maxHoursBeforeStart'] = parsed;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _l10n.profileStudioPricingRuleBoost,
                        ),
                        initialValue:
                            ((rulesDraft[i]['boostPercent'] as num?) ?? 0)
                                .toStringAsFixed(0),
                        onChanged: (value) {
                          final parsed = double.tryParse(value);
                          if (parsed == null) return;
                          rulesDraft[i]['boostPercent'] = parsed;
                        },
                      ),
                    ),
                    if (rulesDraft.length > 1)
                      IconButton(
                        onPressed: isSaving
                            ? null
                            : () => setSheetState(() {
                                  rulesDraft.removeAt(i);
                                }),
                        icon: const Icon(LucideIcons.trash2, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (rulesDraft.length < 3)
                OutlinedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () => setSheetState(() {
                            rulesDraft.add({
                              'maxHoursBeforeStart': 2.0,
                              'boostPercent': 10.0,
                            });
                          }),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: Text(_l10n.profileStudioPricingAddRule),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final parsedRate =
                              double.tryParse(defaultRateController.text.trim());
                          if (parsedRate == null || parsedRate <= 0) return;
                          final messenger = ScaffoldMessenger.of(this.context);
                          final navigator = Navigator.of(context);
                          final errorColor =
                              Theme.of(this.context).colorScheme.error;
                          setSheetState(() => isSaving = true);
                          try {
                            final normalizedRules =
                                _normalizeStudioPricingRules(rulesDraft);
                            await ConvexService.instance.setMyStudioPricingSettings(
                              defaultBaseRate: parsedRate,
                              leadTimeSurgeRules: normalizedRules,
                            );
                            if (!mounted) return;
                            setState(() {
                              _studioDefaultBaseRate = parsedRate;
                              _studioLeadTimeRules = normalizedRules;
                              _studioPricingLoaded = true;
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content:
                                    Text(_l10n.profileStudioPricingSaved),
                              ),
                            );
                            navigator.pop();
                          } catch (_) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  _l10n.profileStudioPricingSaveFailed,
                                ),
                                backgroundColor: errorColor,
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setSheetState(() => isSaving = false);
                            }
                          }
                        },
                  child: Text(
                    isSaving ? _l10n.saving : _l10n.save,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startEditing() async {
    setState(() {
      _isEditing = true;
      _authFingerprint = null;
    });
  }

  Future<void> _cancelEditing(AuthState authState) async {
    _hydrateFromAuth(authState, force: true);
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _saveProfile() async {
    final authState = ref.read(authProvider);
    final address = _addressController.text.trim();
    final nextLat = _lat;
    final nextLng = _lng;

    final success = await _submitProfileUpdate(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: address,
      latitude: nextLat,
      longitude: nextLng,
      radiusKm: authState.role == 'instructor' ? _radiusKm : null,
      categories: _selectedCategories.toList(),
    );
    if (!mounted || !success) return;
    setState(() {
      _lat = nextLat;
      _lng = nextLng;
      _resolvedAddress =
          address.isNotEmpty && nextLat != null && nextLng != null
              ? address
              : '';
      _isEditing = false;
    });

    // Keep profile save responsive: if we don't have coordinates yet, resolve
    // address in the background and patch location once available.
    unawaited(_backfillAddressCoordinatesIfNeeded(address));
  }

  Future<void> _backfillAddressCoordinatesIfNeeded(String address) async {
    final trimmedAddress = address.trim();
    if (trimmedAddress.isEmpty) return;
    if (_lat != null && _lng != null) return;

    try {
      final pos = await LocationService.instance
          .getLatLngFromAddress(trimmedAddress)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (pos == null) return;

      final updated = await ref.read(authProvider.notifier).updateProfile(
            address: trimmedAddress,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      if (!mounted || !updated) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _resolvedAddress = trimmedAddress;
      });
    } catch (_) {
      // Best-effort enrichment; keep save UX unaffected on network issues.
    }
  }

  Future<bool> _submitProfileUpdate({
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    double? radiusKm,
    List<String>? categories,
  }) async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);
    try {
      final success = await ref.read(authProvider.notifier).updateProfile(
            name: name,
            phone: phone,
            address: address,
            latitude: latitude,
            longitude: longitude,
            radiusKm: radiusKm,
            categories: categories,
          );

      if (!mounted) return success;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.profileUpdated)),
        );
        return true;
      }

      final errorText =
          ref.read(authProvider).error ?? _l10n.somethingWentWrong;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorText),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final studioJobsState = ref.watch(studioJobsProvider);
    _hydrateFromAuth(authState);
    if (authState.role == 'studio' && !_billingLoaded && !_isBillingLoading) {
      unawaited(_loadBillingIntegrations());
    }
    if (authState.role == 'studio' &&
        !_studioPricingLoaded &&
        !_isStudioPricingLoading) {
      unawaited(_loadStudioPricingSettings());
    }

    final theme = Theme.of(context);
    final colors = context.colors;
    final studioActiveJobsCount =
        authState.role == 'studio' ? studioJobsState.activeJobs.length : 0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.07),
              theme.colorScheme.surface,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeaderCard(authState, colors),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isEditing)
                    _buildEditForm(theme, authState)
                  else ...[
                    if (authState.role == 'instructor') ...[
                      _buildVerificationCard(authState.isVerified),
                      const SizedBox(height: 16),
                    ],
                    _buildAccountSection(authState),
                    const SizedBox(height: 16),
                    _buildCategoriesSection(authState),
                    const SizedBox(height: 16),
                    _buildSettingsSection(
                      authState,
                      studioActiveJobsCount: studioActiveJobsCount,
                    ),
                    const SizedBox(height: 16),
                    _buildSignOutSection(),
                    const SizedBox(height: 28),
                    _buildVersionInfo(),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isEditing ? _buildSaveBar(theme, authState) : null,
    );
  }

  Widget _buildHeaderCard(AuthState authState, AppColors colors) {
    final theme = Theme.of(context);
    final role = authState.role == 'studio'
        ? _l10n.profileRoleStudio
        : _l10n.profileRoleInstructor;
    final resolvedName =
        (authState.name ?? authState.user?.displayName ?? '').trim();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.cardBorder),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surfaceContainerHighest,
                theme.colorScheme.surfaceContainer,
              ],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      role,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: _showNotificationSettings,
                    icon: const Icon(LucideIcons.bell, size: 18),
                    tooltip: _l10n.notifications,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: authState.user?.photoURL != null
                        ? NetworkImage(authState.user!.photoURL!)
                        : null,
                    child: authState.user?.photoURL == null
                        ? Icon(
                            LucideIcons.user,
                            size: 36,
                            color: theme.colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolvedName.isNotEmpty
                              ? resolvedName
                              : _l10n.profileAnonymousUser,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authState.user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _isEditing
                        ? OutlinedButton.icon(
                            onPressed: () => _cancelEditing(authState),
                            icon: const Icon(LucideIcons.x, size: 16),
                            label: Text(_l10n.cancel),
                          )
                        : FilledButton.icon(
                            onPressed: _startEditing,
                            icon: const Icon(LucideIcons.pencil, size: 16),
                            label: Text(_l10n.editProfile),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showLanguagePicker,
                      icon: const Icon(LucideIcons.globe, size: 16),
                      label: Text(_languageLabel()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditForm(ThemeData theme, AuthState authState) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final isCupertino = isCupertinoPlatform(context);
    final isInstructor = authState.role == 'instructor';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionCard(
          title: _l10n.profileInfo,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _l10n.displayNameLabel,
                      prefixIcon: const Icon(LucideIcons.user),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: _l10n.phoneNumber,
                      prefixIcon: const Icon(LucideIcons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TypeAheadField<Map<String, dynamic>>(
                    controller: _addressController,
                    builder: (context, controller, focusNode) => TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: _l10n.homeAddress,
                        prefixIcon: const Icon(LucideIcons.mapPin),
                        hintMaxLines: 2,
                      ),
                      onChanged: (value) {
                        if (_shouldClearDraftLocationForAddressInput(
                          input: value,
                          resolvedAddress: _resolvedAddress,
                        )) {
                          _lat = null;
                          _lng = null;
                        }
                      },
                    ),
                    suggestionsCallback: (pattern) async {
                      return LocationService.instance
                          .getAutocompleteSuggestions(pattern);
                    },
                    itemBuilder: (context, suggestion) {
                      return ListTile(
                        leading: const Icon(LucideIcons.mapPin, size: 18),
                        title: Text(
                          (suggestion['label'] ??
                                  suggestion['description'] ??
                                  '')
                              .toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                    onSelected: (suggestion) {
                      final address = ((suggestion['label'] ??
                                  suggestion['description'] ??
                                  '')
                              .toString())
                          .trim();
                      _addressController.text = address;
                      final suggestionLat =
                          (suggestion['lat'] as num?)?.toDouble();
                      final suggestionLng =
                          (suggestion['lng'] as num?)?.toDouble();
                      if (suggestionLat != null && suggestionLng != null) {
                        _lat = suggestionLat;
                        _lng = suggestionLng;
                        _resolvedAddress = address;
                      } else {
                        _lat = null;
                        _lng = null;
                        _resolvedAddress = '';
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isInstructor) ...[
          ProfileSectionCard(
            title: _l10n.searchRadius,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _l10n.maximumDistance,
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          _l10n.radiusKmLabel(_radiusKm.toStringAsFixed(1)),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    isCupertino
                        ? CupertinoSlider(
                            value: _radiusKm.clamp(0.1, 15.0),
                            min: 0.1,
                            max: 15.0,
                            divisions: 149,
                            onChanged: (value) =>
                                setState(() => _radiusKm = value),
                          )
                        : Slider(
                            value: _radiusKm.clamp(0.1, 15.0),
                            min: 0.1,
                            max: 15.0,
                            divisions: 149,
                            onChanged: (value) =>
                                setState(() => _radiusKm = value),
                          ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        ProfileSectionCard(
          title: _l10n.expertise,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FitnessCategory.values.map((cat) {
                  final isSelected = _selectedCategories.contains(cat.id);
                  return FilterChip(
                    label: Text(cat.displayNameWithEmoji(localeCode)),
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
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveBar(ThemeData theme, AuthState authState) {
    final isCupertino = isCupertinoPlatform(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: isCupertino
                  ? CupertinoButton(
                      onPressed:
                          _isSaving ? null : () => _cancelEditing(authState),
                      color: CupertinoColors.systemGrey4,
                      child: Text(_l10n.cancel),
                    )
                  : OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => _cancelEditing(authState),
                      child: Text(_l10n.cancel),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isCupertino
                  ? CupertinoButton.filled(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_l10n.saveChanges),
                    )
                  : FilledButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_l10n.saveChanges),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(AuthState authState) {
    final resolvedName =
        (authState.name ?? authState.user?.displayName ?? '').trim();
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (resolvedName.isNotEmpty ? resolvedName : _l10n.notSet);
    final email = (authState.user?.email ?? '').trim();
    final phone = (authState.phone ?? '').trim();
    final address = _addressController.text.trim().isNotEmpty
        ? _addressController.text.trim()
        : ((authState.homeAddress ?? '').trim().isNotEmpty
            ? authState.homeAddress!
            : _l10n.notSet);

    final entries = <_AccountEntry>[
      _AccountEntry(
        icon: LucideIcons.user,
        title: _l10n.displayNameLabel,
        value: displayName,
        onTap: _isSaving ? null : _editDisplayName,
      ),
      _AccountEntry(
        icon: LucideIcons.mail,
        title: _l10n.email,
        value: email.isNotEmpty ? email : _l10n.notSet,
        onTap: () => _showEmailActions(authState),
      ),
      if (phone.isNotEmpty)
        _AccountEntry(
          icon: LucideIcons.phone,
          title: _l10n.phoneNumber,
          value: phone,
        ),
      _AccountEntry(
        icon: LucideIcons.mapPin,
        title: _l10n.homeAddress,
        value: address,
        onTap: _isSaving ? null : _editAddress,
      ),
      if (authState.role == 'instructor')
        _AccountEntry(
          icon: LucideIcons.mapPin,
          title: _l10n.workRadius,
          value: _l10n.radiusKmLabel(_radiusKm.toStringAsFixed(1)),
          onTap: _isSaving ? null : _editRadius,
        ),
    ];

    return ProfileSectionCard(
      title: _l10n.account,
      children: [
        for (var i = 0; i < entries.length; i++)
          ProfileTile(
            icon: entries[i].icon,
            title: entries[i].title,
            trailing: _buildTrailingText(
              entries[i].value,
              isActionable: entries[i].onTap != null,
            ),
            onTap: entries[i].onTap,
            showDivider: i != entries.length - 1,
          ),
      ],
    );
  }

  Future<void> _editDisplayName() async {
    final nextName = await _showTextInputEditor(
      title: _l10n.displayNameLabel,
      initialValue: _nameController.text.trim(),
      keyboardType: TextInputType.name,
      validator: (value) {
        if (value.trim().isEmpty) return _nameRequiredMessage();
        return null;
      },
    );
    if (nextName == null) return;

    final success = await _submitProfileUpdate(name: nextName);
    if (!mounted || !success) return;
    setState(() {
      _nameController.text = nextName;
      _authFingerprint = null;
    });
  }

  Future<void> _editAddress() async {
    final draft = await _showAddressEditor(
      initialAddress: _addressController.text.trim(),
      initialLat: _lat,
      initialLng: _lng,
    );
    if (draft == null) return;

    final success = await _submitProfileUpdate(
      address: draft.address,
      latitude: draft.latitude,
      longitude: draft.longitude,
    );
    if (!mounted || !success) return;
    setState(() {
      _addressController.text = draft.address;
      if (draft.latitude != null && draft.longitude != null) {
        _lat = draft.latitude;
        _lng = draft.longitude;
      }
      _resolvedAddress =
          draft.address.isNotEmpty && _lat != null && _lng != null
              ? draft.address
              : '';
      _authFingerprint = null;
    });
  }

  Future<void> _editRadius() async {
    if (ref.read(authProvider).role != 'instructor') return;
    final isCupertino = isCupertinoPlatform(context);
    var radiusDraft = _radiusKm.clamp(0.1, 15.0);

    Future<void> save() async {
      final success = await _submitProfileUpdate(radiusKm: radiusDraft);
      if (!mounted || !success) return;
      setState(() => _radiusKm = radiusDraft);
      Navigator.pop(context);
    }

    if (isCupertino) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => CupertinoPopupSurface(
          child: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (context, setSheetState) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _l10n.workRadius,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_l10n.radiusKmLabel(radiusDraft.toStringAsFixed(1))),
                    CupertinoSlider(
                      value: radiusDraft,
                      min: 0.1,
                      max: 15.0,
                      divisions: 149,
                      onChanged: _isSaving
                          ? null
                          : (value) => setSheetState(() => radiusDraft = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            onPressed:
                                _isSaving ? null : () => Navigator.pop(context),
                            color: CupertinoColors.systemGrey4,
                            child: Text(_l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CupertinoButton.filled(
                            onPressed: _isSaving ? null : save,
                            child: Text(_l10n.save),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.workRadius,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_l10n.radiusKmLabel(radiusDraft.toStringAsFixed(1))),
              Slider(
                value: radiusDraft,
                min: 0.1,
                max: 15.0,
                divisions: 149,
                onChanged: _isSaving
                    ? null
                    : (value) => setSheetState(() => radiusDraft = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: Text(_l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : save,
                      child: Text(_l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEmailActions(AuthState authState) async {
    final email = (authState.user?.email ?? '').trim();
    final providers =
        (authState.user?.providerData ?? const <firebase_auth.UserInfo>[])
            .map((p) => _providerLabel(p.providerId))
            .where((label) => label.isNotEmpty)
            .toList();
    final hasPassword =
        authState.user?.providerData.any((p) => p.providerId == 'password') ??
            false;
    final providersLabel = providers.isNotEmpty
        ? providers.join(', ')
        : _l10n.profileProviderOauth;
    final body = _emailEditMessage(
      providersLabel: providersLabel,
      hasPassword: hasPassword,
    );
    final isCupertino = isCupertinoPlatform(context);

    if (isCupertino) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => CupertinoPopupSurface(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _l10n.email,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(email.isNotEmpty ? email : _l10n.notSet),
                  const SizedBox(height: 8),
                  Text(body, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  if (!hasPassword) ...[
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: () async {
                          Navigator.pop(context);
                          if (!mounted) return;
                          await _showAddPasswordDialog();
                        },
                        child: Text(_l10n.addPassword),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (!mounted) return;
                        await _showChangeEmailDialog(authState);
                      },
                      child: Text(_l10n.changeEmail),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_l10n.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _l10n.email,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(email.isNotEmpty ? email : _l10n.notSet),
            const SizedBox(height: 8),
            Text(body),
            const SizedBox(height: 12),
            if (!hasPassword) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (!mounted) return;
                    await _showAddPasswordDialog();
                  },
                  child: Text(_l10n.addPassword),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () async {
                  Navigator.pop(context);
                  if (!mounted) return;
                  await _showChangeEmailDialog(authState);
                },
                child: Text(_l10n.changeEmail),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeEmailDialog(AuthState authState) async {
    final currentEmail = (authState.user?.email ?? '').trim();
    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();
    final hasPassword =
        authState.user?.providerData.any((p) => p.providerId == 'password') ??
            false;

    final isCupertino = isCupertinoPlatform(context);
    final confirmed = await (isCupertino
        ? showCupertinoDialog<bool>(
            context: context,
            builder: (context) {
              String? errorText;
              return StatefulBuilder(
                builder: (context, setSheetState) => CupertinoAlertDialog(
                  title: Text(_l10n.changeEmail),
                  content: Column(
                    children: [
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: newEmailController,
                        placeholder: _l10n.newEmailLabel,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      if (hasPassword) ...[
                        const SizedBox(height: 8),
                        CupertinoTextField(
                          controller: passwordController,
                          placeholder: _l10n.currentPasswordLabel,
                          obscureText: true,
                        ),
                      ],
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: const TextStyle(
                            color: CupertinoColors.systemRed,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(_l10n.cancel),
                    ),
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      onPressed: () {
                        final next = newEmailController.text.trim();
                        if (next.isEmpty || !next.contains('@')) {
                          setSheetState(() => errorText = _l10n.emailInvalid);
                          return;
                        }
                        if (next.toLowerCase() == currentEmail.toLowerCase()) {
                          setSheetState(() => errorText = _l10n.emailUnchanged);
                          return;
                        }
                        if (hasPassword &&
                            passwordController.text.trim().isEmpty) {
                          setSheetState(
                              () => errorText = _l10n.currentPasswordRequired);
                          return;
                        }
                        Navigator.pop(context, true);
                      },
                      child: Text(_l10n.sendVerification),
                    ),
                  ],
                ),
              );
            },
          )
        : showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(_l10n.changeEmail),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: _l10n.newEmailLabel,
                      prefixIcon: const Icon(LucideIcons.mail),
                    ),
                  ),
                  if (hasPassword) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: _l10n.currentPasswordLabel,
                        prefixIcon: const Icon(LucideIcons.lock),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final next = newEmailController.text.trim();
                    if (next.isEmpty ||
                        !next.contains('@') ||
                        next.toLowerCase() == currentEmail.toLowerCase() ||
                        (hasPassword &&
                            passwordController.text.trim().isEmpty)) {
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: Text(_l10n.sendVerification),
                ),
              ],
            ),
          ));

    if (confirmed == true) {
      final success =
          await ref.read(authProvider.notifier).requestEmailChangeVerification(
                newEmail: newEmailController.text.trim(),
                currentPassword:
                    hasPassword ? passwordController.text.trim() : null,
              );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.emailChangeVerificationSent)),
        );
      } else {
        final error = ref.read(authProvider).error ?? _l10n.somethingWentWrong;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }

    newEmailController.dispose();
    passwordController.dispose();
  }

  Future<String?> _showTextInputEditor({
    required String title,
    required String initialValue,
    String? Function(String value)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? errorText;
    final isCupertino = isCupertinoPlatform(context);

    Future<void> submit(StateSetter setSheetState) async {
      final value = controller.text.trim();
      final validation = validator?.call(value);
      if (validation != null) {
        setSheetState(() => errorText = validation);
        return;
      }
      Navigator.pop(context, value);
    }

    final result = await (isCupertino
        ? showCupertinoModalPopup<String>(
            context: context,
            builder: (context) => CupertinoPopupSurface(
              child: SafeArea(
                top: false,
                child: StatefulBuilder(
                  builder: (context, setSheetState) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        CupertinoTextField(
                          controller: controller,
                          keyboardType: keyboardType,
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorText!,
                            style: const TextStyle(
                              color: CupertinoColors.systemRed,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                onPressed: () => Navigator.pop(context),
                                color: CupertinoColors.systemGrey4,
                                child: Text(_l10n.cancel),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CupertinoButton.filled(
                                onPressed: () => submit(setSheetState),
                                child: Text(_l10n.save),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        : showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => StatefulBuilder(
              builder: (context, setSheetState) => Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller,
                      keyboardType: keyboardType,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(_l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => submit(setSheetState),
                            child: Text(_l10n.save),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ));

    _disposeTransientController(controller);
    if (result == null) return null;
    return result.trim();
  }

  Future<_AddressEditResult?> _showAddressEditor({
    required String initialAddress,
    required double? initialLat,
    required double? initialLng,
  }) async {
    final controller = TextEditingController(text: initialAddress);
    var latDraft = initialLat;
    var lngDraft = initialLng;
    var resolvedAddress = initialAddress.trim();
    var isResolving = false;
    final isCupertino = isCupertinoPlatform(context);

    Future<void> submit(StateSetter setSheetState) async {
      final value = controller.text.trim();
      if (value.isEmpty) {
        Navigator.pop(
          context,
          const _AddressEditResult(
              address: '', latitude: null, longitude: null),
        );
        return;
      }

      if (value != resolvedAddress) {
        setSheetState(() => isResolving = true);
        final pos = await LocationService.instance.getLatLngFromAddress(value);
        if (pos != null) {
          latDraft = pos.latitude;
          lngDraft = pos.longitude;
          resolvedAddress = value;
        }
        if (!mounted) return;
        setSheetState(() => isResolving = false);
      }

      Navigator.pop(
        context,
        _AddressEditResult(
          address: value,
          latitude: latDraft,
          longitude: lngDraft,
        ),
      );
    }

    final result = await (isCupertino
        ? showCupertinoModalPopup<_AddressEditResult>(
            context: context,
            builder: (context) => CupertinoPopupSurface(
              child: SafeArea(
                top: false,
                child: StatefulBuilder(
                  builder: (context, setSheetState) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _l10n.homeAddress,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TypeAheadField<Map<String, dynamic>>(
                            controller: controller,
                            builder: (context, controller, focusNode) =>
                                TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration:
                                  InputDecoration(labelText: _l10n.homeAddress),
                              onChanged: (value) {
                                if (value.trim() != resolvedAddress) {
                                  latDraft = null;
                                  lngDraft = null;
                                }
                              },
                            ),
                            suggestionsCallback: (pattern) async {
                              return LocationService.instance
                                  .getAutocompleteSuggestions(pattern);
                            },
                            itemBuilder: (context, suggestion) {
                              return ListTile(
                                leading:
                                    const Icon(LucideIcons.mapPin, size: 18),
                                title: Text(
                                  (suggestion['label'] ??
                                          suggestion['description'] ??
                                          '')
                                      .toString(),
                                ),
                              );
                            },
                            onSelected: (suggestion) async {
                              final address = (suggestion['label'] ??
                                      suggestion['description'] ??
                                      '')
                                  .toString()
                                  .trim();
                              controller.text = address;
                              final pos = await LocationService.instance
                                  .getLatLngFromAddress(
                                address,
                              );
                              if (pos != null) {
                                latDraft = pos.latitude;
                                lngDraft = pos.longitude;
                                resolvedAddress = address;
                              }
                            },
                          ),
                          if (isResolving) ...[
                            const SizedBox(height: 8),
                            const CupertinoActivityIndicator(),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  onPressed: () => Navigator.pop(context),
                                  color: CupertinoColors.systemGrey4,
                                  child: Text(_l10n.cancel),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CupertinoButton.filled(
                                  onPressed: isResolving
                                      ? null
                                      : () => submit(setSheetState),
                                  child: Text(_l10n.save),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : showModalBottomSheet<_AddressEditResult>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => StatefulBuilder(
              builder: (context, setSheetState) => Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _l10n.homeAddress,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TypeAheadField<Map<String, dynamic>>(
                        controller: controller,
                        builder: (context, controller, focusNode) =>
                            TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration:
                              InputDecoration(labelText: _l10n.homeAddress),
                          onChanged: (value) {
                            if (value.trim() != resolvedAddress) {
                              latDraft = null;
                              lngDraft = null;
                            }
                          },
                        ),
                        suggestionsCallback: (pattern) async {
                          return LocationService.instance
                              .getAutocompleteSuggestions(pattern);
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(
                            leading: const Icon(LucideIcons.mapPin, size: 18),
                            title: Text(
                              (suggestion['label'] ??
                                      suggestion['description'] ??
                                      '')
                                  .toString(),
                            ),
                          );
                        },
                        onSelected: (suggestion) async {
                          final address = (suggestion['label'] ??
                                  suggestion['description'] ??
                                  '')
                              .toString()
                              .trim();
                          controller.text = address;
                          final pos = await LocationService.instance
                              .getLatLngFromAddress(
                            address,
                          );
                          if (pos != null) {
                            latDraft = pos.latitude;
                            lngDraft = pos.longitude;
                            resolvedAddress = address;
                          }
                        },
                      ),
                      if (isResolving) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(_l10n.cancel),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: isResolving
                                  ? null
                                  : () => submit(setSheetState),
                              child: Text(_l10n.save),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ));

    _disposeTransientController(controller);
    return result;
  }

  String _emailEditMessage({
    required String providersLabel,
    required bool hasPassword,
  }) {
    if (hasPassword) {
      return _l10n.profileEmailManagedByProvider(providersLabel);
    }
    return _l10n.profileEmailManagedByProviderWithFallback(providersLabel);
  }

  String _nameRequiredMessage() {
    return _l10n.profileDisplayNameRequired;
  }

  Widget _buildCategoriesSection(AuthState authState) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final selected = (authState.categories ?? const <String>[])
        .map(FitnessCategory.fromId)
        .whereType<FitnessCategory>()
        .toList();

    return ProfileSectionCard(
      title: authState.role == 'instructor'
          ? _l10n.teachingCategories
          : _l10n.classTypes,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: selected.isEmpty
              ? Text(
                  _l10n.notSet,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.mutedText,
                      ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selected
                      .map(
                        (cat) => ProfileChip(
                          label: cat.displayNameWithEmoji(localeCode),
                          color: cat.color,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(
    AuthState authState, {
    required int studioActiveJobsCount,
  }) {
    final providers =
        (authState.user?.providerData ?? const <firebase_auth.UserInfo>[])
            .map((p) => _providerLabel(p.providerId))
            .where((label) => label.isNotEmpty)
            .toList();
    final hasPassword =
        authState.user?.providerData.any((p) => p.providerId == 'password') ??
            false;

    return ProfileSectionCard(
      title: _l10n.settings,
      children: [
        ProfileTile(
          icon: LucideIcons.link,
          title: _l10n.linkedAccounts,
          trailing: _buildTrailingText(
              providers.isNotEmpty ? providers.join(', ') : _l10n.none),
        ),
        if (!hasPassword)
          ProfileTile(
            icon: LucideIcons.keyRound,
            title: _l10n.addPassword,
            subtitle: _l10n.enableEmailLogin,
            onTap: _showAddPasswordDialog,
          ),
        ProfileTile(
          icon: LucideIcons.bell,
          title: _l10n.notifications,
          trailing: _buildTrailingText(_notificationLabel()),
          onTap: _showNotificationSettings,
        ),
        ProfileTile(
          icon: LucideIcons.globe,
          title: _l10n.language,
          trailing: _buildTrailingText(_languageLabel()),
          onTap: _showLanguagePicker,
        ),
        if (authState.role == 'studio')
          ProfileTile(
            icon: LucideIcons.trendingUp,
            title: _l10n.profileStudioPricingTitle,
            subtitle: _l10n.profileStudioPricingSubtitle,
            trailing: _buildTrailingText(_studioPricingSummaryText()),
            onTap: _openStudioPricingSheet,
          ),
        if (authState.role == 'studio')
          ProfileTile(
            icon: LucideIcons.creditCard,
            title: _l10n.profileStudioBillingTitle,
            subtitle: _l10n.profileStudioBillingSubtitle,
            trailing: _buildTrailingText(_billingSummaryText()),
            onTap: _openStudioBillingSheet,
          ),
        if (authState.role == 'studio' && authState.convexUserId != null)
          ProfileTile(
            icon: LucideIcons.briefcase,
            title: _l10n.profileStudioPublicJobsTitle,
            subtitle: _l10n.profileStudioPublicJobsSubtitle,
            trailing: _buildTrailingText(
              _l10n.profileStudioActiveJobsCount(studioActiveJobsCount),
            ),
            onTap: () => context.push(
              AppRoutes.studioPublicProfile
                  .replaceFirst(':id', authState.convexUserId!),
            ),
          ),
        ProfileTile(
          icon: LucideIcons.refreshCw,
          title: _l10n.redoOnboarding,
          onTap: _confirmRedoOnboarding,
        ),
        ProfileTile(
          icon: LucideIcons.helpCircle,
          title: _l10n.helpSupport,
          onTap: () => _showInfoSheet(
            title: _l10n.helpSupport,
            body: _l10n.supportPlaceholder,
          ),
        ),
        ProfileTile(
          icon: LucideIcons.fileText,
          title: _l10n.termsOfService,
          onTap: () => _showInfoSheet(
            title: _l10n.termsOfService,
            body: _l10n.termsPlaceholder,
          ),
        ),
        ProfileTile(
          icon: LucideIcons.shield,
          title: _l10n.privacyPolicy,
          onTap: () => _showInfoSheet(
            title: _l10n.privacyPolicy,
            body: _l10n.privacyPlaceholder,
          ),
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildSignOutSection() {
    return ProfileSectionCard(
      title: '',
      children: [
        ProfileTile(
          icon: LucideIcons.logOut,
          title: _l10n.signOut,
          danger: true,
          showDivider: false,
          onTap: () async => ref.read(authProvider.notifier).signOut(),
        ),
      ],
    );
  }

  Widget _buildVersionInfo() {
    return Center(
      child: Text(
        _l10n.versionLabel('1.0.0'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colors.mutedText,
            ),
      ),
    );
  }

  Widget _buildVerificationCard(bool isVerified) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final bg = isVerified ? colors.successBackground : colors.urgentBackground;
    final border = isVerified ? colors.successBorder : colors.urgentBorder;
    final fg = isVerified ? colors.successText : colors.urgentText;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isVerified ? LucideIcons.badgeCheck : LucideIcons.alertCircle,
              color: fg,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified
                      ? _l10n.profileVerifiedInstructor
                      : _l10n.verificationPendingTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isVerified
                      ? _l10n.verifiedCredentials
                      : _l10n.uploadCredentials,
                  style: theme.textTheme.bodySmall?.copyWith(color: fg),
                ),
              ],
            ),
          ),
          if (!isVerified)
            TextButton(
              onPressed: () => context.push(AppRoutes.verification),
              child: Text(_l10n.verify),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailingText(
    String text, {
    bool isActionable = false,
  }) {
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

  String _providerLabel(String providerId) {
    switch (providerId) {
      case 'google.com':
        return _l10n.profileProviderGoogle;
      case 'apple.com':
        return _l10n.profileProviderApple;
      case 'password':
        return _l10n.profileProviderEmail;
      default:
        return providerId;
    }
  }

  String _languageLabel() {
    switch (_settingsDraft.languageCode) {
      case 'he':
        return _l10n.languageHebrew;
      case 'en':
      default:
        return _l10n.languageEnglish;
    }
  }

  String _notificationLabel() {
    if (!_settingsDraft.notificationsEnabled) {
      return _l10n.notificationsLabelOff;
    }
    if (_settingsDraft.regularJobAlerts && _settingsDraft.sosJobAlerts) {
      return _l10n.notificationsLabelAll;
    }
    if (_settingsDraft.sosJobAlerts && !_settingsDraft.regularJobAlerts) {
      return _l10n.notificationsLabelSosOnly;
    }
    if (_settingsDraft.regularJobAlerts && !_settingsDraft.sosJobAlerts) {
      return _l10n.notificationsLabelRegularOnly;
    }
    return _l10n.notificationsLabelMuted;
  }

  Future<void> _confirmRedoOnboarding() async {
    final isCupertino = isCupertinoPlatform(context);
    bool? confirmed;
    if (isCupertino) {
      confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text('${_l10n.redoOnboarding}?'),
          content: Text(_l10n.redoOnboardingPrompt),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_l10n.cancel),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              isDestructiveAction: true,
              child: Text(_l10n.redo),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${_l10n.redoOnboarding}?'),
          content: Text(_l10n.redoOnboardingPrompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_l10n.redo),
            ),
          ],
        ),
      );
    }

    if (confirmed == true) {
      final success = await ref.read(authProvider.notifier).resetOnboarding();
      if (!mounted) return;
      if (success) {
        // Let GoRouter redirect based on updated auth state.
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.somethingWentWrong)),
        );
      }
    }
  }

  Future<void> _showNotificationSettings() async {
    final current = await SettingsService.instance.load();
    if (!mounted) return;

    bool enabled = _settingsDraft.notificationsEnabled;
    bool regular = _settingsDraft.regularJobAlerts;
    bool sos = _settingsDraft.sosJobAlerts;
    final isCupertino = isCupertinoPlatform(context);

    Future<void> save() async {
      final nextDraft = _settingsDraft.copyWith(
        notificationsEnabled: enabled,
        regularJobAlerts: regular,
        sosJobAlerts: sos,
      );
      final updatedSettings = nextDraft.toSettings(current);
      final persisted =
          await ref.read(authProvider.notifier).updateSettingsPreferences(
                notificationsEnabled: enabled,
                regularJobAlerts: regular,
                sosJobAlerts: sos,
              );
      if (!persisted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_l10n.somethingWentWrong)),
          );
        }
        return;
      }
      await ref.read(settingsProvider.notifier).saveSettings(updatedSettings);
      await NotificationService.instance.applySettings(updatedSettings);
      if (!mounted) return;
      setState(() => _settingsDraft = nextDraft);
    }

    if (isCupertino) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => CupertinoPopupSurface(
          child: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (context, setSheetState) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _l10n.notificationsTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoFormSection.insetGrouped(
                      children: [
                        CupertinoFormRow(
                          prefix: Text(_l10n.notificationsEnable),
                          child: CupertinoSwitch(
                            value: enabled,
                            onChanged: (value) {
                              setSheetState(() => enabled = value);
                            },
                          ),
                        ),
                        CupertinoFormRow(
                          prefix: Text(_l10n.notificationsRegular),
                          child: CupertinoSwitch(
                            value: regular,
                            onChanged: enabled
                                ? (value) =>
                                    setSheetState(() => regular = value)
                                : null,
                          ),
                        ),
                        CupertinoFormRow(
                          prefix: Text(_l10n.notificationsSos),
                          child: CupertinoSwitch(
                            value: sos,
                            onChanged: enabled
                                ? (value) => setSheetState(() => sos = value)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: () async {
                          await save();
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        child: Text(_l10n.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _l10n.notificationsTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                title: Text(_l10n.notificationsEnable),
                value: enabled,
                onChanged: (value) => setSheetState(() => enabled = value),
              ),
              SwitchListTile.adaptive(
                title: Text(_l10n.notificationsRegular),
                value: regular,
                onChanged: enabled
                    ? (value) => setSheetState(() => regular = value)
                    : null,
              ),
              SwitchListTile.adaptive(
                title: Text(_l10n.notificationsSos),
                value: sos,
                onChanged: enabled
                    ? (value) => setSheetState(() => sos = value)
                    : null,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await save();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: Text(_l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker() async {
    final current = await SettingsService.instance.load();
    if (!mounted) return;
    String selected = _settingsDraft.languageCode;
    final isCupertino = isCupertinoPlatform(context);

    Future<void> save(String code) async {
      final nextDraft = _settingsDraft.copyWith(languageCode: code);
      final updatedSettings = nextDraft.toSettings(current);
      final persisted = await ref
          .read(authProvider.notifier)
          .updateSettingsPreferences(languageCode: code);
      if (!persisted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_l10n.somethingWentWrong)),
          );
        }
        return;
      }
      await ref.read(settingsProvider.notifier).saveSettings(updatedSettings);
      if (!mounted) return;
      setState(() => _settingsDraft = nextDraft);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.languageRestartPrompt)),
      );
    }

    if (isCupertino) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(_l10n.language),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                selected = 'en';
                await save(selected);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: Text(_l10n.languageEnglish),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                selected = 'he';
                await save(selected);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: Text(_l10n.languageHebrew),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text(_l10n.cancel),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _l10n.language,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selected,
                items: [
                  DropdownMenuItem(
                    value: 'en',
                    child: Text(_l10n.languageEnglish),
                  ),
                  DropdownMenuItem(
                    value: 'he',
                    child: Text(_l10n.languageHebrew),
                  ),
                ],
                onChanged: (value) =>
                    setSheetState(() => selected = value ?? 'en'),
                decoration: InputDecoration(
                  labelText: _l10n.language,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await save(selected);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: Text(_l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInfoSheet({
    required String title,
    required String body,
  }) async {
    final isCupertino = isCupertinoPlatform(context);
    if (isCupertino) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => CupertinoPopupSurface(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(body, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_l10n.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(body),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final authState = ref.read(authProvider);
    final email = authState.user?.email ?? '';

    final isCupertino = isCupertinoPlatform(context);
    final confirmed = await (isCupertino
        ? showCupertinoDialog<bool>(
            context: context,
            builder: (context) {
              String? errorText;
              return StatefulBuilder(
                builder: (context, setSheetState) => CupertinoAlertDialog(
                  title: Text(_l10n.addPassword),
                  content: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        _l10n.profileAddPasswordDescription(email),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      CupertinoTextField(
                        controller: passwordController,
                        placeholder: _l10n.profilePasswordPlaceholder,
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: confirmController,
                        placeholder: _l10n.confirmPasswordLabel,
                        obscureText: true,
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: const TextStyle(
                            color: CupertinoColors.systemRed,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(_l10n.cancel),
                    ),
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      onPressed: () {
                        final password = passwordController.text.trim();
                        final confirm = confirmController.text.trim();
                        if (password.length < 6) {
                          setSheetState(
                            () => errorText = _l10n.passwordMinLength,
                          );
                          return;
                        }
                        if (password != confirm) {
                          setSheetState(
                              () => errorText = _l10n.passwordsDoNotMatch);
                          return;
                        }
                        Navigator.pop(context, true);
                      },
                      child: Text(_l10n.addPassword),
                    ),
                  ],
                ),
              );
            },
          )
        : showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(_l10n.addPassword),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _l10n.profileAddPasswordDescription(email),
                      style: TextStyle(color: context.colors.mutedText),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: _l10n.passwordLabel,
                        prefixIcon: const Icon(LucideIcons.lock),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return _l10n.passwordMinLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: _l10n.confirmPasswordLabel,
                        prefixIcon: const Icon(LucideIcons.lock),
                      ),
                      validator: (value) {
                        if (value != passwordController.text) {
                          return _l10n.passwordsDoNotMatch;
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
                  child: Text(_l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: Text(_l10n.addPassword),
                ),
              ],
            ),
          ));

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
                ? _l10n.profilePasswordAddedSuccess
                : _l10n.profilePasswordAddFailed,
          ),
        ),
      );
    }

    passwordController.dispose();
    confirmController.dispose();
  }
}

class _AddressEditResult {
  const _AddressEditResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double? latitude;
  final double? longitude;
}

class _AccountEntry {
  const _AccountEntry({
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
