import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_colors.dart';

/// A static map widget using Stadia Maps tiles with local caching.
///
/// Designed for fast rendering in lists and cards.
/// Uses [flutter_map] with [CachedNetworkImageProvider] for offline support.
class StaticMap extends StatelessWidget {
  const StaticMap({
    super.key,
    required this.center,
    this.zoom = 15.0,
    this.height = 120,
    this.width = double.infinity,
    this.borderRadius = 12.0,
    this.showPin = true,
    this.onTap,
  });

  final LatLng center;
  final double zoom;
  final double height;
  final double width;
  final double borderRadius;
  final bool showPin;
  final VoidCallback? onTap;

  // OpenStreetMap - Free, no API key needed
  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          children: [
            // Map Layer
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  tileProvider: _CachedTileProvider(),
                  maxZoom: 19,
                  userAgentPackageName: 'com.quickfit.app',
                ),
                if (showPin)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.cobaltAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.mapPin,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Tap Handler
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    splashColor: colors.cobaltAccent.withValues(alpha: 0.1),
                    highlightColor: colors.cobaltAccent.withValues(alpha: 0.05),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Custom TileProvider using CachedNetworkImage
class _CachedTileProvider extends TileProvider {
  _CachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = _getTileUrl(coordinates, options);
    return CachedNetworkImageProvider(url);
  }

  String _getTileUrl(TileCoordinates coordinates, TileLayer options) {
    var url = options.urlTemplate ?? '';

    // Basic replacement logic
    url = url.replaceAll('{z}', coordinates.z.toString());
    url = url.replaceAll('{x}', coordinates.x.toString());
    url = url.replaceAll('{y}', coordinates.y.toString());

    // Handle retina/high-res
    url = url.replaceAll('{r}', ''); // Default to standard for now

    // Handle additional options (api_key)
    options.additionalOptions.forEach((key, value) {
      url = url.replaceAll('{$key}', value);
    });

    return url;
  }
}
