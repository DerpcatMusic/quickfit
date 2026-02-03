import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convex_flutter/convex_flutter.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/map_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/quickfit_map.dart';

/// Instructor Map Screen - The main homepage for instructors.
/// Shows:
/// - Full-screen map with their location
/// - Radius circle visualization
/// - Job markers within their search area
/// - Stats card (jobs this month)
/// - Radius slider to adjust search distance
class InstructorMapScreen extends ConsumerStatefulWidget {
  const InstructorMapScreen({super.key});

  @override
  ConsumerState<InstructorMapScreen> createState() =>
      _InstructorMapScreenState();
}

class _InstructorMapScreenState extends ConsumerState<InstructorMapScreen> {
  // Key to access QuickFitMap state for external control
  final GlobalKey<QuickFitMapState> _mapKey = GlobalKey();

  double _radiusKm = 5.0;
  bool _isSaving = false;
  LatLng? _currentLocation;
  bool _isSliding = false;

  // Stats
  int _totalJobs = 0;
  double _earningsThisMonth = 0;

  // Jobs from Convex
  List<dynamic> _nearbyJobs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Run location and stats in parallel for faster loading
    await Future.wait([
      _loadCurrentLocation(),
      _loadStats(),
    ]);
    // Jobs depend on location being available
    await _loadJobsForMap();
  }

  Future<void> _loadCurrentLocation() async {
    final position = await LocationService.instance.updateLocation();
    if (position != null) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final result = await ConvexClient.instance.query(
        'jobs:getInstructorStats',
        {},
      );
      if (result.isNotEmpty && result != 'null') {
        final data = json.decode(result);
        if (data != null) {
          setState(() {
            _totalJobs = data['totalJobsCompleted'] ?? 0;
            _earningsThisMonth = (data['earningsThisMonth'] ?? 0).toDouble();
            _radiusKm = (data['radiusKm'] ?? 5.0).toDouble();
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
      // 2026 GEOSPATIAL SEARCH
      final result = await ConvexClient.instance.query(
        'geo:getNearbyJobsForInstructor',
        {
          'latitude': _currentLocation!.latitude.toString(),
          'longitude': _currentLocation!.longitude.toString(),
          'radiusKm': _radiusKm.toString(),
          'categories': (ref.read(authProvider).role == 'instructor'
                  ? ['general']
                  : ['general'])
              .join(','),
          'isVerified': ref.read(authProvider).isVerified.toString(),
        },
      );

      if (result.isNotEmpty && result != 'null') {
        final data = json.decode(result) as List<dynamic>;
        setState(() {
          _nearbyJobs = data;
        });
        // Update map with new job markers
        _updateMapJobs();
      }
    } catch (e) {
      debugPrint('Failed to load jobs: $e');
    }
  }

  void _updateMapJobs() {
    final mapState = _mapKey.currentState;
    if (mapState == null || !mapState.isStyleLoaded) return;

    final jobs = _nearbyJobs
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

    mapState.updateJobs(jobs);
  }

  Future<void> _saveRadius() async {
    setState(() => _isSaving = true);
    try {
      await ConvexClient.instance.mutation(
        name: 'users:updateRadius',
        args: {'radiusKm': _radiusKm},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Radius updated to ${_radiusKm.toStringAsFixed(1)} km'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // Reload jobs with new radius
      await _loadJobsForMap();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final jobsInRadius = _nearbyJobs
        .where(
          (j) => (j['distanceMeters'] as num? ?? 0) <= (_radiusKm * 1000),
        )
        .length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // MapLibre Map (via QuickFitMap)
          QuickFitMap(
            key: _mapKey,
            initialCenter: _currentLocation,
            initialZoom: MapConfig.cityZoom,
            radiusKm: _radiusKm,
            radiusCenter: _currentLocation,
            showUserLocation: true,
            showRadius: true,
            interactionEnabled: !_isSliding,
            onStyleLoaded: () {
              // Once style is loaded, add job markers
              _updateMapJobs();
            },
          ),

          // Stats Card (Top)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: _buildStatsCard(theme, colors, jobsInRadius),
          ),

          // Radius Slider Panel (Bottom)
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: _buildRadiusPanel(theme),
          ),

          // FAB for current location
          Positioned(
            bottom: 200,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'location',
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Refresh button
          Positioned(
            bottom: 250,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'refresh',
              onPressed: _loadData,
              child: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme, AppColors colors, int jobsInRadius) {
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
            // Total Jobs
            Expanded(
              child: _StatItem(
                label: 'Total Jobs',
                value: '$_totalJobs',
                icon: Icons.history,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: colors.divider,
            ),
            // Total earnings
            Expanded(
              child: _StatItem(
                label: 'Earnings',
                value: '₪${_earningsThisMonth.toStringAsFixed(0)}',
                icon: Icons.payments_outlined,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: colors.divider,
            ),
            // Available jobs
            Expanded(
              child: _StatItem(
                label: 'In Range',
                value: '$jobsInRadius',
                icon: Icons.location_on_outlined,
                highlight: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusPanel(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Radius',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_radiusKm.toStringAsFixed(1)} km',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
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
              onChangeStart: (_) => setState(() => _isSliding = true),
              onChangeEnd: (_) {
                setState(() => _isSliding = false);
                // Update map radius visualization
                _mapKey.currentState
                    ?.updateRadius(_radiusKm, center: _currentLocation);
              },
              onChanged: (value) {
                setState(() {
                  _radiusKm = value;
                });
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveRadius,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Radius'),
              ),
            ),
          ],
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
      // Animate map to new location
      _mapKey.currentState?.animateTo(latLng, zoom: MapConfig.cityZoom);
    }
  }
}

/// A single stat item for the stats card.
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight ? theme.colorScheme.primary : null;

    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
