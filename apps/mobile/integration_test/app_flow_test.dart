import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:quickfit/app.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/features/auth/presentation/login_screen.dart';

class _FakeUser implements firebase_auth.User {
  @override
  String get uid => 'test_uid';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _UnauthAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(isLoading: false);
  }
}

class _RolePendingAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState(
      user: _FakeUser(),
      hasCompletedOnboarding: true,
      role: null,
      isLoading: false,
    );
  }
}

class _StudioAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState(
      user: _FakeUser(),
      hasCompletedOnboarding: true,
      role: 'studio',
      isLoading: false,
    );
  }
}

class _InstructorAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState(
      user: _FakeUser(),
      hasCompletedOnboarding: true,
      role: 'instructor',
      isLoading: false,
    );
  }
}

Future<void> _pumpWithAuth(
  WidgetTester tester,
  AuthNotifier notifier,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => notifier),
      ],
      child: const QuickfitApp(),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots to login when unauthenticated', (tester) async {
    await _pumpWithAuth(tester, _UnauthAuthNotifier());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Quickfit'), findsOneWidget);
  });

  testWidgets('Logged in user with unresolved role remains on splash', (tester) async {
    await _pumpWithAuth(tester, _RolePendingAuthNotifier());

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Studio user lands in studio shell', (tester) async {
    await _pumpWithAuth(tester, _StudioAuthNotifier());

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('My Jobs'), findsOneWidget);
  });

  testWidgets('Instructor user lands in instructor shell', (tester) async {
    await _pumpWithAuth(tester, _InstructorAuthNotifier());

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Schedule'), findsOneWidget);
  });
}
