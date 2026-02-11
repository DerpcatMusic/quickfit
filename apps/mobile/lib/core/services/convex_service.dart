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
    String? dispatchMode,
    List<String>? zoneIds,
  }) async {
    final args = {
      'role': role,
      'name': name,
      'categories': categories.join(','),
      if (dispatchMode != null) 'dispatchMode': dispatchMode,
      if (radiusKm != null) 'radiusKm': radiusKm.toDouble(),
      if (latitude != null) 'latitude': latitude.toDouble(),
      if (longitude != null) 'longitude': longitude.toDouble(),
      if (address != null) 'address': address,
      if (zoneIds != null && zoneIds.isNotEmpty)
        // Cast to List<dynamic> for proper JSON array serialization
        'zoneIds': List<dynamic>.from(zoneIds),
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

  /// Gets studio pricing defaults and lead-time surge rules.
  Future<Map<String, dynamic>?> getMyStudioPricingSettings() async {
    try {
      final result = await ConvexClient.instance.query(
        'users:getMyStudioPricingSettings',
        {},
      );
      if (result.isEmpty || result == 'null') return null;
      return json.decode(result) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('getMyStudioPricingSettings failed: $e');
      return null;
    }
  }

  /// Saves studio pricing defaults and lead-time surge rules.
  Future<Map<String, dynamic>?> setMyStudioPricingSettings({
    required double defaultBaseRate,
    required List<Map<String, dynamic>> leadTimeSurgeRules,
  }) async {
    try {
      final result = await ConvexClient.instance.mutation(
        name: 'users:setMyStudioPricingSettings',
        args: {
          'defaultBaseRate': defaultBaseRate,
          'leadTimeSurgeRules': leadTimeSurgeRules,
        },
      );
      if (result.isEmpty || result == 'null') return null;
      return json.decode(result) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('setMyStudioPricingSettings failed: $e');
      rethrow;
    }
  }

  /// Marks a confirmed job as completed.
  Future<void> completeJob(String jobId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:completeJob',
        args: {'jobId': jobId},
      );
    } catch (e) {
      debugPrint('completeJob failed: $e');
      rethrow;
    }
  }

  /// Submits a post-job rating for studio/instructor counterpart.
  Future<void> submitRating({
    required String jobId,
    required String toUserId,
    required double rating,
    String? comment,
  }) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:submitRating',
        args: {
          'jobId': jobId,
          'toUserId': toUserId,
          'rating': rating,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );
    } catch (e) {
      debugPrint('submitRating failed: $e');
      rethrow;
    }
  }

  /// Generic mutation call for offline queue.
  Future<dynamic> mutate(String mutationName, Map<String, dynamic> args) async {
    try {
      final result = await ConvexClient.instance.mutation(
        name: mutationName,
        args: args,
      );
      return result;
    } catch (e) {
      debugPrint('mutate $mutationName failed: $e');
      rethrow;
    }
  }

  Future<dynamic> _tryQueryByNames(
    List<String> names,
    Map<String, String> args,
  ) async {
    Object? lastError;
    for (final name in names) {
      try {
        return await ConvexClient.instance.query(name, args);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('All query candidates failed');
  }

  /// Returns current studio invoicing integrations (sensitive secrets are masked).
  Future<List<Map<String, dynamic>>> getMyInvoicingIntegrations() async {
    try {
      final result = await ConvexClient.instance.query(
        'billing:listMyInvoicingIntegrations',
        {},
      );
      if (result.isEmpty || result == 'null') return <Map<String, dynamic>>[];
      final decoded = json.decode(result);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (e) {
      debugPrint('getMyInvoicingIntegrations failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Creates or updates a studio invoicing integration.
  Future<void> upsertMyInvoicingIntegration({
    required String provider, // morning | icount
    required String baseUrl,
    bool isActive = true,
    String? displayName,
    String? apiToken,
    String? apiKey,
    String? accountId,
    double? defaultVatRate,
  }) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'billing:upsertMyInvoicingIntegration',
        args: {
          'provider': provider,
          'baseUrl': baseUrl,
          'isActive': isActive,
          if (displayName != null) 'displayName': displayName,
          if (apiToken != null) 'apiToken': apiToken,
          if (apiKey != null) 'apiKey': apiKey,
          if (accountId != null) 'accountId': accountId,
          if (defaultVatRate != null) 'defaultVatRate': defaultVatRate,
        },
      );
    } catch (e) {
      debugPrint('upsertMyInvoicingIntegration failed: $e');
      rethrow;
    }
  }

  /// Activates/deactivates one provider integration.
  Future<void> setMyInvoicingIntegrationActive({
    required String provider, // morning | icount
    required bool isActive,
  }) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'billing:setMyInvoicingIntegrationActive',
        args: {
          'provider': provider,
          'isActive': isActive,
        },
      );
    } catch (e) {
      debugPrint('setMyInvoicingIntegrationActive failed: $e');
      rethrow;
    }
  }

  /// Deletes one provider integration.
  Future<void> removeMyInvoicingIntegration({
    required String provider, // morning | icount
  }) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'billing:removeMyInvoicingIntegration',
        args: {'provider': provider},
      );
    } catch (e) {
      debugPrint('removeMyInvoicingIntegration failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listMyPayments({int limit = 50}) async {
    try {
      final result = await _tryQueryByNames(
        const ['payments:listMyPayments'],
        {'limit': limit.toString()},
      );
      if (result == null || result.toString().isEmpty || result == 'null') {
        return <Map<String, dynamic>>[];
      }
      final decoded = json.decode(result.toString());
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (e) {
      debugPrint('listMyPayments failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> getMyPaymentDetail(String paymentId) async {
    try {
      final result = await _tryQueryByNames(
        const ['payments:getMyPaymentDetail'],
        {'paymentId': paymentId},
      );
      if (result == null || result.toString().isEmpty || result == 'null') {
        return null;
      }
      final decoded = json.decode(result.toString());
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('getMyPaymentDetail failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMyPaymentForJob(String jobId) async {
    try {
      final result = await _tryQueryByNames(
        const ['payments:getMyPaymentForJob'],
        {'jobId': jobId},
      );
      if (result == null || result.toString().isEmpty || result == 'null') {
        return null;
      }
      final decoded = json.decode(result.toString());
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('getMyPaymentForJob failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStudioPublicProfile(String studioId) async {
    try {
      final result = await _tryQueryByNames(
        const ['users:getStudioPublicProfile'],
        {'studioId': studioId},
      );
      if (result == null || result.toString().isEmpty || result == 'null') {
        return null;
      }
      final decoded = json.decode(result.toString());
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('getStudioPublicProfile failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createRapydCheckoutForJob({
    required String jobId,
    required String returnUrl,
    String? cancelUrl,
    String? idempotencyKey,
  }) async {
    try {
      final result = await ConvexClient.instance.action(
        name: 'rapyd:createCheckoutForJob',
        args: {
          'jobId': jobId,
          'returnUrl': returnUrl,
          if (cancelUrl != null) 'cancelUrl': cancelUrl,
          if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        },
      );
      if (result.isEmpty || result == 'null') return null;
      final decoded = json.decode(result);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('createRapydCheckoutForJob failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPaymentsPreflight() async {
    try {
      final result = await _tryQueryByNames(
        const ['paymentsDiagnostics:getPaymentsPreflight'],
        const {},
      );
      if (result == null || result.toString().isEmpty || result == 'null') {
        return null;
      }
      final decoded = json.decode(result.toString());
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('getPaymentsPreflight failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listMyPayoutDestinations() async {
    try {
      final result = await _tryQueryByNames(
        const ['payments:listMyPayoutDestinations'],
        const {},
      );
      if (result == null || result.toString().isEmpty || result == 'null') {
        return <Map<String, dynamic>>[];
      }
      final decoded = json.decode(result.toString());
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (e) {
      debugPrint('listMyPayoutDestinations failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> upsertMyPayoutDestination({
    required String provider,
    required String type,
    required String externalRecipientId,
    String? label,
    String? country,
    String? currency,
    String? last4,
    bool isDefault = true,
    String status = 'verified',
  }) async {
    try {
      final result = await ConvexClient.instance.mutation(
        name: 'payments:upsertMyPayoutDestination',
        args: {
          'provider': provider,
          'type': type,
          'externalRecipientId': externalRecipientId,
          if (label != null) 'label': label,
          if (country != null) 'country': country,
          if (currency != null) 'currency': currency,
          if (last4 != null) 'last4': last4,
          'isDefault': isDefault,
          'status': status,
        },
      );
      if (result.isEmpty || result == 'null') return null;
      final decoded = json.decode(result);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('upsertMyPayoutDestination failed: $e');
      return null;
    }
  }
}
