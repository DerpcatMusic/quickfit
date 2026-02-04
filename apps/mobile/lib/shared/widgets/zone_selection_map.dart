/// Zone Selection Map Widget
///
/// Displays Pikud HaOref zones as selectable polygons on a MapLibre map.
/// Uses a hierarchical view: City Clusters (Low Zoom) -> Zone Polygons (High Zoom).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:quickfit/shared/widgets/quickfit_map.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:quickfit/core/services/map_style_service.dart';
import 'package:quickfit/core/models/zone.dart';
import 'package:quickfit/core/constants/map_constants.dart';

// Zone and CityCluster are now imported from core/models/zone.dart

/// Callback for zone selection changes
typedef OnZoneSelectionChanged = void Function(Set<String> selectedZoneIds);

/// Interactive zone selection map with polygon overlays and city clustering
class ZoneSelectionMap extends StatefulWidget {
  /// Initial set of selected zone IDs
  final Set<String> initialSelectedZones;

  /// Called when selection changes
  final OnZoneSelectionChanged? onSelectionChanged;

  /// List of zones to display (fetched from Convex)
  final List<Zone> zones;

  /// Initial map center (defaults to Israel center)
  final LatLng? initialCenter;

  /// Initial zoom level
  final double initialZoom;
  final List<QuickFitJobMarker>? jobs;
  final Function(String jobId)? onJobTap;
  final double topPadding;

  const ZoneSelectionMap({
    super.key,
    this.initialSelectedZones = const {},
    this.onSelectionChanged,
    required this.zones,
    this.initialCenter,
    this.initialZoom = 8,
    this.jobs,
    this.onJobTap,
    this.topPadding = 0,
  });

  @override
  State<ZoneSelectionMap> createState() => _ZoneSelectionMapState();
}

class _ZoneSelectionMapState extends State<ZoneSelectionMap> {
  MapLibreMapController? _controller;
  late Set<String> _selectedZoneIds;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isMapReady = false;
  List<CityCluster> _cityClusters = [];

  // Click delay for web - distinguish click from drag
  DateTime? _pointerDownTime;

  // Israel center
  static const _israelCenter = LatLng(31.5, 34.8);

  @override
  void initState() {
    super.initState();
    _selectedZoneIds = Set.from(widget.initialSelectedZones);
    _updateCityClusters();
  }

  void _updateCityClusters() {
    final Map<String, List<Zone>> groups = {};
    for (final z in widget.zones) {
      // Use explicit city field, or heuristic from name
      final city =
          (z.city != null && z.city!.isNotEmpty) ? z.city! : _extractCity(z);
      if (city.isEmpty) continue;
      groups.putIfAbsent(city, () => []).add(z);
    }

    _cityClusters = groups.entries.map((entry) {
      final zones = entry.value;
      // Calculate centroid and bounding polygon for city
      double lat = 0;
      double lng = 0;
      double minLat = double.infinity;
      double maxLat = double.negativeInfinity;
      double minLng = double.infinity;
      double maxLng = double.negativeInfinity;

      for (final z in zones) {
        lat += z.centroid.latitude;
        lng += z.centroid.longitude;
        // Build bounding box from all zone polygons
        for (final p in z.polygon) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }
      }

      // Create bounding box polygon for city
      final bounds = [
        LatLng(minLat, minLng),
        LatLng(minLat, maxLng),
        LatLng(maxLat, maxLng),
        LatLng(maxLat, minLng),
        LatLng(minLat, minLng), // Close the polygon
      ];

      return CityCluster(
        name: entry.key,
        centroid: LatLng(lat / zones.length, lng / zones.length),
        zoneCount: zones.length,
        bounds: bounds,
      );
    }).toList();
  }

  String _extractCity(Zone z) {
    if (z.nameHebrew.contains('-')) return z.nameHebrew.split('-')[0].trim();
    if (z.nameHebrew.contains(' ')) return z.nameHebrew.split(' ')[0].trim();
    return z.nameHebrew;
  }

  @override
  void didUpdateWidget(ZoneSelectionMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.zones != oldWidget.zones) {
      _updateCityClusters();
      if (_isMapReady) {
        _updateSources();
      }
    }
    if (widget.jobs != oldWidget.jobs && _isMapReady) {
      _updateJobSource();
    }
    if (widget.initialSelectedZones != oldWidget.initialSelectedZones) {
      _selectedZoneIds = Set.from(widget.initialSelectedZones);
      if (_isMapReady) _updateSelectedSource();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    if (_controller == null) return;
    setState(() => _isMapReady = true);
    await _setupLayers();
  }

  Future<void> _setupLayers() async {
    final controller = _controller;
    if (controller == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Add Sources (NO city polygon source - it looked ugly!)
    await _addCitySource();
    await _addStaticZoneSource();
    await _addSelectedZoneSource();

    if (!mounted) return;

    // 2. Add Layers

    // Dynamic Colors
    final cityColor = isDark ? '#90CAF9' : '#0D47A1'; // Blue 200 vs 900
    final cityHalo = isDark ? '#000000' : '#ffffff';
    final zoneStaticFill = isDark ? '#FFFFFF' : '#000000';
    final zoneStaticBorder = isDark ? '#78909C' : '#90A4AE'; // Blue Grey
    final zoneSelectedFill = isDark ? '#64B5F6' : '#1565C0';
    final zoneSelectedBorder = isDark ? '#BBDEFB' : '#0D47A1';
    final zoneLabelColor = isDark ? '#E3F2FD' : '#1A237E';

    // ─────────────────────────────────────────────────────────────
    // ZONES - Visible at ALL zoom levels
    // ─────────────────────────────────────────────────────────────

    // Zone fills - always visible (opacity varies by zoom would be nice but keep simple)
    await controller.addFillLayer(
      'zones-static',
      'zones-unselected',
      FillLayerProperties(
        fillColor: zoneStaticFill,
        fillOpacity: MapConstants.zoneUnselectedOpacity,
      ),
      // NO minzoom - zones always visible!
    );

    // Zone borders - always visible
    await controller.addLineLayer(
      'zones-static',
      'zones-border',
      LineLayerProperties(
        lineColor: zoneStaticBorder,
        lineWidth: MapConstants.zoneBorderWidth,
        lineOpacity: MapConstants.zoneBorderOpacity,
      ),
      // NO minzoom - zones always visible!
    );

    // ─────────────────────────────────────────────────────────────
    // SELECTED ZONES - Prominent highlight
    // ─────────────────────────────────────────────────────────────

    await controller.addFillLayer(
      'zones-selected',
      'zones-selected-fill',
      FillLayerProperties(
        fillColor: zoneSelectedFill,
        fillOpacity: MapConstants.zoneSelectedOpacity,
      ),
    );

    await controller.addLineLayer(
      'zones-selected',
      'zones-selected-border',
      LineLayerProperties(
        lineColor: zoneSelectedBorder,
        lineWidth: MapConstants.zoneSelectedBorderWidth,
        lineOpacity: 1.0,
      ),
    );

    // ─────────────────────────────────────────────────────────────
    // CITY LABELS - Just text, no ugly polygons
    // ─────────────────────────────────────────────────────────────

    await controller.addCircleLayer(
      'cities',
      'cities-circles',
      CircleLayerProperties(
        circleColor: cityColor,
        circleRadius: 5,
        circleOpacity: 0.9,
        circleStrokeWidth: 2,
        circleStrokeColor: cityHalo,
      ),
      maxzoom: MapConstants.cityToZoneZoomThreshold,
    );

    await controller.addSymbolLayer(
      'cities',
      'cities-labels',
      SymbolLayerProperties(
        textField: ['get', 'name'],
        textSize: MapConstants.cityLabelSize,
        textColor: cityColor,
        textHaloColor: cityHalo,
        textHaloWidth: MapConstants.textHaloWidth,
        textAnchor: 'top',
        textOffset: [0, 0.5],
        textFont: ['Open Sans Bold', 'Arial Unicode MS Bold'],
      ),
      maxzoom: MapConstants.cityToZoneZoomThreshold,
    );

    // ─────────────────────────────────────────────────────────────
    // ZONE LABELS - At higher zoom
    // ─────────────────────────────────────────────────────────────

    await controller.addSymbolLayer(
      'zones-static',
      'zones-labels',
      SymbolLayerProperties(
        textField: ['get', 'nameHebrew'],
        textSize: MapConstants.zoneLabelSize,
        textColor: zoneLabelColor,
        textHaloColor: cityHalo,
        textHaloWidth: MapConstants.textHaloWidth,
        textAllowOverlap: false,
      ),
      minzoom: MapConstants.zoneLabelMinZoom,
    );

    // Jobs (Top Layer)
    await _addJobSource();
    if (widget.jobs != null) {
      await controller.addCircleLayer(
        'jobs',
        'jobs-circles',
        const CircleLayerProperties(
          circleColor: [
            'case',
            ['get', 'isSos'],
            '#F44336', // Red for SOS
            '#4CAF50' // Green for Normal
          ],
          circleRadius: 8,
          circleStrokeWidth: 2,
          circleStrokeColor: '#FFFFFF',
        ),
      );

      await controller.addSymbolLayer(
        'jobs',
        'jobs-labels',
        SymbolLayerProperties(
          textField: [
            'concat',
            '₪',
            [
              'to-string',
              ['get', 'rate']
            ]
          ],
          textSize: 12,
          textColor: '#1B5E20',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2,
          textOffset: [0, 1.4],
          textAnchor: 'top',
        ),
      );
    }
  }

  Future<void> _addCitySource() async {
    if (_controller == null) return;
    final features = _cityClusters.map((c) {
      return {
        'type': 'Feature',
        'id': c.name.hashCode,
        'properties': {
          'name': c.name,
          'count': c.zoneCount,
          'lat': c.centroid.latitude,
          'lng': c.centroid.longitude,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [c.centroid.longitude, c.centroid.latitude],
        },
      };
    }).toList();

    await _controller!.addGeoJsonSource('cities', {
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  Future<void> _updateJobSource() async {
    if (_controller == null || widget.jobs == null) return;

    final features = widget.jobs!.map((job) {
      return {
        'type': 'Feature',
        'properties': {
          'jobId': job.id,
          'rate': job.currentRate ?? 0,
          'isSos': job.isSos,
          'label': job.label,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [job.position.longitude, job.position.latitude],
        },
      };
    }).toList();

    await _controller!.setGeoJsonSource('jobs', {
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  Future<void> _addJobSource() async {
    if (_controller == null) return;
    await _controller!.addGeoJsonSource('jobs', {
      'type': 'FeatureCollection',
      'features': [],
    });
    if (widget.jobs != null && widget.jobs!.isNotEmpty) {
      _updateJobSource();
    }
  }

  Future<void> _addStaticZoneSource() async {
    if (_controller == null) return;
    final features = widget.zones.map((zone) {
      final coordinates =
          zone.polygon.map((p) => [p.longitude, p.latitude]).toList();
      if (coordinates.isNotEmpty) coordinates.add(coordinates.first);

      return {
        'type': 'Feature',
        'properties': {
          'zoneId': zone.id,
          'name': zone.name,
          'nameHebrew': zone.nameHebrew,
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [coordinates],
        },
      };
    }).toList();

    await _controller!.addGeoJsonSource('zones-static', {
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  Future<void> _addSelectedZoneSource() async {
    if (_controller == null) return;
    await _controller!.addGeoJsonSource('zones-selected', {
      'type': 'FeatureCollection',
      'features': [],
    });
    _updateSelectedSource();
  }

  Future<void> _updateSelectedSource() async {
    if (!_isMapReady || _controller == null) return;

    final selectedZones =
        widget.zones.where((z) => _selectedZoneIds.contains(z.id)).toList();

    final features = selectedZones.map((zone) {
      final coordinates =
          zone.polygon.map((p) => [p.longitude, p.latitude]).toList();
      if (coordinates.isNotEmpty) coordinates.add(coordinates.first);

      return {
        'type': 'Feature',
        'properties': {'selected': true, 'zoneId': zone.id},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [coordinates],
        },
      };
    }).toList();

    try {
      await _controller!.setGeoJsonSource('zones-selected', {
        'type': 'FeatureCollection',
        'features': features,
      });
    } catch (e) {
      debugPrint('Error updating selected source: $e');
    }
  }

  Future<void> _updateSources() async {
    if (!_isMapReady || _controller == null) return;
    await _updateCitySource();
    await _updateSelectedSource();
  }

  Future<void> _updateCitySource() async {
    final features = _cityClusters.map((c) {
      return {
        'type': 'Feature',
        'properties': {
          'name': c.name,
          'lat': c.centroid.latitude,
          'lng': c.centroid.longitude,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [c.centroid.longitude, c.centroid.latitude],
        },
      };
    }).toList();
    await _controller!.setGeoJsonSource('cities', {
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  /// Click delay wrapper - only process clicks that are quick taps (not drags)
  void _onMapClickWithDelay(
      math.Point<double> screenPoint, LatLng coordinates) {
    // Check if this was a genuine click vs a drag
    // If _pointerDownTime is null (possible on web), still allow the click
    if (_pointerDownTime != null) {
      final elapsed =
          DateTime.now().difference(_pointerDownTime!).inMilliseconds;

      // If held too long (> 500ms), it's probably a drag - ignore
      // Increased from 300ms to 500ms for better web compatibility
      if (elapsed > 500) {
        debugPrint('ZoneMap: Ignoring click - held too long (${elapsed}ms)');
        return;
      }
    }

    // Reset pointer time for next click
    _pointerDownTime = null;

    // Proceed with actual click handling
    _onMapClick(screenPoint, coordinates);
  }

  void _onMapClick(math.Point<double> screenPoint, LatLng coordinates) async {
    if (_controller == null) return;
    final zoom = _controller!.cameraPosition?.zoom ?? 0;

    // ─────────────────────────────────────────────────────────────
    // 1. Check for Jobs First (Any Zoom)
    // ─────────────────────────────────────────────────────────────
    if (widget.jobs != null) {
      final jobFeatures = await _controller!.queryRenderedFeatures(
          screenPoint, ['jobs-circles', 'jobs-labels'], null);

      if (jobFeatures.isNotEmpty) {
        final props = jobFeatures.first['properties'];
        final jobId = props?['jobId'];
        if (jobId != null) {
          widget.onJobTap?.call(jobId.toString());
          return;
        }
      }
    }

    // ─────────────────────────────────────────────────────────────
    // 2. ZONE CLICK - Try zones at ALL zoom levels
    // ─────────────────────────────────────────────────────────────
    // Query zone layers - they're now visible at all zooms
    final zoneFeatures = await _controller!.queryRenderedFeatures(
      screenPoint,
      ['zones-unselected', 'zones-selected-fill', 'zones-border'],
      null,
    );

    if (zoneFeatures.isNotEmpty) {
      final props = zoneFeatures.first['properties'];
      final dynamic zoneId = props?['zoneId'];
      if (zoneId != null) {
        _toggleZoneSelection(zoneId.toString());
        return;
      }
    }

    // Fallback to raycasting for zones (in case query misses)
    for (final zone in widget.zones) {
      if (_isPointInPolygon(coordinates, zone.polygon)) {
        _toggleZoneSelection(zone.id);
        return;
      }
    }

    // ─────────────────────────────────────────────────────────────
    // 3. CITY LABEL CLICK - At low zoom, toggle city zones
    // ─────────────────────────────────────────────────────────────
    if (zoom < MapConstants.cityToZoneZoomThreshold) {
      final cityFeatures = await _controller!.queryRenderedFeatures(
        screenPoint,
        ['cities-circles', 'cities-labels'],
        null,
      );

      if (cityFeatures.isNotEmpty) {
        final props = cityFeatures.first['properties'];
        final name = props?['name'];

        if (name != null) {
          final zonesInCity = widget.zones
              .where((z) => z.city?.trim() == name)
              .map((z) => z.id)
              .toSet();

          if (zonesInCity.isNotEmpty) {
            // Toggle: if ANY selected, deselect all; else select all
            final alreadySelected =
                zonesInCity.any((id) => _selectedZoneIds.contains(id));

            setState(() {
              if (alreadySelected) {
                _selectedZoneIds.removeAll(zonesInCity);
              } else {
                _selectedZoneIds.addAll(zonesInCity);
              }
            });

            _updateSelectedSource();
            widget.onSelectionChanged?.call(_selectedZoneIds);
          }
        }
      }
    }
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    final x = point.longitude;
    final y = point.latitude;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      if (((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  void _toggleZoneSelection(String zoneId) {
    setState(() {
      if (_selectedZoneIds.contains(zoneId)) {
        _selectedZoneIds.remove(zoneId);
      } else {
        _selectedZoneIds.add(zoneId);
      }
    });

    _updateSelectedSource();
    widget.onSelectionChanged?.call(_selectedZoneIds);
  }

  List<Zone> get _filteredZones {
    if (_searchQuery.isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return widget.zones
        .where((z) =>
            z.name.toLowerCase().contains(query) ||
            z.nameHebrew.contains(query) ||
            (z.city?.toLowerCase().contains(query) ?? false))
        .take(15)
        .toList();
  }

  void _selectZone(Zone zone) {
    if (!_selectedZoneIds.contains(zone.id)) {
      _toggleZoneSelection(zone.id);
    }
    _controller?.animateCamera(CameraUpdate.newLatLngZoom(zone.centroid, 13));
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter zones for search
    final results = _filteredZones;

    return Stack(
      children: [
        // Wrap map with Listener to track pointer timing for click delay
        Listener(
          onPointerDown: (event) {
            _pointerDownTime = DateTime.now();
          },
          child: MapLibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: CameraPosition(
              target: widget.initialCenter ?? _israelCenter,
              zoom: widget.initialZoom,
            ),
            styleString: MapStyleService.getStyleString(theme.brightness),
            onMapClick: _onMapClickWithDelay,
            trackCameraPosition: true,
          ),
        ),

        // Search & Results
        Positioned(
          top: 16 + widget.topPadding,
          left: 16,
          right: 16,
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search zones or cities...',
                    prefixIcon: const Icon(LucideIcons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              if (results.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 4),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${results.length} matched',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.hintColor),
                              ),
                              TextButton(
                                onPressed: () {
                                  final ids = results.map((z) => z.id).toSet();
                                  setState(() => _selectedZoneIds.addAll(ids));
                                  _updateSelectedSource();
                                  widget.onSelectionChanged
                                      ?.call(_selectedZoneIds);
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Text('Select All'),
                              ),
                            ],
                          ),
                        ),
                        // City Match Section
                        if (_searchQuery.isNotEmpty) ...[
                          (() {
                            final cityMatch = _cityClusters.firstWhere(
                                (c) =>
                                    c.name.toLowerCase() ==
                                    _searchQuery.toLowerCase(),
                                orElse: () => CityCluster(
                                    name: '',
                                    centroid: const LatLng(0, 0),
                                    zoneCount: 0));

                            if (cityMatch.name.isNotEmpty) {
                              // Simple visual for City Match
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      shape: BoxShape.circle),
                                  child: Icon(LucideIcons.building,
                                      size: 16,
                                      color: theme.colorScheme.primary),
                                ),
                                title: Text('Select all in ${cityMatch.name}'),
                                subtitle: Text('${cityMatch.zoneCount} zones'),
                                trailing: const Icon(LucideIcons.chevronRight,
                                    size: 16),
                                onTap: () {
                                  final zonesInCity = widget.zones
                                      .where((z) =>
                                          z.city?.trim() == cityMatch.name)
                                      .map((z) => z.id)
                                      .toList();
                                  setState(() {
                                    _selectedZoneIds.addAll(zonesInCity);
                                    _searchQuery = '';
                                  });
                                  _searchController.clear();
                                  _updateSelectedSource();
                                  widget.onSelectionChanged
                                      ?.call(_selectedZoneIds);
                                  _controller?.animateCamera(
                                      CameraUpdate.newLatLngZoom(
                                          cityMatch.centroid, 13));
                                },
                              );
                            }
                            return const SizedBox.shrink();
                          })(),
                          const Divider(height: 1),
                        ],
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final zone = results[index];
                              final isSelected =
                                  _selectedZoneIds.contains(zone.id);
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  isSelected
                                      ? LucideIcons.checkCircle2
                                      : LucideIcons.mapPin,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : null,
                                  size: 18,
                                ),
                                title: Text(zone.nameHebrew),
                                subtitle:
                                    zone.city != null ? Text(zone.city!) : null,
                                onTap: () => _selectZone(zone),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Selected Badge
        Positioned(
          bottom: 16,
          left: 16,
          child: Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${_selectedZoneIds.length} zones selected',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),

        // Clear Button
        if (_selectedZoneIds.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'clearZones',
              onPressed: () {
                setState(() => _selectedZoneIds.clear());
                _updateSelectedSource();
                widget.onSelectionChanged?.call(_selectedZoneIds);
              },
              icon: const Icon(LucideIcons.trash2),
              label: const Text('Clear All'),
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
          ),
      ],
    );
  }
}
