// Onboarding Screen - Role selection and profile setup
// lib/features/auth/presentation/onboarding_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:quickfit/core/constants/categories.dart';
import 'package:quickfit/core/constants/app_constants.dart';
import 'package:quickfit/core/services/location_service.dart';
import 'package:quickfit/core/theme/app_theme.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/shared/widgets/quickfit_map.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final GlobalKey<QuickFitMapState> _mapKey = GlobalKey();
  int _currentPage = 0;

  // Form state
  String? _selectedRole;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final Set<String> _selectedCategories = {};
  double _radiusKm = AppConstants.defaultRadiusKm;
  LatLng? _currentLocation;
  bool _isSubmitting = false;

  final _storageKey = const PageStorageKey('onboarding_form');

  @override
  void initState() {
    super.initState();
    _initLocation();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not get your location. Try entering your address.')),
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
      await ref.read(authProvider.notifier).completeOnboarding(
            role: _selectedRole!,
            name: _nameController.text.trim(),
            categories: _selectedCategories.toList(),
            radiusKm: _selectedRole == 'instructor' ? _radiusKm : null,
            latitude: _currentLocation?.latitude,
            longitude: _currentLocation?.longitude,
            address: _addressController.text.trim(),
          );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return _selectedRole != null;
      case 1:
        return _nameController.text.trim().isNotEmpty &&
            _addressController.text.trim().isNotEmpty &&
            _selectedCategories.isNotEmpty;
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
    switch (_currentPage) {
      case 0:
        return const _TipsPanel();
      case 1:
        return _selectedRole == 'instructor'
            ? _buildMapPanel(theme)
            : _ProfilePreviewPanel(
                role: _selectedRole,
                name: _nameController.text,
                selectedCategories: _selectedCategories,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome.',
              style: theme.textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Choose your role to continue.',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 32),
          _buildRoleCard(
            theme,
            role: 'instructor',
            icon: LucideIcons.dumbbell,
            title: 'Instructor',
            description:
                'Find sub jobs at studios near you and grow your network.',
          ),
          const SizedBox(height: 16),
          _buildRoleCard(
            theme,
            role: 'studio',
            icon: LucideIcons.building2,
            title: 'Studio',
            description:
                'Post classes and find reliable instructors in minutes.',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Build your profile.',
              style: theme.textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText:
                  _selectedRole == 'instructor' ? 'Full Name' : 'Studio Name',
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
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(LucideIcons.mapPin),
                hintText: 'e.g., Rothschild 1, Tel Aviv',
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
          const SizedBox(height: 32),
          Text('Your Expertise',
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
            Text('Search Radius',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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
                    '${_radiusKm.round()} km',
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
    final isLastPage = _currentPage == 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                child: const Text('Back'),
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
                          isLastPage ? 'Get Started' : 'Next Step',
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
    // Show helpful prompt when no location set yet
    if (_currentLocation == null) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Center(
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
                  Text('Set Your Location',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Enter your address in the form, or use GPS:',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _findMyLocation,
                    icon: const Icon(LucideIcons.crosshair),
                    label: const Text('Find My Location'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Stack(
        children: [
          QuickFitMap(
            key: _mapKey,
            initialCenter: _currentLocation,
            initialZoom: 12,
            radiusKm: _radiusKm,
            radiusCenter: _currentLocation,
            showUserLocation: true,
            showRadius: true,
            interactionEnabled: true, // Allow panning/zooming
            onMapTap: _onMapTap, // Drop pin on tap
          ),
          // Radius label
          Positioned(
            top: 24,
            right: 24,
            child: Card(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('${_radiusKm.round()} km radius',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          // Find My Location button
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.small(
              heroTag: 'findLocation',
              onPressed: _findMyLocation,
              tooltip: 'Find My Location',
              child: const Icon(LucideIcons.crosshair),
            ),
          ),
          // Hint text
          Positioned(
            bottom: 24,
            left: 24,
            right: 80,
            child: Card(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.9),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Tap the map to set your home location',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get isHebrew => Localizations.localeOf(context).languageCode == 'he';
}

class _TipsPanel extends StatelessWidget {
  const _TipsPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TipItem(
                icon: LucideIcons.zap,
                title: "Fast Matching",
                desc: "Connect with studios in real-time."),
            SizedBox(height: 24),
            _TipItem(
                icon: LucideIcons.shieldCheck,
                title: "Verified Pros",
                desc: "Join a community of certified instructors."),
            SizedBox(height: 24),
            _TipItem(
                icon: LucideIcons.map,
                title: "Local Focus",
                desc: "Work exactly where you want to."),
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

  const _ProfilePreviewPanel({
    required this.role,
    required this.name,
    required this.selectedCategories,
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
                'PREVIEW',
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
                    Text(name.isEmpty ? 'Your Name' : name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(role?.toUpperCase() ?? 'UNSELECTED',
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
                      Text('Select categories to see them here.',
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
