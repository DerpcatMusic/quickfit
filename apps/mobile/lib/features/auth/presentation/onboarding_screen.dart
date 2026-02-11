// Onboarding Screen - Role selection and profile setup
// lib/features/auth/presentation/onboarding_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:quickfit/core/constants/categories.dart';
import 'package:quickfit/core/constants/app_constants.dart';
import 'package:quickfit/core/services/location_service.dart';
import 'package:quickfit/core/theme/app_theme.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/l10n/app_localizations.dart';
import 'package:quickfit/shared/widgets/zone_selection_map.dart';
import 'package:quickfit/shared/widgets/quickfit_map.dart';
import 'package:quickfit/core/providers/zone_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final GlobalKey<QuickFitMapState> _mapKey = GlobalKey();
  int _currentPage = 0;
  bool _isMapVisible = false;
  Timer? _mapVisibilityTimer;

  // Form state
  String? _selectedRole;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final Set<String> _selectedCategories = {};
  double _radiusKm = AppConstants.defaultRadiusKm;
  LatLng? _currentLocation;
  bool _isSubmitting = false;

  // Zone selection state (default to zones mode)
  bool _useZoneMode = true; // true = select zones, false = use radius
  Set<String> _selectedZoneIds = {};

  final _storageKey = const PageStorageKey('onboarding_form');

  @override
  void initState() {
    super.initState();
    _initLocation();
    // Start loading zones in background so they act "instantly" availability later
    ref.read(zonesProvider);
  }

  Future<void> _initLocation() async {
    // Try to get current location - if it fails, user can use address search or "Find My Location"
    try {
      final pos = await LocationService.instance
          .updateLocation()
          .timeout(const Duration(seconds: 10));
      if (pos != null && mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      // Location failed - user can set it manually via address or "Find My Location"
    }
  }

  /// Find current GPS location and update map
  Future<void> _findMyLocation() async {
    try {
      final pos = await LocationService.instance.updateLocation();
      if (pos != null && mounted) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentLocation = latLng;
        });
        _mapKey.currentState?.animateTo(latLng, zoom: 14);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.onboardingLocationUnavailable)),
        );
      }
    }
  }

  /// Handle map tap to drop a pin
  void _onMapTap(LatLng location) {
    setState(() {
      _currentLocation = location;
    });
    // Update radius circle on map
    _mapKey.currentState?.updateRadiusCenter(location);
  }

  @override
  void dispose() {
    _mapVisibilityTimer?.cancel();
    _pageController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _nextPage() {
    const totalPages = 2; // Fixed 2 steps for everyone
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );

      // Delay map visibility to avoid lag during transition
      _mapVisibilityTimer?.cancel();
      _mapVisibilityTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _isMapVisible = true);
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      // 2026 FIX: Ensure studio address has coordinates
      if (_currentLocation == null &&
          _addressController.text.trim().isNotEmpty) {
        final pos = await LocationService.instance
            .getLatLngFromAddress(_addressController.text.trim());

        if (pos != null) {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        } else {
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.onboardingLocationNotFound),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isSubmitting = false);
            return;
          }
        }
      }

      // 2026 FIX: Prevent studios from onboarding without location
      if (_selectedRole == 'studio' && _currentLocation == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.onboardingStudioLocationRequired),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final success = await ref.read(authProvider.notifier).completeOnboarding(
            role: _selectedRole!,
            name: _nameController.text.trim(),
            categories: _selectedCategories.toList(),
            radiusKm: _selectedRole == 'instructor' && !_useZoneMode
                ? _radiusKm
                : null,
            latitude: _currentLocation?.latitude,
            longitude: _currentLocation?.longitude,
            address: _addressController.text.trim(),
            dispatchMode: _selectedRole == 'instructor'
                ? (_useZoneMode ? 'zone' : 'radius')
                : null,
            zoneIds: _selectedRole == 'instructor' && _useZoneMode
                ? _selectedZoneIds.toList()
                : null,
          );

      if (!success && mounted) {
        final l10n = AppLocalizations.of(context)!;
        // Show error to user - don't navigate away
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.onboardingSetupFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      // If success, router will automatically redirect based on hasCompletedOnboarding
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return _selectedRole != null;
      case 1:
        final baseValid = _nameController.text.trim().isNotEmpty &&
            _addressController.text.trim().isNotEmpty &&
            _selectedCategories.isNotEmpty;

        // For instructors, validate zone or radius selection
        if (_selectedRole == 'instructor') {
          if (_useZoneMode) {
            // Zone mode: require at least 1 zone selected
            return baseValid && _selectedZoneIds.isNotEmpty;
          } else {
            // Radius mode: require location
            return baseValid && _currentLocation != null;
          }
        }
        return baseValid;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      key: _storageKey,
      backgroundColor: theme.colorScheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (isDesktop) {
            return _buildDesktopLayout(theme, isRtl);
          } else {
            return _buildMobileLayout(theme);
          }
        },
      ),
    );
  }

  // ==============================================================================
  // LAYOUTS
  // ==============================================================================

  Widget _buildDesktopLayout(ThemeData theme, bool isRtl) {
    return Row(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      children: [
        // Functional Pane
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: isRtl
                    ? BorderSide.none
                    : BorderSide(color: theme.colorScheme.outlineVariant),
                left: isRtl
                    ? BorderSide(color: theme.colorScheme.outlineVariant)
                    : BorderSide.none,
              ),
            ),
            child: _buildFormPane(theme),
          ),
        ),
        // Visualization/Context Pane
        Expanded(
          flex: 6,
          child: Container(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            child: _buildContextualPane(theme, true),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    // CRITICAL: We use Visibility with maintainState to keep the map alive
    // even when hidden. This prevents widget destruction/recreation which
    // causes infinite loops from MapLibre style reloading.

    final bool showMap = _currentPage == 1 && _selectedRole == 'instructor';

    return Column(
      children: [
        // Map pane - ALWAYS in tree, hidden when not needed
        // Using AnimatedContainer for smooth height transitions
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          height: showMap ? MediaQuery.of(context).size.height * 0.45 : 0,
          child: Visibility(
            visible: showMap,
            maintainState: true, // CRITICAL: Keep map state alive!
            maintainAnimation: true,
            maintainSize: false,
            child: _buildContextualPane(theme, false),
          ),
        ),

        // Form pane - takes remaining space
        Expanded(
          child: Container(
            color: theme.colorScheme.surface,
            child: _buildFormPane(theme),
          ),
        ),
      ],
    );
  }

  // ==============================================================================
  // PANES
  // ==============================================================================

  Widget _buildFormPane(ThemeData theme) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(theme),
          _buildProgressIndicator(theme),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildRoleSelectionPage(theme),
                _buildProfilePage(theme),
              ],
            ),
          ),
          _buildNavigationButtons(theme),
        ],
      ),
    );
  }

  Widget _buildContextualPane(ThemeData theme, bool isDesktop) {
    final l10n = AppLocalizations.of(context)!;
    switch (_currentPage) {
      case 0:
        return _TipsPanel(
          fastMatchingTitle: l10n.onboardingTipFastMatchingTitle,
          fastMatchingBody: l10n.onboardingTipFastMatchingBody,
          verifiedProsTitle: l10n.onboardingTipVerifiedTitle,
          verifiedProsBody: l10n.onboardingTipVerifiedBody,
          localFocusTitle: l10n.onboardingTipLocalTitle,
          localFocusBody: l10n.onboardingTipLocalBody,
        );
      case 1:
        return _selectedRole == 'instructor'
            ? _buildMapPanel(theme)
            : _ProfilePreviewPanel(
                role: _selectedRole,
                name: _nameController.text,
                selectedCategories: _selectedCategories,
                previewLabel: l10n.onboardingPreview,
                emptyName: l10n.onboardingYourName,
                unselectedRole: l10n.onboardingUnselected,
                emptyCategories: l10n.onboardingSelectCategoriesHint,
              );
      default:
        return const SizedBox.shrink();
    }
  }

  // ==============================================================================
  // COMPONENTS
  // ==============================================================================

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.zap, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Quickfit',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    const totalPages = 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(totalPages, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              margin: EdgeInsets.only(right: index < totalPages - 1 ? 8 : 0),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------------- STEP 1: ROLE ----------------

  Widget _buildRoleSelectionPage(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingWelcomeTitle,
              style: theme.textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.onboardingWelcomeBody,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          _buildRoleCard(
            theme,
            role: 'instructor',
            icon: LucideIcons.dumbbell,
            title: l10n.onboardingRoleInstructor,
            description: l10n.onboardingRoleInstructorBody,
          ),
          const SizedBox(height: 16),
          _buildRoleCard(
            theme,
            role: 'studio',
            icon: LucideIcons.building2,
            title: l10n.onboardingRoleStudio,
            description: l10n.onboardingRoleStudioBody,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(ThemeData theme,
      {required String role,
      required IconData icon,
      required String title,
      required String description}) {
    final isSelected = _selectedRole == role;
    return Card(
      elevation: 0,
      shape: AppTheme.geometricShape.copyWith(
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _selectedRole = role),
        customBorder: AppTheme.geometricShape,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (isSelected)
                Icon(LucideIcons.checkCircle2,
                    color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- STEP 2: PROFILE ----------------

  Widget _buildProfilePage(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingBuildProfile,
              style: theme.textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText:
                  _selectedRole == 'instructor'
                      ? l10n.onboardingFullName
                      : l10n.onboardingStudioName,
              prefixIcon: const Icon(LucideIcons.user),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TypeAheadField<Map<String, dynamic>>(
            controller: _addressController,
            builder: (context, controller, focusNode) => TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: l10n.onboardingAddress,
                prefixIcon: const Icon(LucideIcons.mapPin),
                hintText: l10n.onboardingAddressHint,
              ),
              onChanged: (_) => setState(() {}),
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

              // Geocode and update map
              final pos =
                  await LocationService.instance.getLatLngFromAddress(address);
              if (pos != null) {
                final latLng = LatLng(pos.latitude, pos.longitude);
                setState(() {
                  _currentLocation = latLng;
                });

                // Animate map to new location using QuickFitMap
                _mapKey.currentState?.animateTo(latLng, zoom: 15);
              }
            },
          ),
          const SizedBox(height: 12),
          // GPS Location Button
          OutlinedButton.icon(
            onPressed: () async {
              await _findMyLocation();
              // Reverse geocode to fill address field if possible
              if (_currentLocation != null) {
                final address =
                    await LocationService.instance.getAddressFromLatLng(
                  _currentLocation!.latitude,
                  _currentLocation!.longitude,
                );

                if (address != null && mounted) {
                  setState(() {
                    _addressController.text = address;
                  });
                }
              }
            },
            icon: const Icon(LucideIcons.crosshair),
            label: Text(l10n.onboardingUseCurrentLocation),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 32),
          Text(l10n.onboardingYourExpertise,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
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
          if (_selectedRole == 'instructor') ...[
            const SizedBox(height: 32),
            Text(_useZoneMode
                    ? l10n.onboardingCoverageZones
                    : l10n.onboardingSearchRadius,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_useZoneMode)
              // Zone mode: show zones count and hint
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(LucideIcons.map, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.zonesSelectedLabel(_selectedZoneIds.length),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              l10n.onboardingZoneHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Radius mode: show slider
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _radiusKm,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      onChanged: (v) => setState(() => _radiusKm = v),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.mapRadiusKm(_radiusKm.round()),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  // ---------------- STEP 3: RADIUS ----------------

  // ---------------- NAVIGATION ----------------

  Widget _buildNavigationButtons(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final isLastPage = _currentPage == 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                child: Text(l10n.back),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed:
                  _canProceed ? (isLastPage ? _submit : _nextPage) : null,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : SizedBox(
                      key: ValueKey('page_button_text_$_currentPage'),
                      height: 24,
                      child: Center(
                        widthFactor: 1.0,
                        child: Text(
                          isLastPage
                              ? l10n.onboardingGetStarted
                              : l10n.onboardingNextStep,
                          style: const TextStyle(height: 1.0),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // VISUALIZATION PANELS
  // ==============================================================================

  Widget _buildMapPanel(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final bottomInset = media.padding.bottom;
    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Stack(
        children: [
          // Map content - zone or radius based on toggle
          _useZoneMode ? _buildZoneMap(theme) : _buildRadiusMap(theme),

          // Mode toggle at top
          Positioned(
            top: 16 + topInset,
            left: 16,
            right: 16,
            child: PointerInterceptor(
              child: Card(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModeButton(
                        theme,
                        icon: LucideIcons.map,
                        label: l10n.mapModeZones,
                        isSelected: _useZoneMode,
                        onTap: () => setState(() => _useZoneMode = true),
                      ),
                      const SizedBox(width: 8),
                      _buildModeButton(
                        theme,
                        icon: LucideIcons.circle,
                        label: l10n.mapModeRadius,
                        isSelected: !_useZoneMode,
                        onTap: () => setState(() => _useZoneMode = false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Selection info at bottom
          Positioned(
            bottom: 16 + bottomInset,
            left: 16,
            right: 16,
            child: PointerInterceptor(
              child: Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.95),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        _useZoneMode ? LucideIcons.mapPin : LucideIcons.circle,
                        size: 20,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _useZoneMode
                              ? l10n.zonesSelectedLabel(_selectedZoneIds.length)
                              : l10n.onboardingRadiusLabel(_radiusKm.round()),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      if (!_useZoneMode)
                        FloatingActionButton.small(
                          heroTag: 'findLocation',
                          onPressed: _findMyLocation,
                          tooltip: l10n.onboardingFindMyLocation,
                          child: const Icon(LucideIcons.crosshair, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoneMap(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final zonesAsync = ref.watch(zonesProvider);

    return zonesAsync.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.mapLoadingZones, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
      error: (err, stack) => Center(
        child: SingleChildScrollView(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.alertCircle,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(l10n.onboardingCouldNotLoadZones,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(l10n.onboardingTryRadiusMode,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.refresh(zonesProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      data: (zones) => AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: _isMapVisible ? 1.0 : 0.0,
        child: _isMapVisible
            ? ZoneSelectionMap(
                zones: zones,
                initialSelectedZones: _selectedZoneIds,
                onSelectionChanged: (ids) =>
                    setState(() => _selectedZoneIds = Set.from(ids)),
                topPadding: 80,
              )
            : Container(color: theme.colorScheme.surface),
      ),
    );
  }

  Widget _buildRadiusMap(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    if (!_isMapVisible) return Container(color: theme.colorScheme.surface);
    // Show helpful prompt when no location set yet
    if (_currentLocation == null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.mapPin,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(l10n.onboardingSetYourLocation,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(l10n.onboardingSetYourLocationBody,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _findMyLocation,
                  icon: const Icon(LucideIcons.crosshair),
                  label: Text(l10n.onboardingFindMyLocation),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 80, bottom: 80),
      child: QuickFitMap(
        key: _mapKey,
        initialCenter: _currentLocation,
        initialZoom: 12,
        radiusKm: _radiusKm,
        radiusCenter: _currentLocation,
        showUserLocation: true,
        showRadius: true,
        showHomePin: true,
        interactionEnabled: true,
        onMapTap: _onMapTap,
      ),
    );
  }

  bool get isHebrew => Localizations.localeOf(context).languageCode == 'he';
}

class _TipsPanel extends StatelessWidget {
  const _TipsPanel({
    required this.fastMatchingTitle,
    required this.fastMatchingBody,
    required this.verifiedProsTitle,
    required this.verifiedProsBody,
    required this.localFocusTitle,
    required this.localFocusBody,
  });

  final String fastMatchingTitle;
  final String fastMatchingBody;
  final String verifiedProsTitle;
  final String verifiedProsBody;
  final String localFocusTitle;
  final String localFocusBody;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TipItem(
                icon: LucideIcons.zap,
                title: fastMatchingTitle,
                desc: fastMatchingBody),
            const SizedBox(height: 24),
            _TipItem(
                icon: LucideIcons.shieldCheck,
                title: verifiedProsTitle,
                desc: verifiedProsBody),
            const SizedBox(height: 24),
            _TipItem(
                icon: LucideIcons.map,
                title: localFocusTitle,
                desc: localFocusBody),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _TipItem({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(desc,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfilePreviewPanel extends StatelessWidget {
  final String? role;
  final String name;
  final Set<String> selectedCategories;
  final String previewLabel;
  final String emptyName;
  final String unselectedRole;
  final String emptyCategories;

  const _ProfilePreviewPanel({
    required this.role,
    required this.name,
    required this.selectedCategories,
    required this.previewLabel,
    required this.emptyName,
    required this.unselectedRole,
    required this.emptyCategories,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
            child: Center(
              widthFactor: 1.0,
              child: Text(
                previewLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            shape: AppTheme.geometricShape,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  children: [
                    CircleAvatar(
                        radius: 40,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                            role == 'studio'
                                ? LucideIcons.building2
                                : LucideIcons.user,
                            size: 40,
                            color: theme.colorScheme.onPrimaryContainer)),
                    const SizedBox(height: 16),
                    Text(name.isEmpty ? emptyName : name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(role?.toUpperCase() ?? unselectedRole,
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Divider(color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: selectedCategories.map((id) {
                        final cat = FitnessCategory.fromId(id);
                        return Chip(
                            label: Text('${cat?.emoji} ${cat?.nameEn}'),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact);
                      }).toList(),
                    ),
                    if (selectedCategories.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(emptyCategories,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
