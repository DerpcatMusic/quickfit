import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:quickfit/core/services/hive_service.dart';
import 'package:quickfit/core/models/zone.dart';

/// Provides the list of all zones, fetched from the backend.
/// Uses pagination to load all zones efficiently.
final zonesProvider =
    AsyncNotifierProvider<ZonesNotifier, List<Zone>>(ZonesNotifier.new);

class ZonesNotifier extends AsyncNotifier<List<Zone>> {
  @override
  Future<List<Zone>> build() async {
    // Keep state alive even if not used
    ref.keepAlive();

    // Try load from cache
    _loadFromCache();

    // Fetch fresh in background
    Future.microtask(_fetchAllZones);

    // Return current state (likely cached or empty)
    // If we have cached data, we return it. If not, we wait for fetch.
    return state.value ?? [];
  }

  void _loadFromCache() {
    try {
      final cached = HiveService().get('all_zones');
      if (cached != null) {
        final zones = (cached as List)
            .map((e) => Zone.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        state = AsyncData(zones);
      }
    } catch (e) {
      developer.log('Error loading zones cache', error: e);
    }
  }

  Future<void> _fetchAllZones() async {
    final convex = ConvexClient.instance;
    List<Zone> allZones = [];
    String? cursor;
    bool hasMore = true;
    const int pageSize = 200;
    int retryCount = 0;
    const maxRetries = 3;

    try {
      while (hasMore) {
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

        final zones = page.map((json) => Zone.fromJson(json)).toList();
        allZones.addAll(zones);

        cursor = continueCursor;
        hasMore = !isDone && cursor != null;
        retryCount = 0;

        if (allZones.length > 5000) break;
      }

      // Save to cache
      if (allZones.isNotEmpty) {
        await HiveService()
            .save('all_zones', allZones.map((z) => z.toJson()).toList());
        state = AsyncData(allZones);
      }
    } catch (e, stack) {
      developer.log('Error fetching zones', error: e, stackTrace: stack);
      // If we failed but have cache, keep cache. If no cache, set error?
      if (state.value == null || state.value!.isEmpty) {
        state = AsyncError(e, stack);
      }
    }
  }
}
