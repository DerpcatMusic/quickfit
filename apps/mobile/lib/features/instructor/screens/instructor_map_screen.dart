import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/map_config.dart';
import '../../../core/providers/zone_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/quickfit_map.dart';
import '../../../shared/widgets/zone_selection_map.dart';

class InstructorMapScreen extends ConsumerStatefulWidget {
  const InstructorMapScreen({super.key});

  @override
  ConsumerState<InstructorMapScreen> createState() =>
      _InstructorMapScreenState();
}

enum SelectionMode { radius, zones }

class _InstructorMapScreenState extends ConsumerState<InstructorMapScreen> {
  // Key to access QuickFitMap state for external control
  final GlobalKey<QuickFitMapState> _mapKey = GlobalKey();

  // Mode
  SelectionMode _mode = SelectionMode.radius;

  // Radius State
  double _radiusKm = 5.0;
  bool _isSaving = false;
  LatLng? _currentLocation;

  // Note: We don't track sliding state anymore as slider is in a modal

  // Zone State
  Set<String> _selectedZoneIds = {};

  // Stats
  int _totalJobs = 0;
  double _earningsThisMonth = 0;

  // Jobs from Convex
  List<QuickFitJobMarker> _parsedJobs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadCurrentLocation(),
      _loadStats(),
      _loadUserProfile(),
    ]);
    await _loadJobsForMap();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user =
          await ConvexClient.instance.query('users:getCurrentUser', {});
      if (user.isNotEmpty && user != 'null') {
        final userData = json.decode(user);
        final userRadius = userData['radiusKm'];
        final userZones =
            userData['selectedZones']; // Checked logs: selectedZones

        if (mounted) {
          setState(() {
            if (userRadius != null) _radiusKm = (userRadius as num).toDouble();
            if (userZones != null) {
              _selectedZoneIds =
                  Set.from((userZones as List).map((e) => e.toString()));
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _loadCurrentLocation() async {
    final position = await LocationService.instance.updateLocation();
    if (position != null) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final result =
          await ConvexClient.instance.query('jobs:getInstructorStats', {});
      if (result.isNotEmpty && result != 'null') {
        final data = json.decode(result);
        if (data != null && mounted) {
          setState(() {
            _totalJobs = data['totalJobsCompleted'] ?? 0;
            _earningsThisMonth = (data['earningsThisMonth'] ?? 0).toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load stats: $e');
    }
  }

  Future<void> _loadJobsForMap() async {
    if (_currentLocation == null) return;

    try {
      final result = await ConvexClient.instance.query(
        'geo:getNearbyJobsForInstructor',
        {
          'latitude': _currentLocation!.latitude.toString(),
          'longitude': _currentLocation!.longitude.toString(),
          'radiusKm': _radiusKm.toString(),
          'categories':
              ref.read(authProvider).categories?.join(',') ?? 'general',
          'isVerified':
              mounted ? ref.read(authProvider).isVerified.toString() : 'false',
        },
      );

      if (result.isNotEmpty && result != 'null') {
        final data = json.decode(result) as List<dynamic>;
        if (mounted) {
          setState(() {
            _parsedJobs = _parseJobs(data);
          });
          if (_mode == SelectionMode.radius) {
            _mapKey.currentState?.updateJobs(_parsedJobs);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load jobs: $e');
    }
  }

  List<QuickFitJobMarker> _parseJobs(List<dynamic> data) {
    return data
        .map((job) {
          final lat = job['latitude'] as double?;
          final lng = job['longitude'] as double?;
          if (lat == null || lng == null) return null;

          return QuickFitJobMarker(
            id: job['_id'] as String,
            position: LatLng(lat, lng),
            label: job['title'] as String? ?? 'Job',
            isSos: job['sosBoostApplied'] as bool? ?? false,
            currentRate: (job['currentRate'] as num?)?.toDouble(),
            distanceKm: ((job['distanceMeters'] as num?) ?? 0) / 1000,
          );
        })
        .whereType<QuickFitJobMarker>()
        .toList();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      if (_mode == SelectionMode.radius) {
        await ConvexClient.instance.mutation(
            name: 'users:updateRadius', args: {'radiusKm': _radiusKm});
      } else {
        await ConvexClient.instance.mutation(
            name: 'users:updateZones',
            args: {'zoneIds': _selectedZoneIds.toList()});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mode == SelectionMode.radius
                ? 'Radius updated to ${_radiusKm.toStringAsFixed(1)} km'
                : 'Updated ${_selectedZoneIds.length} zones'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadJobsForMap();
    } catch (e) {
      debugPrint('Save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          return Consumer(builder: (context, ref, _) {
            final theme = Theme.of(context);
            final zonesAsync = ref.watch(zonesProvider);

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Search Settings',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Toggle Mode
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildToggleItem(theme, 'Radius', SelectionMode.radius,
                            LucideIcons.circle),
                        _buildToggleItem(theme, 'Zones', SelectionMode.zones,
                            LucideIcons.map),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_mode == SelectionMode.radius) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Search Radius',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('${_radiusKm.toStringAsFixed(1)} km',
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: theme.colorScheme.primary,
                        inactiveTrackColor: theme.colorScheme.primaryContainer,
                        thumbColor: theme.colorScheme.primary,
                        overlayColor:
                            theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _radiusKm.clamp(0.5, 50.0),
                        min: 0.5,
                        max: 50.0,
                        onChanged: (v) {
                          setState(() => _radiusKm = v);
                          // Pre-update map if possible, but keep it performant
                          // _mapKey.currentState?.updateRadius(_radiusKm, center: _currentLocation);
                        },
                      ),
                    ),
                  ] else ...[
                    // Zone Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.info,
                              size: 20, color: theme.colorScheme.secondary),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  'Selected zones are managed directly on the map. Close this menu to interact.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme
                                          .colorScheme.onSecondaryContainer))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (zonesAsync.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Text(
                        '${_selectedZoneIds.length} zones active',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold),
                      ),
                  ],

                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await _saveSettings();
                        if (mounted) navigator.pop();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save & Update Map',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          });
        },
      ),
    ).then((_) {
      setState(() {});
    });
  }

  Widget _buildToggleItem(
      ThemeData theme, String label, SelectionMode mode, IconData icon) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _mode = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    final position = await LocationService.instance.updateLocation();
    if (position != null) {
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = latLng;
      });
      _mapKey.currentState?.animateTo(latLng, zoom: MapConfig.cityZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final zonesAsync = ref.watch(zonesProvider);

    final jobsInView = _parsedJobs.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // MAP LAYER
          Positioned.fill(
            child: _mode == SelectionMode.radius
                ? QuickFitMap(
                    key: _mapKey,
                    initialCenter: _currentLocation,
                    initialZoom: MapConfig.cityZoom,
                    radiusKm: _radiusKm,
                    radiusCenter: _currentLocation,
                    showUserLocation: true,
                    showRadius: true,
                    interactionEnabled: true,
                    onStyleLoaded: () {
                      _mapKey.currentState?.updateJobs(_parsedJobs);
                    },
                  )
                : zonesAsync.when(
                    data: (zones) => ZoneSelectionMap(
                      zones: zones,
                      initialSelectedZones: _selectedZoneIds,
                      onSelectionChanged: (ids) => _selectedZoneIds = ids,
                      jobs: _parsedJobs,
                      topPadding: 80,
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
          ),

          // Stats Card (Top)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: _buildStatsCard(theme, colors, jobsInView),
          ),

          // Map Controls (Bottom Right)
          Positioned(
            bottom: 32,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_mode == SelectionMode.radius)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FloatingActionButton(
                      heroTag: 'location',
                      onPressed: _goToCurrentLocation,
                      backgroundColor: theme.colorScheme.surface,
                      foregroundColor: theme.colorScheme.onSurface,
                      child: const Icon(LucideIcons.locate),
                    ),
                  ),
                FloatingActionButton.large(
                  heroTag: 'settings',
                  onPressed: _showSettingsModal,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: const Icon(LucideIcons.settings2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme, AppColors colors, int jobsCount) {
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
                    label: 'Total Jobs',
                    value: '$_totalJobs',
                    icon: Icons.history)),
            Container(width: 1, height: 40, color: colors.divider),
            Expanded(
                child: _StatItem(
                    label: 'Earnings',
                    value: '₪${_earningsThisMonth.toStringAsFixed(0)}',
                    icon: Icons.payments_outlined)),
            Container(width: 1, height: 40, color: colors.divider),
            Expanded(
                child: _StatItem(
                    label: 'Visible',
                    value: '$jobsCount',
                    icon: Icons.map,
                    highlight: true)),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem(
      {required this.label,
      required this.value,
      required this.icon,
      this.highlight = false});
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
        Text(value,
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: highlight ? theme.colorScheme.primary : null)),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
