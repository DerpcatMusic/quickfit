// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:quickfit/app.dart';
import 'package:quickfit/core/router/app_router.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(isLoading: false);
  }
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final testRouter = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox(),
        ),
      ],
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => FakeAuthNotifier()),
          routerProvider.overrideWithValue(testRouter),
        ],
        child: const QuickfitApp(),
      ),
    );

    // Verify that the app renders a MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
