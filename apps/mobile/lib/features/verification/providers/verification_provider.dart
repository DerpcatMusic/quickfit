import 'dart:async';
import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final latestVerificationProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  final controller = StreamController<Map<String, dynamic>?>();
  SubscriptionHandle? handle;

  Future<void> start() async {
    try {
      handle = await ConvexClient.instance.subscribe(
        name: 'verifications:getMyVerifications',
        args: {},
        onUpdate: (data) {
          if (controller.isClosed) return;
          if (data.isEmpty || data == 'null') {
            controller.add(null);
            return;
          }

          final dynamic decoded = json.decode(data);
          if (decoded is! List || decoded.isEmpty) {
            controller.add(null);
            return;
          }

          final latest = decoded.first;
          if (latest is Map<String, dynamic>) {
            controller.add(latest);
          } else if (latest is Map) {
            controller.add(Map<String, dynamic>.from(latest));
          } else {
            controller.add(null);
          }
        },
        onError: (message, value) {
          if (!controller.isClosed) {
            controller.addError(message);
          }
        },
      );
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  start();

  ref.onDispose(() async {
    handle?.cancel();
    await controller.close();
  });

  return controller.stream;
});
