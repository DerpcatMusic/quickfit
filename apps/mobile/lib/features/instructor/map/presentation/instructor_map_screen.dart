import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:quickfit/core/router/app_routes.dart';
import 'package:quickfit/core/constants/categories.dart';
import 'package:quickfit/core/providers/zone_provider.dart';
import 'package:quickfit/core/services/location_service.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/features/instructor/map/presentation/widgets/instructor_map_view.dart';
import 'package:quickfit/features/instructor/map/presentation/widgets/map_settings_sheet.dart';
import 'package:quickfit/shared/widgets/quickfit_map.dart';
import 'package:quickfit/l10n/app_localizations.dart';

class InstructorMapScreen extends ConsumerStatefulWidget {
  const InstructorMapScreen({super.key});

  @override
  ConsumerState<InstructorMapScreen> createState() =>
      _InstructorMapScreenState();
}

class _InstructorMapScreenState extends ConsumerState<InstructorMapScreen> {
  final GlobalKey<QuickFitMapState> _mapKey = GlobalKey();
  final TextEditingController _addressController = TextEditingController();

  SelectionMode _mode = SelectionMode.radius;
  double _radiusKm = 5.0;
  double _previewRadiusKm = 5.0;
  LatLng? _currentLocation;
  Set<String> _selectedZoneIds = {};
  bool _isPinDropMode = false;
  bool _isResolvingAddress = false;
  bool _isSettingsExpanded = false;
  bool _isApplyingSettings = false;
  bool _reapplySettings = false;

  List<QuickFitJobMarker> _parsedJobs = const [];
  int _jobsDataSignature = 0;
  SubscriptionHandle? _jobsSubscription;
  Timer? _jobsSubscriptionDebounce;
  String? _jobsSubscriptionKey;
  Timer? _applyDebounce;
  Timer? _radiusPreviewThrottle;
  StreamSubscription<Position>? _locationSubscription;
  String? _lastHydratedAuthSnapshot;

  @override
  void initState() {
    super.initState();
    final position = LocationService.instance.currentPosition;
    if (position != null) {
      _currentLocation = LatLng(position.latitude, position.longitude);
    }

    _loadInitialData();
    _bootstrapLocationTracking();
  }

  void _bootstrapLocationTracking() {
    unawaited(_refreshCurrentLocationIfNeeded());

    _locationSubscription = LocationService.instance.watchLocation().listen(
      (position) {
        if (!mounted) return;
        if (_mode != SelectionMode.radius) return;
        final next = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = next;
        });
        _mapKey.currentState?.updateRadiusCenter(next);
      },
      onError: (_, __) {},
    );
  }

  Future<void> _refreshCurrentLocationIfNeeded() async {
    try {
      final updated = await LocationService.instance.updateLocation();
      if (!mounted || updated == null || _mode != SelectionMode.radius) {
        return;
      }
      final next = LatLng(updated.latitude, updated.longitude);
      setState(() {
        _currentLocation = next;
      });
      _mapKey.currentState?.updateRadiusCenter(next);
    } catch (_) {
      // Non-fatal; map remains usable with previously cached location.
    }
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final authState = ref.read(authProvider);
      _hydrateFromAuthState(authState, force: true);
      if (!mounted) return;
      await _subscribeToMapJobs(force: true);
    });
  }

  void _hydrateFromAuthState(AuthState authState, {bool force = false}) {
    final snapshot = [
      authState.dispatchMode ?? '',
      (authState.zoneIds ?? const <String>[]).join(','),
      authState.latitude?.toString() ?? '',
      authState.longitude?.toString() ?? '',
      authState.radiusKm?.toString() ?? '',
      authState.homeAddress ?? '',
      authState.isLoading.toString(),
      authState.user?.uid ?? '',
    ].join('|');

    if (!force && snapshot == _lastHydratedAuthSnapshot) {
      return;
    }
    _lastHydratedAuthSnapshot = snapshot;
    if (authState.isLoading || authState.user == null) {
      return;
    }

    final hasLatLng = authState.latitude != null && authState.longitude != null;
    final hydratedMode =
        authState.dispatchMode == 'zone' ? SelectionMode.zones : SelectionMode.radius;
    final hydratedZones = Set<String>.from(authState.zoneIds ?? const <String>[]);
    final hydratedAddress = (authState.homeAddress ?? '').trim();
    final hydratedRadius = authState.radiusKm ?? _radiusKm;
    final hydratedPoint = hasLatLng
        ? LatLng(authState.latitude!, authState.longitude!)
        : _currentLocation;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _mode = hydratedMode;
        _selectedZoneIds = hydratedZones;
        _radiusKm = hydratedRadius;
        _previewRadiusKm = hydratedRadius;
        _currentLocation = hydratedPoint;
        if (hydratedAddress.isNotEmpty) {
          _addressController.text = hydratedAddress;
        }
      });
      _subscribeToMapJobs(force: true);
    });
  }

  void _scheduleMapJobsResubscribe() {
    _jobsSubscriptionDebounce?.cancel();
    _jobsSubscriptionDebounce = Timer(const Duration(milliseconds: 250), () {
      _subscribeToMapJobs();
    });
  }

  void _scheduleAutoApply({
    Duration delay = const Duration(milliseconds: 700),
  }) {
    _applyDebounce?.cancel();
    _applyDebounce = Timer(delay, () {
      _applySettings();
    });
  }

  Future<void> _applySettings() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isApplyingSettings) {
      _reapplySettings = true;
      return;
    }

    if (_mode == SelectionMode.radius && _currentLocation == null) {
      return;
    }

    final address = _addressController.text.trim();
    if (_mode == SelectionMode.zones && _selectedZoneIds.isEmpty) {
      if (address.isEmpty) return;
      _isApplyingSettings = true;
      try {
        await ref.read(authProvider.notifier).updateProfile(
              address: address,
              latitude: _currentLocation?.latitude,
              longitude: _currentLocation?.longitude,
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.instructorMapErrorSavingSettings(e.toString())),
            ),
          );
        }
      } finally {
        _isApplyingSettings = false;
      }
      return;
    }

    _isApplyingSettings = true;
    try {
      if (_mode == SelectionMode.radius) {
        await ref.read(authProvider.notifier).updateDispatchPreferences(
              dispatchMode: 'radius',
              radiusKm: _radiusKm,
              latitude: _currentLocation!.latitude,
              longitude: _currentLocation!.longitude,
              address: address.isEmpty ? null : address,
            );
      } else {
        await ref.read(authProvider.notifier).updateDispatchPreferences(
              dispatchMode: 'zone',
              zoneIds: _selectedZoneIds.toList(),
              address: address.isEmpty ? null : address,
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(l10n.instructorMapErrorSavingSettings(e.toString()))),
        );
      }
    } finally {
      _isApplyingSettings = false;
      if (_reapplySettings) {
        _reapplySettings = false;
        _scheduleAutoApply(delay: Duration.zero);
      }
    }
  }

  Map<String, String> _buildMapJobsArgs() {
    final mapCategories =
        FitnessCategory.values.map((c) => c.id).join(',');
    return {
      'latitude': _currentLocation!.latitude.toString(),
      'longitude': _currentLocation!.longitude.toString(),
      'radiusKm': _radiusKm.toString(),
      // Map discovery should surface all nearby studios with open jobs.
      'categories': mapCategories,
      'isVerified': ref.read(authProvider).isVerified.toString(),
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

    final args = _mode == SelectionMode.radius
        ? _buildMapJobsArgs()
        : <String, String>{};
    final zoneArgs = <String, String>{
      'zoneIds': json.encode(_selectedZoneIds.toList()),
      // Keep map consistent across radius/zone mode: show all available studios.
      'categories': FitnessCategory.values.map((c) => c.id).join(','),
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
        args: _mode == SelectionMode.zones ? zoneArgs : args,
        onUpdate: _handleMapJobsUpdate,
        onError: (message, value) {
          developer.log(
            'Map job subscription error: $message',
            name: 'instructor_map',
            error: value,
          );
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
      final studioBuckets = <String, Map<String, dynamic>>{};
      for (final raw in parsed) {
        final job = Map<String, dynamic>.from(raw as Map);
        final studioId =
            (job['studioId'] as String?) ?? (job['_id'] as String?) ?? '';
        if (studioId.isEmpty) continue;

        final lat = (job['latitude'] as num?)?.toDouble();
        final lng = (job['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final existing = studioBuckets[studioId];
        if (existing == null) {
          final createdAt = (job['createdAt'] as num?)?.toInt() ??
              (job['_creationTime'] as num?)?.toInt();
          studioBuckets[studioId] = {
            'studioId': studioId,
            'studioName': (job['studioName'] as String?) ?? 'Studio',
            'latitude': lat,
            'longitude': lng,
            'jobCount': 1,
            'isSos': job['sosBoostApplied'] as bool? ?? false,
            'currentRate': (job['currentRate'] as num?)?.toDouble(),
            'distanceKm': ((job['distanceMeters'] as num?) ?? 0) / 1000,
            'latestPostedAt': createdAt,
          };
          continue;
        }
        existing['jobCount'] = (existing['jobCount'] as int) + 1;
        existing['isSos'] =
            (existing['isSos'] as bool) || (job['sosBoostApplied'] as bool? ?? false);
        final candidateRate = (job['currentRate'] as num?)?.toDouble();
        if (candidateRate != null) {
          final existingRate = existing['currentRate'] as double?;
          if (existingRate == null || candidateRate > existingRate) {
            existing['currentRate'] = candidateRate;
          }
        }
        final createdAt = (job['createdAt'] as num?)?.toInt() ??
            (job['_creationTime'] as num?)?.toInt();
        final latestPostedAt = existing['latestPostedAt'] as int?;
        if (createdAt != null &&
            (latestPostedAt == null || createdAt > latestPostedAt)) {
          existing['latestPostedAt'] = createdAt;
        }
      }

      final jobs = studioBuckets.values.map((bucket) {
        final count = bucket['jobCount'] as int;
        final studioName = bucket['studioName'] as String? ?? 'Studio';
        final latestPostedAt = bucket['latestPostedAt'] as int?;
        final postedLabel = _formatPostedAt(latestPostedAt);
        final countLabel = count > 1 ? '$studioName ($count)' : studioName;
        final label = postedLabel != null ? '$countLabel • $postedLabel' : countLabel;
        return QuickFitJobMarker(
          id: bucket['studioId'] as String,
          studioId: bucket['studioId'] as String,
          position: LatLng(
            bucket['latitude'] as double,
            bucket['longitude'] as double,
          ),
          label: label,
          isSos: bucket['isSos'] as bool,
          currentRate: bucket['currentRate'] as double?,
          distanceKm: bucket['distanceKm'] as double?,
          jobCount: count,
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

  String? _formatPostedAt(int? timestampMs) {
    if (timestampMs == null || timestampMs <= 0) return null;
    final postedAt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final isToday = postedAt.year == now.year &&
        postedAt.month == now.month &&
        postedAt.day == now.day;
    if (isToday) {
      final hh = postedAt.hour.toString().padLeft(2, '0');
      final mm = postedAt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${postedAt.month}/${postedAt.day}';
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

  Future<void> _setPinFromAddress({
    double? latitude,
    double? longitude,
    String? addressOverride,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final typedAddress = _addressController.text.trim();
    final query = addressOverride?.trim().isNotEmpty == true
        ? addressOverride!.trim()
        : typedAddress;
    if (query.isEmpty || _isResolvingAddress) return;

    late final LatLng point;
    if (latitude != null && longitude != null) {
      point = LatLng(latitude, longitude);
    } else {
      setState(() => _isResolvingAddress = true);
      try {
        final position =
            await LocationService.instance.getLatLngFromAddress(query);
        if (!mounted) return;
        if (position == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.instructorMapAddressNotFound)),
          );
          return;
        }
        point = LatLng(position.latitude, position.longitude);
      } finally {
        if (mounted) setState(() => _isResolvingAddress = false);
      }
    }
    if (!mounted) return;

    setState(() {
      _currentLocation = point;
      _isPinDropMode = false;
      _addressController.text = query;
    });
    _scheduleMapJobsResubscribe();
    _scheduleAutoApply(delay: const Duration(milliseconds: 120));
    await _mapKey.currentState?.animateTo(point, zoom: 13.5);
    await _mapKey.currentState?.updateHomePin(point);
    await _mapKey.currentState?.updateRadiusCenter(point);
  }

  void _applyAddressSuggestion({
    required String address,
    required double? latitude,
    required double? longitude,
  }) {
    _addressController.text = address;
    _setPinFromAddress(
      latitude: latitude,
      longitude: longitude,
      addressOverride: address,
    );
  }

  void _onRadiusPreviewChanged(double radius) {
    _previewRadiusKm = radius;
    if (_mode != SelectionMode.radius) return;

    _radiusPreviewThrottle?.cancel();
    _radiusPreviewThrottle = Timer(const Duration(milliseconds: 70), () {
      if (!mounted || _mode != SelectionMode.radius) return;
      _mapKey.currentState?.updateRadius(
        _previewRadiusKm,
        center: _currentLocation,
      );
    });
  }

  void _onRadiusPreviewCommit() {
    _radiusPreviewThrottle?.cancel();
    if ((_radiusKm - _previewRadiusKm).abs() > 0.001) {
      setState(() {
        _radiusKm = _previewRadiusKm;
      });
    }
    _scheduleMapJobsResubscribe();
    _scheduleAutoApply();
  }

  void _toggleDropPinMode() {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isPinDropMode = !_isPinDropMode);
    if (_isPinDropMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.instructorMapTapToDropPin)),
      );
    }
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    _jobsSubscriptionDebounce?.cancel();
    _applyDebounce?.cancel();
    _radiusPreviewThrottle?.cancel();
    _locationSubscription?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    _hydrateFromAuthState(authState);
    final zonesAsync = ref.watch(zonesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          InstructorMapView(
            mapKey: _mapKey,
            mode: _mode,
            currentLocation: _currentLocation,
            radiusKm: _previewRadiusKm,
            interactionEnabled: true,
            jobs: _parsedJobs,
            selectedZoneIds: _selectedZoneIds,
            zonesAsync: zonesAsync,
            onZoneSelectionChanged: (zones) {
              setState(() {
                _selectedZoneIds = zones;
              });
              _scheduleMapJobsResubscribe();
              _scheduleAutoApply();
            },
            onMapTap: (point) {
              if (_mode == SelectionMode.radius && _isPinDropMode) {
                setState(() {
                  _currentLocation = point;
                  _isPinDropMode = false;
                });
                _scheduleMapJobsResubscribe();
                _scheduleAutoApply(delay: Duration.zero);
                _mapKey.currentState?.updateHomePin(point);
              }
            },
            onJobTapped: (studioId) {
              context.push(
                AppRoutes.studioPublicProfile.replaceFirst(':id', studioId),
              );
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 16),
              child: MapSettingsSheet(
                mode: _mode,
                radiusKm: _previewRadiusKm,
                selectedZoneIds: _selectedZoneIds,
                isExpanded: _isSettingsExpanded,
                addressController: _addressController,
                isResolvingAddress: _isResolvingAddress,
                isPinDropMode: _isPinDropMode,
                onToggleExpanded: () {
                  setState(() => _isSettingsExpanded = !_isSettingsExpanded);
                },
                onTogglePinDropMode: _toggleDropPinMode,
                onApplyAddress: () => _setPinFromAddress(),
                onAddressSelected: _applyAddressSuggestion,
                onModeChanged: (mode) {
                  setState(() {
                    _mode = mode;
                    _isPinDropMode = false;
                    if (mode == SelectionMode.radius) {
                      _previewRadiusKm = _radiusKm;
                    }
                  });
                  _scheduleMapJobsResubscribe();
                  _scheduleAutoApply();
                },
                onRadiusChanged: _onRadiusPreviewChanged,
                onRadiusChangeEnd: _onRadiusPreviewCommit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
