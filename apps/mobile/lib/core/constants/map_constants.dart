/// Map Constants
///
/// Centralized constants for map styling, zoom levels, and interaction.
library;

import 'package:maplibre_gl/maplibre_gl.dart';

/// Map configuration constants
class MapConstants {
  MapConstants._();

  // ─────────────────────────────────────────────────────────────
  // Geographic Defaults
  // ─────────────────────────────────────────────────────────────

  /// Israel geographic center
  static const israelCenter = LatLng(31.5, 34.8);

  /// Default zoom level showing all of Israel
  static const defaultZoom = 8.0;

  // ─────────────────────────────────────────────────────────────
  // Zoom Thresholds
  // ─────────────────────────────────────────────────────────────

  /// Below this: show cities. Above this: show zones.
  static const cityToZoneZoomThreshold = 11.0;

  /// Zone labels appear at this zoom
  static const zoneLabelMinZoom = 12.5;

  // ─────────────────────────────────────────────────────────────
  // Layer Opacities
  // ─────────────────────────────────────────────────────────────

  /// City polygon fill opacity
  static const cityFillOpacity = 0.15;

  /// City polygon border opacity
  static const cityBorderOpacity = 0.6;

  /// Unselected zone fill opacity (needs to be >0 for click detection)
  static const zoneUnselectedOpacity = 0.12;

  /// Selected zone fill opacity
  static const zoneSelectedOpacity = 0.35;

  /// Zone border opacity
  static const zoneBorderOpacity = 0.6;

  // ─────────────────────────────────────────────────────────────
  // Layer Sizes
  // ─────────────────────────────────────────────────────────────

  /// City border width
  static const cityBorderWidth = 1.5;

  /// Unselected zone border width
  static const zoneBorderWidth = 0.5;

  /// Selected zone border width
  static const zoneSelectedBorderWidth = 2.5;

  // ─────────────────────────────────────────────────────────────
  // Interaction
  // ─────────────────────────────────────────────────────────────

  /// Delay before drag starts (ms) - allows click detection
  static const dragDelayMs = 150;

  /// Animation duration for camera moves (ms)
  static const cameraAnimationMs = 300;

  // ─────────────────────────────────────────────────────────────
  // Text Sizes
  // ─────────────────────────────────────────────────────────────

  /// City label text size (larger for visibility)
  static const cityLabelSize = 14.0;

  /// Zone label text size
  static const zoneLabelSize = 12.0;

  /// Text halo width for contrast
  static const textHaloWidth = 2.5;
}
