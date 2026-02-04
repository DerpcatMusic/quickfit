import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:quickfit/core/models/zone.dart';

/// Provides the list of all zones, fetched from the backend.
/// Uses pagination to load all zones efficiently.
final zonesProvider = FutureProvider<List<Zone>>((ref) async {
  final convex = ConvexClient.instance; // Keep fetching until no more results
  List<Zone> allZones = [];
  String? cursor;
  bool hasMore = true;
  const int pageSize = 200;
  int retryCount = 0;
  const maxRetries = 3;

  while (hasMore) {
    try {
      final result = await convex.query(
        'zones:getAllZonesPaginated',
        {
          'paginationOpts': jsonEncode({
            'numItems': pageSize,
            'cursor': cursor,
          })
        },
      );

      if (result == 'null') break;

      final Map<String, dynamic> data = jsonDecode(result);
      final page = (data['page'] as List).cast<Map<String, dynamic>>();
      final isDone = data['isDone'] as bool;
      final continueCursor = data['continueCursor'] as String?;

      // Parse zones
      final zones = page.map((json) => Zone.fromJson(json)).toList();
      allZones.addAll(zones);

      // Update cursor
      cursor = continueCursor;
      hasMore = !isDone && cursor != null;
      retryCount = 0; // Reset retry on success

      // Safety break for dev
      if (allZones.length > 5000) break;
    } catch (e, stack) {
      if (retryCount < maxRetries) {
        retryCount++;
        developer.log(
            'Error loading zones, retrying ($retryCount/$maxRetries)...',
            error: e);
        await Future.delayed(Duration(seconds: retryCount * 2));
        continue;
      }

      developer.log('Error loading zones page', error: e, stackTrace: stack);
      // Even if partial, return what we have?
      if (allZones.isNotEmpty) return allZones;
      rethrow;
    }
  }

  return allZones;
});
