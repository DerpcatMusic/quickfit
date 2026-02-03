// QuickFit Map Configuration
// Custom Uber/iOS-inspired dark theme for MapLibre GL
// lib/core/config/map_config.dart

/// Map configuration for QuickFit's custom Uber/iOS-inspired map style.
///
/// Uses OpenFreeMap/MapTiler free tiles with a custom dark theme optimized for:
/// - Battery efficiency (dark UI reduces OLED power)
/// - Visual clarity (minimal clutter, focused on jobs/instructors)
/// - Brand consistency (uses app's color palette)
class MapConfig {
  MapConfig._();

  // TILE SOURCES & STYLES are now managed by MapStyleService.
  // We use OpenFreeMap via MapStyleService.getStyleString().

  // ===========================================================================
  // DEFAULT CAMERA SETTINGS (Israel-focused)
  // ===========================================================================

  /// Default center: Tel Aviv (Israel's tech hub)
  static const double defaultLatitude = 32.0853;
  static const double defaultLongitude = 34.7818;

  /// Default zoom levels
  static const double defaultZoom = 12.0;
  static const double cityZoom = 13.0;
  static const double neighborhoodZoom = 15.0;
  static const double streetZoom = 17.0;

  /// Zoom bounds
  static const double minZoom = 4.0;
  static const double maxZoom = 18.0;

  // ===========================================================================
  // ANIMATION DURATIONS
  // ===========================================================================

  static const Duration cameraAnimationDuration = Duration(milliseconds: 500);
  static const Duration markerPulseDuration = Duration(milliseconds: 1500);

  // ===========================================================================
  // LAYER Z-INDEX ORDERING
  // ===========================================================================

  static const int userLocationZIndex = 4;

  // ===========================================================================
  // LAYER Z-INDEX ORDERING
  // ===========================================================================

  /// Z-order for map overlays (higher = on top)
  static const int radiusCircleZIndex = 1;
  static const int jobMarkerZIndex = 2;
  static const int sosMarkerZIndex = 3;

  // ===========================================================================
  // RADIUS VISUALIZATION - Premium glow effect
  // ===========================================================================

  /// Radius circle styling - subtle gradient-like appearance
  static const double radiusFillOpacity = 0.08; // Very subtle fill
  static const double radiusStrokeOpacity = 0.6; // Visible but not harsh
  static const double radiusStrokeWidth =
      2.5; // Slightly thicker for premium feel

  /// Premium glow effect (outer stroke)
  static const double radiusGlowOpacity = 0.15;
  static const double radiusGlowWidth = 8.0;

  // ===========================================================================
  // MARKER SIZING
  // ===========================================================================

  /// Job marker sizes
  static const double jobMarkerSize = 40.0;
  static const double sosMarkerSize = 48.0;
  static const double userMarkerSize = 44.0;

  /// Cluster thresholds
  static const int clusterRadius = 50;
  static const int clusterMinPoints = 3;
}

/// Map marker types for QuickFit
enum QuickFitMarkerType {
  /// Current user location
  user,

  /// Regular job posting
  job,

  /// SOS urgent job (pulsing, higher visibility)
  sosJob,

  /// Studio location
  studio,

  /// Claimed job (instructor is en route)
  claimedJob,
}

/// Extension to get marker properties
extension QuickFitMarkerTypeExtension on QuickFitMarkerType {
  /// Get the icon asset path for this marker type
  String get iconAsset {
    switch (this) {
      case QuickFitMarkerType.user:
        return 'assets/icons/marker_user.png';
      case QuickFitMarkerType.job:
        return 'assets/icons/marker_job.png';
      case QuickFitMarkerType.sosJob:
        return 'assets/icons/marker_sos.png';
      case QuickFitMarkerType.studio:
        return 'assets/icons/marker_studio.png';
      case QuickFitMarkerType.claimedJob:
        return 'assets/icons/marker_claimed.png';
    }
  }

  /// Get the marker size for this type
  double get size {
    switch (this) {
      case QuickFitMarkerType.user:
        return MapConfig.userMarkerSize;
      case QuickFitMarkerType.sosJob:
        return MapConfig.sosMarkerSize;
      default:
        return MapConfig.jobMarkerSize;
    }
  }

  /// Whether this marker type should pulse
  bool get shouldPulse {
    return this == QuickFitMarkerType.sosJob;
  }
}
