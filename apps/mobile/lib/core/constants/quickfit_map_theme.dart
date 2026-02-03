// QuickFit Custom Map Theme
// Uber/iOS-inspired dark theme for MapLibre GL
// lib/core/constants/quickfit_map_theme.dart

/// Custom MapLibre GL style for QuickFit.
///
/// This is a dark, minimal, Uber-inspired theme optimized for:
/// - Battery efficiency (OLED-friendly dark background)
/// - Visual clarity (reduced clutter, essential features only)
/// - Brand consistency (uses QuickFit purple/violet accents)
/// - Israel region focus (Hebrew label support)
///
/// Based on OpenMapTiles Dark Matter with custom modifications.
class QuickFitMapTheme {
  QuickFitMapTheme._();

  // ===========================================================================
  // STYLE URLS
  // ===========================================================================

  /// Primary dark style URL
  static const String darkBaseUrl = 'https://tiles.openfreemap.org/styles/dark';

  /// Light mode alternative
  static const String lightBaseUrl =
      'https://tiles.openfreemap.org/styles/bright';

  // ===========================================================================
  // COLOR PALETTE (Uber/iOS inspired)
  // ===========================================================================

  /// Background colors
  static const String backgroundDark = '#0D0D0F'; // Near-black, not pure black
  static const String backgroundMedium = '#1A1A1F'; // Elevated surfaces
  static const String backgroundLight = '#2A2A32'; // Cards, modals

  /// Road colors (subtle hierarchy)
  static const String roadHighway = '#3D3D47'; // Major roads
  static const String roadPrimary = '#2F2F38'; // Primary roads
  static const String roadSecondary = '#252530'; // Secondary roads
  static const String roadLocal = '#1E1E26'; // Local streets

  /// Water and nature
  static const String water = '#0A1929'; // Deep blue-black
  static const String park = '#0D1A0D'; // Very subtle green tint

  /// Text and labels
  static const String textPrimary = '#FFFFFF'; // Pure white for main labels
  static const String textSecondary = '#8A8A99'; // Muted for minor labels
  static const String textTertiary = '#4A4A55'; // Very subtle

  /// Accent colors (matching QuickFit brand)
  static const String accentPrimary = '#8B5CF6'; // Violet (app primary)
  static const String accentSos = '#EF4444'; // Red for SOS
  static const String accentSuccess = '#22C55E'; // Green for claimed
  static const String accentWarning = '#F59E0B'; // Amber for time-sensitive

  // ===========================================================================
  // MARKER COLORS (for programmatic use)
  // ===========================================================================

  /// Marker fill colors (40% opacity applied in-widget)
  static const String markerJobFill = '#8B5CF6'; // Violet
  static const String markerSosFill = '#EF4444'; // Red
  static const String markerUserFill = '#3B82F6'; // Blue
  static const String markerStudioFill = '#F59E0B'; // Amber

  /// Marker stroke colors (80% opacity applied in-widget)
  static const String markerJobStroke = '#C4B5FD'; // Light violet
  static const String markerSosStroke = '#FCA5A5'; // Light red
  static const String markerUserStroke = '#93C5FD'; // Light blue
  static const String markerStudioStroke = '#FCD34D'; // Light amber

  // ===========================================================================
  // RADIUS CIRCLE STYLING
  // ===========================================================================

  /// Radius circle fill color (with opacity applied separately)
  static const String radiusFill = '#8B5CF6';
  static const double radiusFillOpacity = 0.12;

  /// Radius circle stroke
  static const String radiusStroke = '#8B5CF6';
  static const double radiusStrokeOpacity = 0.6;
  static const double radiusStrokeWidth = 2.0;

  // ===========================================================================
  // PULSING ANIMATION COLORS (for SOS markers)
  // ===========================================================================

  /// SOS pulse outer ring
  static const String sosPulseOuter = '#EF4444';
  static const double sosPulseOuterOpacity = 0.3;

  /// SOS pulse inner ring
  static const String sosPulseInner = '#EF4444';
  static const double sosPulseInnerOpacity = 0.15;

  // ===========================================================================
  // FONT CONFIGURATION
  // ===========================================================================

  /// Map label font (should match app typography)
  static const List<String> labelFontStack = [
    'Noto Sans Hebrew',
    'Noto Sans',
    'Arial Unicode MS',
  ];

  /// Label sizes
  static const double labelSizeCity = 14.0;
  static const double labelSizeNeighborhood = 12.0;
  static const double labelSizeStreet = 10.0;
}
