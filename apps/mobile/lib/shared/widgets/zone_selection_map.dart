/// Zone Selection Map Widget
///
/// Displays Pikud HaOref zones as selectable polygons on a MapLibre map.
/// Used in instructor onboarding for selecting coverage areas.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Represents a Pikud HaOref geographic zone
class Zone {
  final String id;
  final String name;
  final String nameHebrew;
  final String? city;
  final List<LatLng> polygon;
  final LatLng centroid;

  const Zone({
    required this.id,
    required this.name,
    required this.nameHebrew,
    this.city,
    required this.polygon,
    required this.centroid,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    final polygonData = json['polygon'] as List<dynamic>? ?? [];
    final centroidData = json['centroid'] as Map<String, dynamic>? ?? {};

    return Zone(
      id: json['_id'] ?? json['orefId'] ?? '',
      name: json['name'] ?? '',
      nameHebrew: json['nameHebrew'] ?? '',
      city: json['city'],
      polygon: polygonData
          .map((p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ))
          .toList(),
      centroid: LatLng(
        (centroidData['lat'] as num?)?.toDouble() ?? 32.0,
        (centroidData['lng'] as num?)?.toDouble() ?? 34.8,
      ),
    );
  }
}

/// Callback for zone selection changes
typedef OnZoneSelectionChanged = void Function(Set<String> selectedZoneIds);

/// Interactive zone selection map with polygon overlays
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

  const ZoneSelectionMap({
    super.key,
    this.initialSelectedZones = const {},
    this.onSelectionChanged,
    required this.zones,
    this.initialCenter,
    this.initialZoom = 8,
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

  // Israel center
  static const _israelCenter = LatLng(31.5, 34.8);

  @override
  void initState() {
    super.initState();
    _selectedZoneIds = Set.from(widget.initialSelectedZones);
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
    await _addZoneLayers();
  }

  /// Add GeoJSON source and layers for zone polygons
  Future<void> _addZoneLayers() async {
    final controller = _controller;
    if (controller == null || widget.zones.isEmpty) return;

    // Build GeoJSON FeatureCollection
    final features = widget.zones.map((zone) {
      final coordinates =
          zone.polygon.map((p) => [p.longitude, p.latitude]).toList();
      // Close the polygon
      if (coordinates.isNotEmpty) {
        coordinates.add(coordinates.first);
      }

      return {
        'type': 'Feature',
        'id': zone.id.hashCode, // MapLibre needs numeric IDs
        'properties': {
          'zoneId': zone.id,
          'name': zone.name,
          'nameHebrew': zone.nameHebrew,
          'city': zone.city ?? '',
          'selected': _selectedZoneIds.contains(zone.id),
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [coordinates],
        },
      };
    }).toList();

    final geojson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    // Add source
    await controller.addGeoJsonSource('zones', geojson);

    // Add fill layer for selected zones
    await controller.addFillLayer(
      'zones',
      'zones-fill',
      FillLayerProperties(
        fillColor: [
          'case',
          ['get', 'selected'],
          '#0D47A1', // Selected: Dark blue
          'transparent',
        ],
        fillOpacity: [
          'case',
          ['get', 'selected'],
          0.35,
          0.0,
        ],
      ),
    );

    // Add line layer for all zone borders
    await controller.addLineLayer(
      'zones',
      'zones-border',
      const LineLayerProperties(
        lineColor: '#0D47A1',
        lineWidth: 1.5,
        lineOpacity: 0.7,
      ),
    );

    // Add symbol layer for zone labels
    await controller.addSymbolLayer(
      'zones',
      'zones-labels',
      const SymbolLayerProperties(
        textField: ['get', 'nameHebrew'],
        textSize: 10,
        textColor: '#1A237E',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 1,
        textAllowOverlap: false,
        textIgnorePlacement: false,
      ),
    );
  }

  /// Update zone layer to reflect selection changes
  Future<void> _updateZoneLayers() async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;

    // Rebuild features with updated selection state
    final features = widget.zones.map((zone) {
      final coordinates =
          zone.polygon.map((p) => [p.longitude, p.latitude]).toList();
      if (coordinates.isNotEmpty) {
        coordinates.add(coordinates.first);
      }

      return {
        'type': 'Feature',
        'id': zone.id.hashCode,
        'properties': {
          'zoneId': zone.id,
          'name': zone.name,
          'nameHebrew': zone.nameHebrew,
          'city': zone.city ?? '',
          'selected': _selectedZoneIds.contains(zone.id),
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [coordinates],
        },
      };
    }).toList();

    final geojson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    await controller.setGeoJsonSource('zones', geojson);
  }

  /// Handle map tap to toggle zone selection
  void _onMapClick(math.Point<double> screenPoint, LatLng coordinates) {
    // Find which zone contains this point
    for (final zone in widget.zones) {
      if (_isPointInPolygon(coordinates, zone.polygon)) {
        _toggleZoneSelection(zone.id);
        break;
      }
    }
  }

  /// Ray casting point-in-polygon test
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
    _updateZoneLayers();
    widget.onSelectionChanged?.call(_selectedZoneIds);
  }

  /// Get filtered zones based on search query
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
    // Fly to zone
    _controller?.animateCamera(CameraUpdate.newLatLngZoom(zone.centroid, 12));
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Map
        MapLibreMap(
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          initialCameraPosition: CameraPosition(
            target: widget.initialCenter ?? _israelCenter,
            zoom: widget.initialZoom,
          ),
          styleString:
              'https://api.maptiler.com/maps/streets-v2/style.json?key=YOUR_MAPTILER_KEY',
          onMapClick: _onMapClick,
        ),

        // Search bar overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Column(
            children: [
              // Search field
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search zones...',
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
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),

              // Search results
              if (_filteredZones.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _filteredZones
                        .map((zone) => ListTile(
                              dense: true,
                              leading: Icon(
                                _selectedZoneIds.contains(zone.id)
                                    ? LucideIcons.checkCircle2
                                    : LucideIcons.mapPin,
                                color: _selectedZoneIds.contains(zone.id)
                                    ? theme.colorScheme.primary
                                    : null,
                                size: 18,
                              ),
                              title: Text(zone.nameHebrew),
                              subtitle:
                                  zone.city != null ? Text(zone.city!) : null,
                              onTap: () => _selectZone(zone),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),

        // Selected count badge
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

        // Clear selection button
        if (_selectedZoneIds.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'clearZones',
              onPressed: () {
                setState(() => _selectedZoneIds.clear());
                _updateZoneLayers();
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
