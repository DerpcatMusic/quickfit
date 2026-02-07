import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:quickfit/core/services/location_service.dart';
import 'package:quickfit/core/providers/zone_provider.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/shared/widgets/quickfit_map.dart';
import 'package:quickfit/features/instructor/map/presentation/widgets/instructor_map_view.dart';
import 'package:quickfit/features/instructor/map/presentation/widgets/instructor_stats_card.dart';
import 'package:quickfit/features/instructor/map/presentation/widgets/map_settings_sheet.dart';

class InstructorMapScreen extends ConsumerStatefulWidget {
  const InstructorMapScreen({super.key});

  @override
  ConsumerState<InstructorMapScreen> createState() =>
      _InstructorMapScreenState();
}

class _InstructorMapScreenState extends ConsumerState<InstructorMapScreen> {
  final GlobalKey<QuickFitMapState> _mapKey = GlobalKey();

  // State
  SelectionMode _mode = SelectionMode.radius;
  double _radiusKm = 5.0;
  LatLng? _currentLocation;
  Set<String> _selectedZoneIds = {};

  // Stats & Data
  int _totalJobs = 0;
  double _earningsThisMonth = 0.0;
  List<QuickFitJobMarker> _parsedJobs = const [];

  @override
  void initState() {
    super.initState();
    final position = LocationService.instance.currentPosition;
    if (position != null) {
      _currentLocation = LatLng(position.latitude, position.longitude);
    }

    _loadInitialData();
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authState = ref.read(authProvider);
      if (authState.latitude != null && authState.longitude != null) {
        setState(() {
          _currentLocation = LatLng(authState.latitude!, authState.longitude!);
          _radiusKm = authState.radiusKm ?? 5.0;
          if (authState.radiusKm != null) {
            _mode = SelectionMode.radius;
          }
        });
      }
      await _loadStatsAndJobs();
    });
  }

  Future<void> _loadStatsAndJobs() async {
    await Future.wait([
      _loadStats(),
      _loadJobsForMap(),
    ]);
  }

  Future<void> _loadStats() async {
    try {
      final result =
          await ConvexClient.instance.query('jobs:getInstructorStats', {});
      if (result.isNotEmpty && result != 'null') {
        final data = json.decode(result);
        if (mounted && data != null) {
          setState(() {
            _totalJobs = data['totalJobsCompleted'] ?? 0;
            _earningsThisMonth = (data['earningsThisMonth'] ?? 0).toDouble();
          });
        }
      }
    } catch (e) {
      developer.log('Error loading stats', name: 'instructor_map', error: e);
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
          'isVerified': ref.read(authProvider).isVerified.toString(),
        },
      );

      if (result.isNotEmpty && result != 'null') {
        final List<dynamic> data = json.decode(result);
        if (mounted) {
          setState(() {
            _parsedJobs = data.map((job) {
              return QuickFitJobMarker(
                id: job['_id'] as String,
                position: LatLng(
                    job['latitude'] as double, job['longitude'] as double),
                label: job['title'] as String? ?? 'Job',
                isSos: job['sosBoostApplied'] as bool? ?? false,
                currentRate: (job['currentRate'] as num?)?.toDouble(),
                distanceKm: ((job['distanceMeters'] as num?) ?? 0) / 1000,
              );
            }).toList();
          });
          _mapKey.currentState?.updateJobs(_parsedJobs);
        }
      }
    } catch (e) {
      developer.log('Error loading jobs', name: 'instructor_map', error: e);
    }
  }

  Future<void> _onSave() async {
    final authNotifier = ref.read(authProvider.notifier);
    final authState = ref.read(authProvider);

    try {
      if (_mode == SelectionMode.radius) {
        if (_currentLocation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select a location on the map')),
          );
          return;
        }

        await authNotifier.completeOnboarding(
          role: authState.role ?? 'instructor',
          name: authState.user?.displayName ?? '',
          categories: authState.categories ?? [],
          radiusKm: _radiusKm,
          latitude: _currentLocation!.latitude,
          longitude: _currentLocation!.longitude,
        );
      } else {
        if (_selectedZoneIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one zone')),
          );
          return;
        }

        await authNotifier.completeOnboarding(
          role: authState.role ?? 'instructor',
          name: authState.user?.displayName ?? '',
          categories: authState.categories ?? [],
          selectedZones: _selectedZoneIds.toList(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zonesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          InstructorMapView(
            mapKey: _mapKey,
            mode: _mode,
            currentLocation: _currentLocation,
            radiusKm: _radiusKm,
            jobs: _parsedJobs,
            selectedZoneIds: _selectedZoneIds,
            zonesAsync: zonesAsync,
            onZoneSelectionChanged: (zones) {
              setState(() {
                _selectedZoneIds = zones;
              });
            },
            onMapTap: (point) {
              if (_mode == SelectionMode.radius) {
                setState(() {
                  _currentLocation = point;
                });
              }
            },
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Service Area',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Controls / Stats Overlay
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_mode == SelectionMode.radius)
                  InstructorStatsCard(
                    totalJobs: _totalJobs,
                    earnings: _earningsThisMonth,
                    visibleJobsCount: _parsedJobs.length,
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => MapSettingsSheet(
                              initialMode: _mode,
                              initialRadius: _radiusKm,
                              selectedZoneIds: _selectedZoneIds,
                              onSave: _onSave,
                              onModeChanged: (mode) {
                                setState(() {
                                  _mode = mode;
                                });
                              },
                              onRadiusChanged: (radius) {
                                setState(() {
                                  _radiusKm = radius;
                                });
                              },
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.settings),
                            SizedBox(width: 8),
                            Text('Settings'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.cobaltAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
