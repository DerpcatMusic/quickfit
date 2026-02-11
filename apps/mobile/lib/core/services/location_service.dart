// Location Service for QuickFit 2026
// lib/core/services/location_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../utils/logger.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  bool _isInitialized = false;
  Position? _currentPosition;

  // Geocoding cache (LRU-style, max 50 entries)
  final Map<String, List<Map<String, dynamic>>> _autocompleteCache = {};
  static const int _maxCacheSize = 50;
  DateTime? _lastRequestTime;

  Position? get currentPosition => _currentPosition;
  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) return false;

    // Try to load last known location
    await _loadLastLocation();

    // Get current location
    await updateLocation();

    _isInitialized = true;
    return true;
  }

  Future<bool> _checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<void> _loadLastLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(StorageKeys.lastLocation);
      if (locationJson != null) {
        final parts = locationJson.split(',');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0]);
          final lng = double.tryParse(parts[1]);
          final timestampStr = parts.length > 2 ? parts[2] : null;
          final timestamp = timestampStr != null
              ? DateTime.tryParse(timestampStr) ?? DateTime.now()
              : DateTime.now();

          if (lat != null && lng != null) {
            _currentPosition = Position(
              latitude: lat,
              longitude: lng,
              timestamp: timestamp,
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          }
        }
      }
    } catch (e) {
      log.e('Failed to load last location: $e');
    }
  }

  Future<void> _saveLastLocation() async {
    if (_currentPosition == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageKeys.lastLocation,
        '${_currentPosition!.latitude},${_currentPosition!.longitude},${_currentPosition!.timestamp.toIso8601String()}',
      );
    } catch (e) {
      log.e('Failed to save location: $e');
    }
  }

  Future<Position?> updateLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy:
              LocationAccuracy.high, // Changed to HIGH for better accuracy
          distanceFilter: 100, // Reduced to 100m for more precise updates
        ),
      );

      if (_currentPosition != null) {
        await _saveLastLocation();
      }

      return _currentPosition;
    } catch (e) {
      log.e('Failed to update location: $e');
      return null;
    }
  }

  /// Check if location data is older than [hours].
  /// Used to decide if we should fallback to home address.
  bool isStale({int hours = 12}) {
    if (_currentPosition == null) return true;
    final age = DateTime.now().difference(_currentPosition!.timestamp);
    return age.inHours >= hours;
  }

  // Calculate distance between two points in km
  double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  // Stream location updates
  Stream<Position> watchLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 500, // Sync with Convex only every 500m to save battery
      ),
    ).map((position) {
      _currentPosition = position;
      _saveLastLocation();
      return position;
    });
  }

  // Settings helpers
  Future<bool> openSettings() async => await Geolocator.openLocationSettings();
  Future<bool> openAppSettings() async => await Geolocator.openAppSettings();

  // ==============================================================================
  // NOMINATIM GEOCODING (OpenStreetMap - Free, No API Key)
  // ==============================================================================
  // Rate limit: Max 1 request per second. We use debounce in the UI.
  // User-Agent header required by Nominatim ToS.

  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _nominatimHeaders = {
    'User-Agent': 'QuickFit/1.0 (fitness-app)',
    'Accept': 'application/json',
  };

  /// Get address autocomplete suggestions from Nominatim.
  ///
  /// Returns a list of suggestions with 'description' and 'place_id'.
  /// Uses cache to reduce API calls and respects 1 req/sec rate limit.
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(
      String input) async {
    if (input.length < 3) return [];

    // Check cache first
    final cacheKey = input.toLowerCase().trim();
    if (_autocompleteCache.containsKey(cacheKey)) {
      return _autocompleteCache[cacheKey]!;
    }

    // Rate limiting: ensure 1 second between requests
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < const Duration(seconds: 1)) {
        await Future.delayed(const Duration(seconds: 1) - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();

    // Focus search on Israel for better local results
    final url = '$_nominatimBaseUrl/search'
        '?q=${Uri.encodeComponent(input)}'
        '&format=json'
        '&addressdetails=1'
        '&countrycodes=il'
        '&limit=5'
        '&accept-language=he,en';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _nominatimHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final results = data.map((place) {
          final address = place['address'] as Map<String, dynamic>?;
          final street = (address?['road'] ??
                  address?['pedestrian'] ??
                  address?['footway'] ??
                  address?['path'])
              ?.toString();
          final houseNumber = address?['house_number']?.toString();
          final city = (address?['city'] ??
                  address?['town'] ??
                  address?['village'] ??
                  address?['hamlet'] ??
                  address?['suburb'])
              ?.toString();
          final displayName = place['display_name']?.toString();
          final fallbackLabel = _compactFromDisplayName(displayName);
          final compactLabel = _buildCompactAddressLabel(
            street: street,
            houseNumber: houseNumber,
            city: city,
          );

          return {
            'description': displayName ?? '',
            'label': compactLabel ?? fallbackLabel ?? displayName ?? '',
            'place_id': place['place_id'].toString(),
            'lat': double.tryParse(place['lat']?.toString() ?? ''),
            'lng': double.tryParse(place['lon']?.toString() ?? ''),
            'street': street,
            'houseNumber': houseNumber,
            'city': city,
          };
        }).toList();

        // Store in cache (with LRU eviction)
        if (_autocompleteCache.length >= _maxCacheSize) {
          _autocompleteCache.remove(_autocompleteCache.keys.first);
        }
        _autocompleteCache[cacheKey] = results;

        return results;
      }
    } catch (e) {
      log.e('Nominatim autocomplete error: $e');
    }
    return [];
  }

  String? _buildCompactAddressLabel({
    String? street,
    String? houseNumber,
    String? city,
  }) {
    final streetValue = street?.trim() ?? '';
    final numberValue = houseNumber?.trim() ?? '';
    final cityValue = city?.trim() ?? '';

    final streetPart = [streetValue, numberValue]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();

    final parts = <String>[
      if (streetPart.isNotEmpty) streetPart,
      if (cityValue.isNotEmpty) cityValue,
    ];

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  String? _compactFromDisplayName(String? displayName) {
    if (displayName == null) return null;
    final parts = displayName
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    if (parts.length == 1) return parts.first;

    final secondary = parts.skip(1).firstWhere(
          (part) => !_isAdministrativeSegment(part),
          orElse: () => parts[1],
        );
    return '${parts.first}, $secondary';
  }

  bool _isAdministrativeSegment(String value) {
    final lower = value.toLowerCase();
    if (lower == 'israel' || lower == 'country') {
      return true;
    }
    if (lower.contains('district') || lower.contains('subdistrict')) {
      return true;
    }
    if (lower.contains('region') || lower.contains('county')) {
      return true;
    }
    if (RegExp(r'^\d{5,}$').hasMatch(lower.replaceAll(' ', ''))) {
      return true;
    }
    return false;
  }

  /// Get coordinates from an address using Nominatim geocoding.
  Future<Position?> getLatLngFromAddress(String address) async {
    final url = '$_nominatimBaseUrl/search'
        '?q=${Uri.encodeComponent(address)}'
        '&format=json'
        '&limit=1'
        '&countrycodes=il';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _nominatimHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat']?.toString() ?? '');
          final lng = double.tryParse(data[0]['lon']?.toString() ?? '');

          if (lat != null && lng != null) {
            return Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          }
        }
      }
    } catch (e) {
      log.e('Nominatim geocoding error: $e');
    }
    return null;
  }

  /// Reverse geocode: get address from coordinates.
  Future<String?> getAddressFromLatLng(double lat, double lng) async {
    final url = '$_nominatimBaseUrl/reverse'
        '?lat=$lat'
        '&lon=$lng'
        '&format=json'
        '&accept-language=he,en';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _nominatimHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      }
    } catch (e) {
      log.e('Nominatim reverse geocoding error: $e');
    }
    return null;
  }
}
