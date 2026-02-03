// QuickFit Map Style Service
// Premium Uber/Wolt/Apple Maps-inspired styling for MapLibre.
//
// DESIGN PHILOSOPHY:
// - Minimal but sophisticated: Dark backgrounds with subtle contrast
// - Focus on roads and key landmarks, not clutter
// - Premium feel with refined colors and smooth gradients
// - No watermarks or distracting attribution
// lib/core/services/map_style_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';

class MapStyleService {
  MapStyleService._();

  /// Get the appropriate style for the current platform and brightness.
  static String getStyleString(Brightness brightness) {
    return _getPremiumStyleJson(brightness);
  }

  /// Generates the premium Uber/Wolt-inspired style JSON.
  static String _getPremiumStyleJson(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // ============================================================
    // PREMIUM COLOR PALETTE - Inspired by Uber/Apple Maps
    // ============================================================

    // Base colors
    final bgColor = isDark ? '#0A0A0C' : '#FAFBFC';
    final bgSubtle = isDark ? '#111113' : '#F4F5F7';

    // Water - subtle blue tint
    final waterColor = isDark ? '#0D1520' : '#C8D7EB';
    final waterDark = isDark ? '#0A1018' : '#B8C8DE';

    // Greenery - very subtle
    final parkColor = isDark ? '#0C120D' : '#E3EDE5';
    final forestColor = isDark ? '#0A0F0B' : '#D8E8DA';

    // Roads - premium hierarchy
    final highwayColor = isDark ? '#2A2A2E' : '#FFFFFF';
    final highwayCasing = isDark ? '#000000' : '#E0E0E3';
    final primaryColor = isDark ? '#1C1C20' : '#FFFFFF';
    final primaryCasing = isDark ? '#000000' : '#E8E8EB';
    final secondaryColor = isDark ? '#161618' : '#FFFFFF';
    final minorColor = isDark ? '#121214' : '#F8F8F9';

    // Buildings
    final buildingColor = isDark ? '#16161A' : '#E8E9EC';
    final buildingStroke = isDark ? '#1F1F24' : '#DCDDE0';

    // Text - refined typography colors
    final cityLabel = isDark ? '#8B8D98' : '#3D4152';
    final townLabel = isDark ? '#6B6D78' : '#5A5D6E';
    final neighborhoodLabel = isDark ? '#4A4C55' : '#74778A';
    final roadLabel = isDark ? '#3A3C45' : '#8A8D9E';
    final textHalo = isDark ? '#0A0A0C' : '#FFFFFF';

    final style = {
      'version': 8,
      'name': 'QuickFit Premium ${isDark ? "Dark" : "Light"}',
      'sources': {
        'openfreemap': {
          'type': 'vector',
          'tiles': ['https://tiles.openfreemap.org/planet/{z}/{x}/{y}.pbf'],
          'minzoom': 0,
          'maxzoom': 14,
        }
      },
      'glyphs': 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
      'sprite': 'https://tiles.openfreemap.org/sprites/liberty',
      'layers': [
        // ========================================
        // LAYER 1: Background
        // ========================================
        {
          'id': 'background',
          'type': 'background',
          'paint': {'background-color': bgColor}
        },

        // ========================================
        // LAYER 2: Landuse - Subtle terrain colors
        // ========================================
        {
          'id': 'landuse-residential',
          'type': 'fill',
          'source': 'openfreemap',
          'source-layer': 'landuse',
          'filter': ['==', 'class', 'residential'],
          'paint': {'fill-color': bgSubtle, 'fill-opacity': 0.5}
        },

        // ========================================
        // LAYER 3: Water - Rich, premium blue
        // ========================================
        {
          'id': 'water',
          'type': 'fill',
          'source': 'openfreemap',
          'source-layer': 'water',
          'paint': {'fill-color': waterColor, 'fill-antialias': true}
        },
        {
          'id': 'water-pattern',
          'type': 'fill',
          'source': 'openfreemap',
          'source-layer': 'water',
          'paint': {'fill-color': waterDark, 'fill-opacity': 0.3}
        },

        // ========================================
        // LAYER 4: Parks & Greenery - Subtle and refined
        // ========================================
        {
          'id': 'park',
          'type': 'fill',
          'source': 'openfreemap',
          'source-layer': 'landcover',
          'filter': ['in', 'class', 'park', 'grass'],
          'paint': {
            'fill-color': parkColor,
            'fill-opacity': {
              'stops': [
                [10, 0.5],
                [14, 0.8]
              ]
            }
          }
        },
        {
          'id': 'forest',
          'type': 'fill',
          'source': 'openfreemap',
          'source-layer': 'landcover',
          'filter': ['in', 'class', 'wood', 'scrub'],
          'paint': {'fill-color': forestColor, 'fill-opacity': 0.6}
        },

        // ========================================
        // LAYER 5: Buildings - Crisp with subtle stroke
        // ========================================
        {
          'id': 'building',
          'type': 'fill',
          'source': 'openfreemap',
          'source-layer': 'building',
          'minzoom': 13,
          'paint': {
            'fill-color': buildingColor,
            'fill-opacity': {
              'stops': [
                [13, 0],
                [14, 0.6],
                [16, 0.8]
              ]
            }
          }
        },
        {
          'id': 'building-outline',
          'type': 'line',
          'source': 'openfreemap',
          'source-layer': 'building',
          'minzoom': 15,
          'paint': {
            'line-color': buildingStroke,
            'line-width': 0.5,
            'line-opacity': 0.5
          }
        },

        // ========================================
        // LAYER 6: Roads - Premium hierarchy with casings
        // ========================================

        // Minor roads
        {
          'id': 'road-minor',
          'type': 'line',
          'source': 'openfreemap',
          'source-layer': 'transportation',
          'filter': [
            'all',
            ['in', 'class', 'minor', 'service', 'path'],
            ['!=', 'brunnel', 'tunnel']
          ],
          'layout': {'line-cap': 'round', 'line-join': 'round'},
          'paint': {
            'line-color': minorColor,
            'line-width': {
              'base': 1.3,
              'stops': [
                [13, 0],
                [14, 1],
                [18, 8]
              ]
            }
          }
        },

        // Secondary road casing
        {
          'id': 'road-secondary-casing',
          'type': 'line',
          'source': 'openfreemap',
          'source-layer': 'transportation',
          'filter': [
            'all',
            ['in', 'class', 'secondary', 'tertiary'],
            ['!=', 'brunnel', 'tunnel']
          ],
          'layout': {'line-cap': 'round', 'line-join': 'round'},
          'paint': {
            'line-color': primaryCasing,
            'line-width': {
              'base': 1.3,
              'stops': [
                [8, 0],
                [12, 2],
                [16, 12],
                [18, 24]
              ]
            }
          }
        },

        // Secondary road fill
        {
          'id': 'road-secondary',
          'type': 'line',
          'source': 'openfreemap',
          'source-layer': 'transportation',
          'filter': [
            'all',
            ['in', 'class', 'secondary', 'tertiary'],
            ['!=', 'brunnel', 'tunnel']
          ],
          'layout': {'line-cap': 'round', 'line-join': 'round'},
          'paint': {
            'line-color': secondaryColor,
            'line-width': {
              'base': 1.3,
              'stops': [
                [8, 0],
                [12, 1.5],
                [16, 10],
                [18, 22]
              ]
            }
          }
        },

        // Primary road casing
        {
          'id': 'road-primary-casing',
          'type': 'line',
          'source': 'openfreemap',
          'source-layer': 'transportation',
          'filter': [
            'all',
            ['==', 'class', 'primary'],
            ['!=', 'brunnel', 'tunnel']
          ],
          'layout': {'line-cap': 'round', 'line-join': 'round'},
          'paint': {
            'line-color': primaryCasing,
            'line-width': {
              'base': 1.3,
              'stops': [
                [6, 0],
                [10, 3],
                [14, 14],
                [18, 28]
              ]
            }
          }
        },

        // Primary road fill
        {
          'id': 'road-primary',
          'type': 'line',
          'source': 'openfreemap',
          'source-layer': 'transportation',
          'filter': [
            'all',
            ['==', 'class', 'primary'],
            ['!=', 'brunnel', 'tunnel']
          ],
          'layout': {'line-cap': 'round', 'line-join': 'round'},
          'paint': {
            'line-color': primaryColor,
            'line-width': {
              'base': 1.3,
              'stops': [
                [6, 0],
                [10, 2],
                [14, 12],
                [18, 26]
              ]
            }
          }
        },

        // Highway/Motorway casing
        {
          'id': 'road-highway-casing',
          'type': 'line',
          'source': 'openfreemap',
          'source-layer': 'transportation',
          'filter': [
            'all',
            ['in', 'class', 'motorway', 'trunk'],
            ['!=', 'brunnel', 'tunnel']
          ],
          'layout': {'line-cap': 'round', 'line-join': 'round'},
          'paint': {
            'line-color': highwayCasing,
            'line-width': {
              'base': 1.3,
              'stops': [
                [4, 0],
                [8, 4],
                [12, 16],
                [18, 36]
              ]
            }
          }
        },

        // Highway/Motorway fill
        {
          'id': 'road-highway',
          'type': 'line',
          'source': 'openfreemap',
          'source-layer': 'transportation',
          'filter': [
            'all',
            ['in', 'class', 'motorway', 'trunk'],
            ['!=', 'brunnel', 'tunnel']
          ],
          'layout': {'line-cap': 'round', 'line-join': 'round'},
          'paint': {
            'line-color': highwayColor,
            'line-width': {
              'base': 1.3,
              'stops': [
                [4, 0],
                [8, 3],
                [12, 14],
                [18, 34]
              ]
            }
          }
        },

        // ========================================
        // LAYER 7: Labels - Clean typography
        // ========================================

        // Road labels (subtle)
        {
          'id': 'road-label',
          'type': 'symbol',
          'source': 'openfreemap',
          'source-layer': 'transportation_name',
          'minzoom': 14,
          'layout': {
            'text-field': [
              'coalesce',
              ['get', 'name:en'],
              ['get', 'name']
            ],
            'text-font': ['Noto Sans Regular'],
            'text-size': {
              'stops': [
                [14, 9],
                [18, 11]
              ]
            },
            'symbol-placement': 'line',
            'text-rotation-alignment': 'map',
            'text-pitch-alignment': 'viewport'
          },
          'paint': {
            'text-color': roadLabel,
            'text-halo-color': textHalo,
            'text-halo-width': 1.5
          }
        },

        // Neighborhood labels
        {
          'id': 'place-neighborhood',
          'type': 'symbol',
          'source': 'openfreemap',
          'source-layer': 'place',
          'filter': ['==', 'class', 'neighbourhood'],
          'minzoom': 13,
          'layout': {
            'text-field': [
              'coalesce',
              ['get', 'name:en'],
              ['get', 'name']
            ],
            'text-font': ['Noto Sans Regular'],
            'text-size': {
              'stops': [
                [13, 10],
                [16, 12]
              ]
            },
            'text-transform': 'uppercase',
            'text-letter-spacing': 0.1
          },
          'paint': {
            'text-color': neighborhoodLabel,
            'text-halo-color': textHalo,
            'text-halo-width': 1.5
          }
        },

        // Town labels
        {
          'id': 'place-town',
          'type': 'symbol',
          'source': 'openfreemap',
          'source-layer': 'place',
          'filter': ['==', 'class', 'town'],
          'layout': {
            'text-field': [
              'coalesce',
              ['get', 'name:en'],
              ['get', 'name']
            ],
            'text-font': ['Noto Sans Medium'],
            'text-size': {
              'stops': [
                [8, 10],
                [12, 14],
                [14, 16]
              ]
            }
          },
          'paint': {
            'text-color': townLabel,
            'text-halo-color': textHalo,
            'text-halo-width': 2
          }
        },

        // City labels - prominent
        {
          'id': 'place-city',
          'type': 'symbol',
          'source': 'openfreemap',
          'source-layer': 'place',
          'filter': ['==', 'class', 'city'],
          'layout': {
            'text-field': [
              'coalesce',
              ['get', 'name:en'],
              ['get', 'name']
            ],
            'text-font': ['Noto Sans Bold'],
            'text-size': {
              'stops': [
                [6, 12],
                [10, 18],
                [14, 22]
              ]
            },
            'text-transform': 'none'
          },
          'paint': {
            'text-color': cityLabel,
            'text-halo-color': textHalo,
            'text-halo-width': 2.5
          }
        },
      ]
    };

    return jsonEncode(style);
  }
}
