import 'dart:convert';
import 'dart:developer' as developer;
import 'package:convex_flutter/convex_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:quickfit/core/services/notification_service.dart';
import 'package:quickfit/core/services/location_service.dart';

part 'user_service.g.dart';

/// Service responsible for synchronizing user data with the Convex backend.
@Riverpod(keepAlive: true)
UserService userService(Ref ref) {
  return UserService();
}

class UserService {
  final ConvexClient _convex = ConvexClient.instance;

  /// Syncs the Firebase identity with the Convex database.
  ///
  /// Returns the current user's profile data from Convex.
  Future<Map<String, dynamic>?> syncUser(User user) async {
    try {
      // Ensure Convex auth is set up with a fresh Firebase token
      await _convex.setAuthWithRefresh(
        fetchToken: () async {
          return await user.getIdToken();
        },
      );

      // Wait for connection if necessary
      if (!_convex.isConnected) {
        await _convex.connectionState
            .firstWhere((s) => s == WebSocketConnectionState.connected)
            .timeout(const Duration(seconds: 15));
      }

      // Sync user identify
      await _convex.mutation(
        name: 'users:syncUser',
        args: {
          'firebaseUid': user.uid,
          'email': user.email ?? '',
          'name': user.displayName ?? '',
          'photoUrl': user.photoURL ?? '',
        },
      );

      // Fetch the full profile
      final resultJson = await _convex.query('users:getCurrentUser', {});
      return json.decode(resultJson) as Map<String, dynamic>?;
    } catch (e) {
      developer.log('User Sync Failed', name: 'user_service', error: e);
      rethrow;
    }
  }

  /// Completes the user onboarding process.
  Future<void> completeOnboarding({
    required String role,
    required String name,
    required List<String> categories,
    double? radiusKm,
    double? latitude,
    double? longitude,
    String? address,
    List<String>? selectedZones,
  }) async {
    final mutationArgs = <String, dynamic>{
      'role': role,
      'name': name,
      'categories': categories.join(','),
    };

    if (radiusKm != null) mutationArgs['radiusKm'] = radiusKm;
    if (latitude != null) mutationArgs['latitude'] = latitude;
    if (longitude != null) mutationArgs['longitude'] = longitude;
    if (address != null) mutationArgs['address'] = address;
    if (selectedZones != null) {
      mutationArgs['selectedZones'] = selectedZones;
    }

    await _convex.mutation(
      name: 'users:completeOnboarding',
      args: mutationArgs,
    );
  }

  /// Updates the user's profile information.
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    double? radiusKm,
    List<String>? categories,
  }) async {
    await _convex.mutation(
      name: 'users:updateProfile',
      args: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (address != null) 'homeAddress': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radiusKm != null) 'radiusKm': radiusKm,
        if (categories != null) 'categories': categories,
      },
    );
  }

  /// Updates the user's FCM token in the backend.
  Future<void> updateFcmToken() async {
    final token = NotificationService.instance.fcmToken;
    if (token == null) return;
    try {
      await _convex.mutation(
        name: 'users:updateFcmToken',
        args: {'token': token},
      );
    } catch (e) {
      developer.log('FCM Token Update Failed', name: 'user_service', error: e);
    }
  }

  /// Updates the user's current GPS location in the backend.
  Future<void> updateLocation() async {
    final lat = LocationService.instance.latitude;
    final lng = LocationService.instance.longitude;
    if (lat == null || lng == null) return;

    try {
      await _convex.mutation(
        name: 'users:updateLocation',
        args: {'latitude': lat, 'longitude': lng},
      );
    } catch (e) {
      developer.log('Location Update Failed', name: 'user_service', error: e);
    }
  }

  /// Resets the onboarding status for testing or re-onboarding.
  Future<void> resetOnboarding() async {
    await _convex.mutation(name: 'users:resetOnboarding', args: {});
  }

  /// Clears the authentication state in the Convex client.
  Future<void> clearAuth() async {
    await _convex.clearAuth();
  }
}
