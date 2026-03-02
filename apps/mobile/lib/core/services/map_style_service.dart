// QuickFit Map Style Service
// Premium map styling for MapLibre using reliable hosted styles.
//
// For web compatibility, we use hosted style URLs from MapTiler/Stadia
// which are properly CORS-enabled and don't have web worker issues.
// lib/core/services/map_style_service.dart

import 'package:flutter/foundation.dart';

class MapStyleService {
  MapStyleService._();

  // CARTO base styles (no API key required, reliable CORS on web)
  static const String _lightUrl =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';
  static const String _darkUrl =
      'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';

  // Alternative: MapTiler styles (requires API key for production)
  // static const String _maptilerLightUrl =
  //     'https://api.maptiler.com/maps/streets-v2/style.json?key=YOUR_KEY';
  // static const String _maptilerDarkUrl =
  //     'https://api.maptiler.com/maps/streets-v2-dark/style.json?key=YOUR_KEY';

  /// Get the appropriate style for the current platform and brightness.
  ///
  /// On web, we use hosted style URLs for reliable loading.
  /// On mobile, we could use inline JSON, but hosted URLs work fine too.
  static String getStyleString(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    if (kIsWeb) {
      return isDark ? _darkUrl : _lightUrl;
    }

    return isDark ? _darkUrl : _lightUrl;
  }

  /// Check if a style string is a URL or inline JSON.
  static bool isStyleUrl(String style) {
    return style.startsWith('http://') || style.startsWith('https://');
  }
}
