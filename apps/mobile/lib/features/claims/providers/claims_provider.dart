// Claims Provider - Manage job claims for studios and instructors
// lib/features/claims/providers/claims_provider.dart

import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:convex_flutter/convex_flutter.dart';

import '../../../core/utils/logger.dart';

part 'claims_provider.g.dart';

/// Provider for studio to manage claims on their jobs
@riverpod
class StudioClaimsNotifier extends _$StudioClaimsNotifier {
  @override
  AsyncValue<List<dynamic>> build() {
    return const AsyncValue.data([]);
  }

  /// Load claims for a specific job
  Future<void> loadClaimsForJob(String jobId) async {
    state = const AsyncValue.loading();

    try {
      final result = await ConvexClient.instance.query(
        'claims:getJobClaims',
        {'jobId': jobId},
      );

      final decoded = json.decode(result);
      final claimsList = decoded as List;

      state = AsyncValue.data(claimsList);
    } catch (e, stack) {
      log.e('Failed to load claims: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Accept a claim (studio confirms instructor)
  Future<bool> acceptClaim(String claimId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:acceptClaim',
        args: {'claimId': claimId},
      );
      return true;
    } catch (e) {
      log.e('Failed to accept claim: $e');
      return false;
    }
  }

  /// Reject a claim
  Future<bool> rejectClaim(String claimId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:rejectClaim',
        args: {'claimId': claimId},
      );
      return true;
    } catch (e) {
      log.e('Failed to reject claim: $e');
      return false;
    }
  }
}

/// Provider for instructors to view their claims
@riverpod
class InstructorClaimsNotifier extends _$InstructorClaimsNotifier {
  @override
  AsyncValue<List<dynamic>> build() {
    return const AsyncValue.data([]);
  }

  /// Load all claims for current instructor
  Future<void> loadMyClaims() async {
    state = const AsyncValue.loading();

    try {
      final result = await ConvexClient.instance.query(
        'claims:getMyClaims',
        {},
      );

      final decoded = json.decode(result);
      final claimsList = decoded as List;

      state = AsyncValue.data(claimsList);
    } catch (e, stack) {
      log.e('Failed to load my claims: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Cancel/withdraw a claim
  Future<bool> withdrawClaim(String claimId) async {
    try {
      await ConvexClient.instance.mutation(
        name: 'jobs:withdrawClaim',
        args: {'claimId': claimId},
      );

      // Refresh claims
      await loadMyClaims();

      return true;
    } catch (e) {
      log.e('Failed to withdraw claim: $e');
      return false;
    }
  }
}
