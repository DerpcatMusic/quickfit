import 'package:maplibre_gl/maplibre_gl.dart';

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

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'nameHebrew': nameHebrew,
      'city': city,
      'polygon':
          polygon.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'centroid': {
        'lat': centroid.latitude,
        'lng': centroid.longitude,
      },
    };
  }
}

class CityCluster {
  final String name;
  final LatLng centroid;
  final int zoneCount;
  final List<LatLng>? bounds; // Bounding polygon for city area

  CityCluster({
    required this.name,
    required this.centroid,
    required this.zoneCount,
    this.bounds,
  });
}
