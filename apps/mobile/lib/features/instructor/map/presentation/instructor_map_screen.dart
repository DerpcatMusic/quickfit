import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:quickfit/core/services/location_service.dart';
import 'package:quickfit/core/providers/zone_provider.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/core/utils/platform.dart';
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
  int _jobsDataSignature = 0;
  SubscriptionHandle? _jobsSubscription;
  Timer? _jobsSubscriptionDebounce;
  String? _jobsSubscriptionKey;

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
      setState(() {
        _selectedZoneIds = Set.from(authState.zoneIds ?? []);
        _mode = authState.dispatchMode == 'zone'
            ? SelectionMode.zones
            : SelectionMode.radius;
      });
      if (authState.latitude != null && authState.longitude != null) {
        setState(() {
          _currentLocation = LatLng(authState.latitude!, authState.longitude!);
          _radiusKm = authState.radiusKm ?? 5.0;
        });
      }
      await _loadStatsAndJobs();
    });
  }

  Future<void> _loadStatsAndJobs() async {
    await Future.wait([
      _loadStats(),
      _subscribeToMapJobs(force: true),
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

  void _scheduleMapJobsResubscribe() {
    _jobsSubscriptionDebounce?.cancel();
    _jobsSubscriptionDebounce = Timer(const Duration(milliseconds: 250), () {
      _subscribeToMapJobs();
    });
  }

  Map<String, String> _buildMapJobsArgs() {
    final auth = ref.read(authProvider);
    return {
      'latitude': _currentLocation!.latitude.toString(),
      'longitude': _currentLocation!.longitude.toString(),
      'radiusKm': _radiusKm.toString(),
      'categories': auth.categories?.join(',') ?? 'general',
      'isVerified': auth.isVerified.toString(),
    };
  }

  Future<void> _subscribeToMapJobs({bool force = false}) async {
    if (_mode == SelectionMode.radius && _currentLocation == null) return;
    if (_mode == SelectionMode.zones && _selectedZoneIds.isEmpty) {
      if (mounted) {
        setState(() => _parsedJobs = const []);
      }
      _jobsSubscription?.cancel();
      _jobsSubscription = null;
      _jobsSubscriptionKey = null;
      return;
    }

    final auth = ref.read(authProvider);
    final args = _mode == SelectionMode.radius ? _buildMapJobsArgs() : <String, String>{};
    final zoneArgs = <String, String>{
      'zoneIds': json.encode(_selectedZoneIds.toList()),
      'categories': auth.categories?.join(',') ?? 'general',
    };
    final key = json.encode(_mode == SelectionMode.zones ? zoneArgs : args);

    if (!force && _jobsSubscription != null && _jobsSubscriptionKey == key) {
      return;
    }

    _jobsSubscription?.cancel();
    _jobsSubscription = null;
    _jobsSubscriptionKey = key;

    try {
      _jobsSubscription = await ConvexClient.instance.subscribe(
        name: _mode == SelectionMode.zones
            ? 'jobs:getZoneJobsForInstructor'
            : 'geo:getNearbyJobsForInstructor',
        args: _mode == SelectionMode.zones
            ? zoneArgs
            : args,
        onUpdate: _handleMapJobsUpdate,
        onError: (message, value) {
          developer.log('Map job subscription error: $message',
              name: 'instructor_map', error: value);
        },
      );
    } catch (e) {
      developer.log('Error subscribing to jobs',
          name: 'instructor_map', error: e);
    }
  }

  void _handleMapJobsUpdate(String data) {
    try {
      if (data.isEmpty || data == 'null') {
        if (mounted) {
          _jobsDataSignature = 0;
          setState(() => _parsedJobs = const []);
        }
        return;
      }

      final List<dynamic> parsed = json.decode(data) as List<dynamic>;
      final jobs = parsed.map((job) {
        return QuickFitJobMarker(
          id: job['_id'] as String,
          position: LatLng(
            (job['latitude'] as num).toDouble(),
            (job['longitude'] as num).toDouble(),
          ),
          label: job['title'] as String? ?? 'Job',
          isSos: job['sosBoostApplied'] as bool? ?? false,
          currentRate: (job['currentRate'] as num?)?.toDouble(),
          distanceKm: ((job['distanceMeters'] as num?) ?? 0) / 1000,
        );
      }).toList();

      final signature = _computeJobsSignature(jobs);
      if (mounted && signature != _jobsDataSignature) {
        _jobsDataSignature = signature;
        setState(() => _parsedJobs = jobs);
      }
    } catch (e) {
      developer.log('Error parsing map jobs', name: 'instructor_map', error: e);
    }
  }

  int _computeJobsSignature(List<QuickFitJobMarker> jobs) {
    var hash = jobs.length;
    for (final job in jobs) {
      hash = Object.hash(
        hash,
        job.id,
        job.position.latitude.toStringAsFixed(5),
        job.position.longitude.toStringAsFixed(5),
        job.isSos,
        job.label,
        job.currentRate,
      );
    }
    return hash;
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
          dispatchMode: 'radius',
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
          dispatchMode: 'zone',
          zoneIds: _selectedZoneIds.toList(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
        await _loadStatsAndJobs();
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
  void dispose() {
    _jobsSubscription?.cancel();
    _jobsSubscriptionDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zonesProvider);
    final isCupertino = isCupertinoPlatform(context);

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
              _scheduleMapJobsResubscribe();
            },
            onMapTap: (point) {
              if (_mode == SelectionMode.radius) {
                setState(() {
                  _currentLocation = point;
                });
                _scheduleMapJobsResubscribe();
              }
            },
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
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
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
            ),
          ),

          // Controls / Stats Overlay
          Positioned(
            bottom: 0,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 16),
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
                        child: isCupertino
                            ? CupertinoButton(
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
                                        _scheduleMapJobsResubscribe();
                                      },
                                      onRadiusChanged: (radius) {
                                        setState(() {
                                          _radiusKm = radius;
                                        });
                                        _scheduleMapJobsResubscribe();
                                      },
                                    ),
                                  );
                                },
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                color: CupertinoColors.systemGrey5,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.settings),
                                    SizedBox(width: 8),
                                    Text('Settings'),
                                  ],
                                ),
                              )
                            : ElevatedButton(
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
                                        _scheduleMapJobsResubscribe();
                                      },
                                      onRadiusChanged: (radius) {
                                        setState(() {
                                          _radiusKm = radius;
                                        });
                                        _scheduleMapJobsResubscribe();
                                      },
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
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
                      isCupertino
                          ? CupertinoButton.filled(
                              onPressed: _onSave,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 24,
                              ),
                              child: const Text('Save'),
                            )
                          : ElevatedButton(
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
          ),
        ],
      ),
    );
  }
}
