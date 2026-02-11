import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:quickfit/core/models/zone.dart';
import 'package:quickfit/core/config/map_config.dart';
import 'package:quickfit/shared/widgets/quickfit_map.dart';
import 'package:quickfit/shared/widgets/zone_selection_map.dart';
import 'package:quickfit/features/instructor/map/presentation/widgets/map_settings_sheet.dart';
import 'package:quickfit/l10n/app_localizations.dart';

/// A component that renders the instructor map based on the selection mode.
class InstructorMapView extends ConsumerWidget {
  const InstructorMapView({
    super.key,
    required this.mapKey,
    required this.mode,
    required this.currentLocation,
    required this.radiusKm,
    required this.jobs,
    required this.selectedZoneIds,
    required this.zonesAsync,
    required this.onZoneSelectionChanged,
    required this.onMapTap,
    required this.interactionEnabled,
    this.onStyleLoaded,
  });

  /// Key used to control the underlying map state.
  final GlobalKey<QuickFitMapState> mapKey;

  /// Whether the user is selecting by radius or by zones.
  final SelectionMode mode;

  /// The center point for the radius selection.
  final LatLng? currentLocation;

  /// The radius in kilometers.
  final double radiusKm;

  /// Markers representing available jobs.
  final List<QuickFitJobMarker> jobs;

  /// IDs of the currently selected zones.
  final Set<String> selectedZoneIds;

  /// Asynchronous list of available zones.
  final AsyncValue<List<Zone>> zonesAsync;

  /// Callback triggered when the zone selection changes.
  final ValueChanged<Set<String>> onZoneSelectionChanged;

  /// Callback triggered when the map is tapped (e.g., to drop a pin).
  final ValueChanged<LatLng> onMapTap;

  /// Whether base map gestures are enabled.
  final bool interactionEnabled;

  /// Callback triggered when the map style has finished loading.
  final VoidCallback? onStyleLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (mode == SelectionMode.radius) {
      return QuickFitMap(
        key: mapKey,
        initialCenter: currentLocation,
        initialZoom: MapConfig.cityZoom,
        radiusKm: radiusKm,
        radiusCenter: currentLocation,
        showUserLocation: true,
        showRadius: true,
        showHomePin: true,
        interactionEnabled: interactionEnabled,
        jobs: jobs,
        onStyleLoaded: onStyleLoaded,
        onMapTap: onMapTap,
      );
    }

    return zonesAsync.when(
      data: (zones) => ZoneSelectionMap(
        zones: zones,
        initialSelectedZones: selectedZoneIds,
        onSelectionChanged: onZoneSelectionChanged,
        jobs: jobs,
        topPadding: 0,
        interactionEnabled: interactionEnabled,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text(l10n.mapErrorWithMessage(err.toString()))),
    );
  }
}
