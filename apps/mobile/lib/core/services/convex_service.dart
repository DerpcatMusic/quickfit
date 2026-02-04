// Convex Service - Backend API abstraction
// lib/core/services/convex_service.dart

import 'dart:convert';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service for Convex backend API operations.
/// Abstracts away the raw query/mutation calls.
class ConvexService {
  ConvexService._();
  static final ConvexService instance = ConvexService._();

  /// Syncs Firebase user with Convex.
  Future<String?> syncUser({
    required String firebaseUid,
    required String email,
    required String name,
    required String photoUrl,
  }) async {
    try {
      final result = await ConvexClient.instance.mutation(
        name: 'users:syncUser',
        args: {
          'firebaseUid': firebaseUid,
          'email': email,
          'name': name,
          'photoUrl': photoUrl,
        },
      );
      return result;
    } catch (e) {
      debugPrint('syncUser failed: $e');
      return null;
    }
  }

  /// Gets current user from Convex.
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final result = await ConvexClient.instance.query(
        'users:getCurrentUser',
        {},
      );

      if (result.isEmpty || result == 'null') return null;

      final decoded = json.decode(result);
      return decoded as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('getCurrentUser failed: $e');
      return null;
    }
  }

  /// Completes user onboarding with profile info.
  Future<Map<String, dynamic>?> completeOnboarding({
    required String role,
    required String name,
    required List<String> categories,
    double? radiusKm,
    double? latitude,
    double? longitude,
    String? address,
    List<String>? selectedZones,
  }) async {
    final args = {
      'role': role,
      'name': name,
      'categories': categories.join(','),
      if (radiusKm != null) 'radiusKm': radiusKm.toDouble(),
      if (latitude != null) 'latitude': latitude.toDouble(),
      if (longitude != null) 'longitude': longitude.toDouble(),
      if (address != null) 'address': address,
      if (selectedZones != null && selectedZones.isNotEmpty)
        // Cast to List<dynamic> for proper JSON array serialization
        'selectedZones': List<dynamic>.from(selectedZones),
    };

    debugPrint('Completing onboarding with args: $args');

    try {
      final result = await ConvexClient.instance.mutation(
        name: 'users:completeOnboarding',
        args: args,
      );

      debugPrint('Onboarding result: $result');

      if (result.contains('Error')) {
        throw Exception(result);
      }

      final decoded = json.decode(result);
      return decoded as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('completeOnboarding failed: $e');
      rethrow;
    }
  }

  /// Updates user's FCM token for push notifications.
  Future<void> updateFcmToken(String token) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'users:updateFcmToken',
        args: {'token': token},
      );
    } catch (e) {
      debugPrint('updateFcmToken failed: $e');
    }
  }

  /// Updates user's location.
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    String? address,
    double? radiusKm,
    List<String>? categories,
  }) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'users:updateLocation',
        args: {
          'latitude': latitude,
          'longitude': longitude,
          if (address != null) 'address': address,
          if (radiusKm != null) 'radiusKm': radiusKm,
          if (categories != null) 'categories': categories,
        },
      );
    } catch (e) {
      debugPrint('updateLocation failed: $e');
    }
  }

  /// Updates user profile.
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    double? radiusKm,
    List<String>? categories,
  }) async {
    try {
      final args = <String, dynamic>{};
      if (name != null) args['name'] = name;
      if (phone != null) args['phone'] = phone;
      if (address != null) args['homeAddress'] = address;
      if (latitude != null) args['latitude'] = latitude;
      if (longitude != null) args['longitude'] = longitude;
      if (radiusKm != null) args['radiusKm'] = radiusKm;
      if (categories != null) args['categories'] = categories;

      if (args.isEmpty) return;

      await ConvexClient.instance.mutation(
        name: 'users:updateProfile',
        args: args,
      );
    } catch (e) {
      debugPrint('updateProfile failed: $e');
    }
  }

  /// Resets user's onboarding status.
  Future<void> resetOnboarding() async {
    try {
      await ConvexClient.instance.mutation(
        name: 'users:resetOnboarding',
        args: {},
      );
    } catch (e) {
      debugPrint('resetOnboarding failed: $e');
    }
  }

  /// Updates instructor's search radius.
  Future<void> updateRadius(double radiusKm) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'users:updateRadius',
        args: {'radiusKm': radiusKm},
      );
    } catch (e) {
      debugPrint('updateRadius failed: $e');
    }
  }

  /// Updates instructor's selected zones.
  Future<void> updateZones(List<String> zoneIds) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'users:updateZones',
        args: {'zoneIds': zoneIds},
      );
    } catch (e) {
      debugPrint('updateZones failed: $e');
    }
  }

  // --- Job Operations ---

  /// Gets a specific job by ID.
  Future<Map<String, dynamic>?> getJobById(String jobId) async {
    try {
      final result = await ConvexClient.instance.query(
        'jobs:getJobById',
        {'jobId': jobId},
      );
      if (result.isEmpty || result == 'null') return null;
      return json.decode(result) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('getJobById failed: $e');
      return null;
    }
  }

  /// Responds to a job claim (Accept/Reject).
  Future<void> respondToClaim({
    required String claimId,
    required bool accept,
  }) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:respondToClaim',
        args: {
          'claimId': claimId,
          'accept': accept,
        },
      );
    } catch (e) {
      debugPrint('respondToClaim failed: $e');
      rethrow;
    }
  }

  /// Cancels a job.
  Future<void> cancelJob(String jobId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:cancelJob',
        args: {'jobId': jobId},
      );
    } catch (e) {
      debugPrint('cancelJob failed: $e');
      rethrow;
    }
  }
}
