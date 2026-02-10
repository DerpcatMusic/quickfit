// QuickFit Map Widget - Foundational MapLibre Wrapper
// Reusable map component for instructor map, onboarding, and future screens
// lib/shared/widgets/quickfit_map.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:quickfit/core/config/map_config.dart';
import 'package:quickfit/core/services/map_style_service.dart';

/// A reusable MapLibre map widget styled for QuickFit.
///
/// Features:
/// - Automatic dark/light theme switching
/// - Built-in radius circle visualization
/// - Job marker layer support
/// - Optimized for Israel region
///
/// Example:
/// ```dart
/// QuickFitMap(
///   initialCenter: LatLng(32.0853, 34.7818),
///   initialZoom: 13,
///   radiusKm: 5.0,
///   jobs: myJobsList,
///   onJobTapped: (jobId) => showJobDetails(jobId),
/// )
/// ```
class QuickFitMap extends StatefulWidget {
  const QuickFitMap({
    super.key,
    this.initialCenter,
    this.initialZoom = MapConfig.defaultZoom,
    this.radiusKm,
    this.radiusCenter,
    this.showUserLocation = true,
    this.showRadius = true,
    this.showHomePin = false,
    this.jobs = const [],
    this.onMapCreated,
    this.onJobTapped,
    this.onCameraMove,
    this.onStyleLoaded,
    this.onMapTap,
    this.interactionEnabled = true,
  });

  /// Initial center of the map. Defaults to Tel Aviv if null.
  final LatLng? initialCenter;

  /// Initial zoom level.
  final double initialZoom;

  /// Radius in kilometers to display around user location.
  final double? radiusKm;

  /// Center of the radius circle. If null, uses initialCenter.
  final LatLng? radiusCenter;

  /// Whether to show the user's current location.
  final bool showUserLocation;

  /// Whether to show the radius circle.
  final bool showRadius;

  /// Whether to show a home pin marker at the radius center.
  final bool showHomePin;

  /// List of jobs to display as markers.
  final List<QuickFitJobMarker> jobs;

  /// Callback when the map controller is ready.
  final void Function(MapLibreMapController controller)? onMapCreated;

  /// Callback when a job marker is tapped.
  final void Function(String jobId)? onJobTapped;

  /// Callback when camera moves.
  final void Function(CameraPosition position)? onCameraMove;

  /// Callback when map style is fully loaded.
  final VoidCallback? onStyleLoaded;

  /// Callback when map is tapped (for dropping pins).
  final void Function(LatLng position)? onMapTap;

  /// Whether user can interact with the map.
  final bool interactionEnabled;

  @override
  State<QuickFitMap> createState() => QuickFitMapState();
}

/// Public state for external controller access.
///
/// Uses [AutomaticKeepAliveClientMixin] to prevent disposal when the widget
/// is hidden (e.g., in a PageView or Visibility wrapper). This is critical
/// for maps which are expensive to reinitialize.
class QuickFitMapState extends State<QuickFitMap>
    with AutomaticKeepAliveClientMixin {
  final Completer<MapLibreMapController> _controllerCompleter = Completer();
  MapLibreMapController? _controller;
  bool _styleLoaded = false;

  // Radius circle state - simple boolean for complete state
  bool _radiusReady = false;
  Symbol? _homePinSymbol;
  bool _jobsReady = false;
  int _jobsSignature = 0;
  LatLng? _lastRadiusCenter;

  /// Get the underlying MapLibre controller for advanced operations.
  Future<MapLibreMapController> get controller => _controllerCompleter.future;

  /// Whether the map style has finished loading.
  bool get isStyleLoaded => _styleLoaded;

  // Layer IDs for radius visualization (ordered: glow -> fill -> stroke)
  static const String _radiusGlowId = 'radius-glow';
  static const String _radiusFillId = 'radius-fill';
  static const String _radiusLineId = 'radius-line';
  static const String _radiusSourceId = 'radius-source';
  static const String _jobsSourceId = 'jobs-source';
  static const String _jobsCircleId = 'jobs-circles';
  static const String _jobsLabelId = 'jobs-labels';

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(QuickFitMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleLoaded) {
      // Only update if values actually changed
      final radiusChanged = widget.radiusKm != oldWidget.radiusKm ||
          widget.radiusCenter != oldWidget.radiusCenter;
      final visibilityChanged = widget.showRadius != oldWidget.showRadius;

      if (radiusChanged || visibilityChanged) {
        if (widget.showRadius && widget.radiusKm != null) {
          updateRadius(widget.radiusKm!, center: widget.radiusCenter);
        } else if (!widget.showRadius && _radiusReady) {
          _removeRadiusCircle();
        }
      }
      final nextSignature = _computeJobsSignature(widget.jobs);
      if (nextSignature != _jobsSignature) {
        _jobsSignature = nextSignature;
        updateJobs(widget.jobs);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final brightness = Theme.of(context).brightness;
    final styleString = MapStyleService.getStyleString(brightness);

    final center = widget.initialCenter ??
        const LatLng(MapConfig.defaultLatitude, MapConfig.defaultLongitude);

    // Wrap in a colored container to prevent white flash while map loads
    // This creates a "lightning fast" perceived performance
    return Container(
      color: brightness == Brightness.dark
          ? const Color(0xFF0D0D0F) // Match QuickFitMapTheme.backgroundDark
          : const Color(0xFFF5F5F5), // Match Light theme background
      child: MapLibreMap(
        styleString: styleString,
        initialCameraPosition: CameraPosition(
          target: center,
          zoom: widget.initialZoom,
        ),
        minMaxZoomPreference:
            const MinMaxZoomPreference(MapConfig.minZoom, MapConfig.maxZoom),
        myLocationEnabled: widget.showUserLocation && !kIsWeb, // Disable on web
        myLocationTrackingMode: MyLocationTrackingMode.none,
        // myLocationRenderMode: MyLocationRenderMode.compass, // Removed for web compatibility
        trackCameraPosition: true,
        compassEnabled: false,
        rotateGesturesEnabled: widget.interactionEnabled,
        scrollGesturesEnabled: widget.interactionEnabled,
        tiltGesturesEnabled: false, // Keep 2D for clarity
        zoomGesturesEnabled: widget.interactionEnabled,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        onCameraIdle: _onCameraIdle,
        onMapClick: _handleMapClick,
        // Hide the attribution on the bottom right as it impacts the premium "avant-garde" look.
        // We ensure attribution is handled in legal/about sections of the app.
        attributionButtonMargins: kIsWeb ? null : const math.Point(-100, -100),
      ),
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    _controllerCompleter.complete(controller);
    widget.onMapCreated?.call(controller);
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    _radiusReady = false; // Reset on new style load
    _jobsReady = false;

    // Add radius visualization if enabled
    if (widget.showRadius && widget.radiusKm != null) {
      await _addRadiusCircle();
    }

    // Add home pin marker at radius center if enabled
    if (widget.showHomePin) {
      await _addHomePin();
    }

    await _ensureJobLayers();
    await _updateJobsSource(widget.jobs);
    _jobsSignature = _computeJobsSignature(widget.jobs);

    widget.onStyleLoaded?.call();
  }

  Future<void> _onCameraIdle() async {
    final controller = await _controllerCompleter.future;
    final position = controller.cameraPosition;
    if (position != null) {
      widget.onCameraMove?.call(position);
    }
  }

  // ===========================================================================
  // PUBLIC METHODS FOR EXTERNAL CONTROL
  // ===========================================================================

  /// Animate camera to a specific location.
  Future<void> animateTo(LatLng target, {double? zoom}) async {
    final controller = await _controllerCompleter.future;

    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom ?? widget.initialZoom),
      duration: MapConfig.cameraAnimationDuration,
    );
  }

  /// Update the radius circle size.
  Future<void> updateRadius(double radiusKm, {LatLng? center}) async {
    if (!_styleLoaded) return;

    final controller = await _controllerCompleter.future;
    final cameraCenter = controller.cameraPosition?.target;
    final circleCenter = center ??
        widget.radiusCenter ??
        _lastRadiusCenter ??
        cameraCenter ??
        widget.initialCenter ??
        const LatLng(MapConfig.defaultLatitude, MapConfig.defaultLongitude);

    _lastRadiusCenter = circleCenter;

    if (_radiusReady) {
      await _updateRadiusSource(circleCenter, radiusKm);
    } else {
      await _addRadiusCircleAt(circleCenter, radiusKm);
    }
  }

  /// Update job markers on the map.
  Future<void> updateJobs(List<QuickFitJobMarker> jobs) async {
    if (!_styleLoaded) return;
    await _ensureJobLayers();
    await _updateJobsSource(jobs);
  }

  /// Update just the radius center (when user drops a pin).
  Future<void> updateRadiusCenter(LatLng center) async {
    if (!_styleLoaded) return;
    final radiusKm = widget.radiusKm ?? 10.0;
    _lastRadiusCenter = center;

    if (_radiusReady) {
      await _updateRadiusSource(center, radiusKm);
    } else {
      await _addRadiusCircleAt(center, radiusKm);
    }

    if (widget.showHomePin) {
      await updateHomePin(center);
    }
  }

  /// Update the home pin position.
  Future<void> updateHomePin(LatLng position) async {
    final controller = await _controllerCompleter.future;
    if (_homePinSymbol != null) {
      await controller.updateSymbol(
          _homePinSymbol!, SymbolOptions(geometry: position));
    } else {
      // If not exists, add it
      await _addHomePin(positionOverride: position);
    }
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  Future<void> _addRadiusCircle() async {
    final center = widget.radiusCenter ?? widget.initialCenter;
    if (center == null || widget.radiusKm == null) return;
    _lastRadiusCenter = center;
    await _addRadiusCircleAt(center, widget.radiusKm!);
  }

  Future<void> _addRadiusCircleAt(LatLng center, double radiusKm) async {
    _lastRadiusCenter = center;
    // Already set up? Just update
    if (_radiusReady) {
      await _updateRadiusSource(center, radiusKm);
      return;
    }

    // Capture color before await to avoid use_build_context_synchronously
    final theme = Theme.of(context);
    final primaryColorHex = _colorToHex(theme.colorScheme.primary);

    final controller = await _controllerCompleter.future;
    if (!mounted) return;

    // Create a GeoJSON circle polygon (approximated with 64 points)
    final circleGeoJson = _createCircleGeoJson(center, radiusKm * 1000);

    // On Web, a small delay ensures MapLibre web worker is ready
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
    }

    try {
      // Add GeoJSON source
      await controller.addGeoJsonSource(
        _radiusSourceId,
        circleGeoJson,
      );

      // Add outer glow layer (wider, softer stroke for premium effect)
      await controller.addLineLayer(
        _radiusSourceId,
        _radiusGlowId,
        LineLayerProperties(
          lineColor: primaryColorHex,
          lineWidth: MapConfig.radiusGlowWidth,
          lineOpacity: MapConfig.radiusGlowOpacity,
          lineBlur: 4.0, // Soft glow effect
        ),
      );

      // Add fill layer with subtle transparency
      await controller.addFillLayer(
        _radiusSourceId,
        _radiusFillId,
        FillLayerProperties(
          fillColor: primaryColorHex,
          fillOpacity: MapConfig.radiusFillOpacity,
        ),
      );

      // Add stroke layer (crisp inner stroke)
      await controller.addLineLayer(
        _radiusSourceId,
        _radiusLineId,
        LineLayerProperties(
          lineColor: primaryColorHex,
          lineWidth: MapConfig.radiusStrokeWidth,
          lineOpacity: MapConfig.radiusStrokeOpacity,
        ),
      );

      _radiusReady = true;
    } catch (e) {
      debugPrint('Error adding radius circle: $e');
      _radiusReady = false;
    }
  }

  /// Update existing radius source with new data (more efficient than remove+add)
  Future<void> _updateRadiusSource(LatLng center, double radiusKm) async {
    // Only update if source is fully ready
    if (!_radiusReady) return;

    final controller = await _controllerCompleter.future;
    if (!mounted) return;

    final circleGeoJson = _createCircleGeoJson(center, radiusKm * 1000);

    try {
      await controller.setGeoJsonSource(_radiusSourceId, circleGeoJson);
    } catch (e) {
      debugPrint('Error updating radius source: $e');
    }
  }

  Future<void> _removeRadiusCircle() async {
    if (!_radiusReady) return;

    final controller = await _controllerCompleter.future;

    try {
      await controller.removeLayer(_radiusLineId);
      await controller.removeLayer(_radiusFillId);
      await controller.removeLayer(_radiusGlowId);
      await controller.removeSource(_radiusSourceId);
    } catch (_) {
      // Layers may not exist, ignore
    } finally {
      _radiusReady = false;
    }
  }

  Future<void> _ensureJobLayers() async {
    if (_jobsReady) return;
    final controller = await _controllerCompleter.future;
    if (!mounted) return;

    try {
      await controller.addGeoJsonSource(_jobsSourceId, {
        'type': 'FeatureCollection',
        'features': [],
      });

      await controller.addCircleLayer(
        _jobsSourceId,
        _jobsCircleId,
        const CircleLayerProperties(
          circleColor: [
            'case',
            ['get', 'isSos'],
            '#F44336',
            '#4CAF50',
          ],
          circleRadius: 8,
          circleStrokeWidth: 2,
          circleStrokeColor: '#FFFFFF',
        ),
      );

      await controller.addSymbolLayer(
        _jobsSourceId,
        _jobsLabelId,
        const SymbolLayerProperties(
          textField: ['get', 'label'],
          textSize: 12,
          textColor: '#FFFFFF',
          textHaloColor: '#000000',
          textHaloWidth: 1,
          textOffset: [0, 1.5],
          textAnchor: 'top',
        ),
      );

      _jobsReady = true;
    } catch (e) {
      debugPrint('Error adding job layers: $e');
      _jobsReady = false;
    }
  }

  Future<void> _updateJobsSource(List<QuickFitJobMarker> jobs) async {
    if (!_jobsReady) return;
    final controller = await _controllerCompleter.future;
    if (!mounted) return;

    final features = jobs.map((job) {
      return {
        'type': 'Feature',
        'properties': {
          'jobId': job.id,
          'label': job.label,
          'isSos': job.isSos,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [job.position.longitude, job.position.latitude],
        },
      };
    }).toList();

    try {
      await controller.setGeoJsonSource(_jobsSourceId, {
        'type': 'FeatureCollection',
        'features': features,
      });
    } catch (e) {
      debugPrint('Error updating job source: $e');
    }
  }

  /// Add a home pin marker at the radius center.
  Future<void> _addHomePin({LatLng? positionOverride}) async {
    final center =
        positionOverride ?? widget.radiusCenter ?? widget.initialCenter;
    if (center == null) return;

    final controller = await _controllerCompleter.future;
    if (!mounted) return;

    // Add a prominent marker at the home location
    _homePinSymbol = await controller.addSymbol(
      SymbolOptions(
        geometry: center,
        iconSize: 1.5,
        textField: 'HOME',
        textSize: 24,
        textOffset: const Offset(0, 0),
      ),
    );
  }

  /// Create a GeoJSON polygon representing a circle.
  Map<String, dynamic> _createCircleGeoJson(
      LatLng center, double radiusMeters) {
    const int points = 64;
    final coordinates = <List<double>>[];

    for (int i = 0; i <= points; i++) {
      final angle = (i * 360 / points) * (math.pi / 180);
      final dx = radiusMeters * math.cos(angle);
      final dy = radiusMeters * math.sin(angle);

      // Convert meters to degrees with higher precision
      // Earth's radius is approximately 6371km. 1 degree of latitude is ~111.32km.
      // 1 degree of longitude is ~111.32km * cos(latitude).
      final lat = center.latitude + (dy / 111320.0);
      final lng = center.longitude +
          (dx / (111319.49 * math.cos(center.latitude * math.pi / 180.0)));

      coordinates.add([lng, lat]);
    }

    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Polygon',
            'coordinates': [coordinates],
          },
          'properties': {},
        },
      ],
    };
  }

  String _colorToHex(Color color) {
    // Flutter 3.x compatible: use toARGB32() to get raw ARGB integer
    final argb = color.toARGB32();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Future<void> _handleMapClick(math.Point<double> point, LatLng latLng) async {
    final controller = _controller;
    if (controller != null && widget.onJobTapped != null) {
      try {
        final features = await controller.queryRenderedFeatures(
          point,
          [_jobsCircleId, _jobsLabelId],
          null,
        );
        if (features.isNotEmpty) {
          final props = features.first['properties'];
          final jobId = props?['jobId'];
          if (jobId != null) {
            widget.onJobTapped?.call(jobId.toString());
            return;
          }
        }
      } catch (e) {
        debugPrint('Error handling job tap: $e');
      }
    }
    widget.onMapTap?.call(latLng);
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

  @override
  void dispose() {
    super.dispose();
  }
}

/// A job marker for display on QuickFitMap.
class QuickFitJobMarker {
  const QuickFitJobMarker({
    required this.id,
    required this.position,
    required this.label,
    this.isSos = false,
    this.currentRate,
    this.distanceKm,
  });

  /// Unique job ID.
  final String id;

  /// Geographic position.
  final LatLng position;

  /// Display label (e.g., job title).
  final String label;

  /// Whether this is an SOS urgent job.
  final bool isSos;

  /// Current rate in ILS.
  final double? currentRate;

  /// Distance from instructor in km.
  final double? distanceKm;
}
