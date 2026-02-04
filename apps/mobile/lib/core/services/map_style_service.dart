// QuickFit Map Style Service
// Premium map styling for MapLibre using reliable hosted styles.
//
// For web compatibility, we use hosted style URLs from MapTiler/Stadia
// which are properly CORS-enabled and don't have web worker issues.
// lib/core/services/map_style_service.dart

import 'package:flutter/foundation.dart';

class MapStyleService {
  MapStyleService._();

  // Stadia Maps free tier style URLs (no API key required for basic usage)
  // These are CORS-enabled and work reliably on web
  static const String _stadiaLightUrl =
      'https://tiles.stadiamaps.com/styles/alidade_smooth.json';
  static const String _stadiaDarkUrl =
      'https://tiles.stadiamaps.com/styles/alidade_smooth_dark.json';

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
      // Use hosted style URLs on web for reliability
      return isDark ? _stadiaDarkUrl : _stadiaLightUrl;
    }

    // For mobile, we can use the same hosted URLs (simpler and works well)
    // Alternatively, inline JSON could be used here if custom styling is needed
    return isDark ? _stadiaDarkUrl : _stadiaLightUrl;
  }

  /// Check if a style string is a URL or inline JSON.
  static bool isStyleUrl(String style) {
    return style.startsWith('http://') || style.startsWith('https://');
  }
}
