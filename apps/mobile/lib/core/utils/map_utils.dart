// QuickFit Map Utilities
// Shared utilities for map operations: distance calculation, geocoding, etc.
// lib/core/utils/map_utils.dart

import 'dart:math' as math;
import 'package:maplibre_gl/maplibre_gl.dart';

/// Utility class for map-related calculations and operations.
class MapUtils {
  MapUtils._();

  // ===========================================================================
  // DISTANCE CALCULATIONS
  // ===========================================================================

  /// Earth's radius in kilometers.
  static const double earthRadiusKm = 6371.0;

  /// Calculate distance between two points using Haversine formula.
  ///
  /// Returns distance in **kilometers**.
  static double distanceKm(LatLng from, LatLng to) {
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLng = _toRadians(to.longitude - from.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(from.latitude)) *
            math.cos(_toRadians(to.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Calculate distance in **meters**.
  static double distanceMeters(LatLng from, LatLng to) {
    return distanceKm(from, to) * 1000;
  }

  /// Format distance for display.
  ///
  /// Examples: "500 m", "1.2 km", "15 km"
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }

  // ===========================================================================
  // CIRCLE GEOMETRY
  // ===========================================================================

  /// Create a GeoJSON polygon representing a circle.
  ///
  /// Used for radius visualization on MapLibre maps.
  static Map<String, dynamic> createCircleGeoJson(
    LatLng center,
    double radiusMeters, {
    int points = 64,
  }) {
    final coordinates = <List<double>>[];

    for (int i = 0; i <= points; i++) {
      final angle = (i * 360 / points) * (math.pi / 180);
      final dx = radiusMeters * math.cos(angle);
      final dy = radiusMeters * math.sin(angle);

      // Convert meters to degrees (approximate)
      final lat = center.latitude + (dy / 111320);
      final lng = center.longitude +
          (dx / (111320 * math.cos(center.latitude * math.pi / 180)));

      coordinates.add([lng, lat]);
    }

    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [coordinates],
      },
      'properties': {},
    };
  }

  /// Create a simple point GeoJSON feature.
  static Map<String, dynamic> createPointGeoJson(
    LatLng point, {
    Map<String, dynamic>? properties,
  }) {
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [point.longitude, point.latitude],
      },
      'properties': properties ?? {},
    };
  }

  /// Create a GeoJSON FeatureCollection from multiple points.
  static Map<String, dynamic> createFeatureCollection(
    List<LatLng> points, {
    List<Map<String, dynamic>>? properties,
  }) {
    final features = <Map<String, dynamic>>[];

    for (int i = 0; i < points.length; i++) {
      features.add(createPointGeoJson(
        points[i],
        properties:
            properties != null && i < properties.length ? properties[i] : null,
      ));
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  // ===========================================================================
  // BOUNDS CALCULATIONS
  // ===========================================================================

  /// Calculate bounding box that contains all given points.
  static LatLngBounds? boundsFromPoints(List<LatLng> points) {
    if (points.isEmpty) return null;

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Expand bounds by a radius in kilometers.
  static LatLngBounds expandBounds(LatLngBounds bounds, double radiusKm) {
    // Approximate degrees per km at the center latitude
    final centerLat =
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
    final kmPerDegreeLat = 111.32; // Roughly constant
    final kmPerDegreeLng = 111.32 * math.cos(centerLat * math.pi / 180);

    final latExpansion = radiusKm / kmPerDegreeLat;
    final lngExpansion = radiusKm / kmPerDegreeLng;

    return LatLngBounds(
      southwest: LatLng(
        bounds.southwest.latitude - latExpansion,
        bounds.southwest.longitude - lngExpansion,
      ),
      northeast: LatLng(
        bounds.northeast.latitude + latExpansion,
        bounds.northeast.longitude + lngExpansion,
      ),
    );
  }

  // ===========================================================================
  // ZOOM CALCULATIONS
  // ===========================================================================

  /// Calculate appropriate zoom level to show a radius.
  ///
  /// Based on Mercator projection formula.
  static double zoomForRadius(double radiusKm, double mapWidth) {
    // Rough approximation for Mercator zoom
    const double metersPerPixelAtZoom0 = 156543.03392;
    final radiusMeters = radiusKm * 1000;
    final pixelsNeeded = mapWidth / 2; // Radius should fit in half the view

    final metersPerPixelNeeded = radiusMeters / pixelsNeeded;
    final zoom =
        math.log(metersPerPixelAtZoom0 / metersPerPixelNeeded) / math.log(2);

    return zoom.clamp(4.0, 18.0);
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}

/// Extension on LatLng for convenience methods.
extension LatLngExtension on LatLng {
  /// Calculate distance to another point in km.
  double distanceToKm(LatLng other) => MapUtils.distanceKm(this, other);

  /// Calculate distance to another point in meters.
  double distanceToMeters(LatLng other) => MapUtils.distanceMeters(this, other);

  /// Check if this point is within a radius of another point.
  bool isWithinRadius(LatLng center, double radiusKm) {
    return distanceToKm(center) <= radiusKm;
  }

  /// Convert to GeoJSON-compatible list [lng, lat].
  List<double> toGeoJsonCoordinates() => [longitude, latitude];
}
