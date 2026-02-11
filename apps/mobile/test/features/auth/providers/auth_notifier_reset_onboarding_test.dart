import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/features/auth/services/auth_service.dart';
import 'package:quickfit/features/auth/services/user_service.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService();

  final StreamController<firebase_auth.User?> _controller =
      StreamController<firebase_auth.User?>.broadcast();

  @override
  Stream<firebase_auth.User?> get authStateChanges => _controller.stream;

  @override
  firebase_auth.User? get currentUser => null;

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

class _FakeUserService implements UserService {
  bool resetCalled = false;
  Object? resetError;

  @override
  Future<void> resetOnboarding() async {
    resetCalled = true;
    if (resetError != null) throw resetError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('resetOnboarding returns true when service succeeds', () async {
    final fakeAuth = _FakeAuthService();
    final fakeUser = _FakeUserService();

    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(fakeAuth),
        userServiceProvider.overrideWithValue(fakeUser),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier);
    final result = await notifier.resetOnboarding();

    expect(result, isTrue);
    expect(fakeUser.resetCalled, isTrue);
    final state = container.read(authProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.hasCompletedOnboarding, isFalse);
  });

  test('resetOnboarding returns false and sets error on failure', () async {
    final fakeAuth = _FakeAuthService();
    final fakeUser = _FakeUserService()..resetError = Exception('boom');

    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(fakeAuth),
        userServiceProvider.overrideWithValue(fakeUser),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier);
    final result = await notifier.resetOnboarding();

    expect(result, isFalse);
    expect(fakeUser.resetCalled, isTrue);
    final state = container.read(authProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNotNull);
  });
}
