import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:quickfit/features/auth/models/auth_state.dart';
import 'package:quickfit/features/auth/services/auth_service.dart';
import 'package:quickfit/features/auth/services/user_service.dart';

export 'package:quickfit/features/auth/models/auth_state.dart';

part 'auth_provider.g.dart';

/// Notifier that manages the application's authentication and user profile state.
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  StreamSubscription<firebase_auth.User?>? _authSubscription;

  AuthService get _authService => ref.read(authServiceProvider);
  UserService get _userService => ref.read(userServiceProvider);

  @override
  AuthState build() {
    _authSubscription =
        _authService.authStateChanges.listen(_onAuthStateChanged);

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    final initialUser = _authService.currentUser;
    if (initialUser != null) {
      _syncUserData(initialUser);
      return AuthState(user: initialUser, isLoading: true);
    }

    return const AuthState();
  }

  void _onAuthStateChanged(firebase_auth.User? user) {
    if (user != null) {
      developer.log('User logged in: ${user.email}', name: 'auth_notifier');
      state = state.copyWith(user: user, isLoading: true, error: null);
      _syncUserData(user);
    } else {
      developer.log('User logged out', name: 'auth_notifier');
      state = const AuthState();
    }
  }

  bool _isSyncing = false;

  Future<void> _syncUserData(firebase_auth.User user) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final userData = await _userService.syncUser(user);

      if (userData != null) {
        state = state.copyWith(
          user: user,
          convexUserId: userData['_id']?.toString(),
          role: userData['role']?.toString(),
          hasCompletedOnboarding: userData['hasCompletedOnboarding'] ?? false,
          phone: userData['phone']?.toString(),
          homeAddress: userData['homeAddress']?.toString(),
          latitude: (userData['latitude'] as num?)?.toDouble(),
          longitude: (userData['longitude'] as num?)?.toDouble(),
          categories: userData['categories'] != null
              ? List<String>.from(userData['categories'] as List)
              : null,
          radiusKm: (userData['radiusKm'] as num?)?.toDouble(),
          isVerified: userData['isVerified'] ?? false,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(user: user, isLoading: false);
      }
    } catch (e) {
      developer.log('Background User Sync Error',
          name: 'auth_notifier', error: e);
      state = state.copyWith(user: user, error: e.toString(), isLoading: false);
    } finally {
      _isSyncing = false;
    }
  }

  // --- Authentication Actions ---

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.signInWithGoogle();
      if (state.user == null) {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.signInWithApple();
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> signInWithEmail(
      {required String email, required String password}) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.signInWithEmail(email: email, password: password);
    } catch (e) {
      state = state.copyWith(error: _formatError(e), isLoading: false);
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.signUpWithEmail(
          email: email, password: password, displayName: displayName);
    } catch (e) {
      state = state.copyWith(error: _formatError(e), isLoading: false);
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.signOut();
      await _userService.clearAuth();
    } catch (e) {
      developer.log('Sign out failure', name: 'auth_notifier', error: e);
      state = const AuthState();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      state = state.copyWith(error: _formatError(e));
    }
  }

  // --- User Profile & Onboarding ---

  Future<bool> completeOnboarding({
    required String role,
    required String name,
    required List<String> categories,
    double? radiusKm,
    double? latitude,
    double? longitude,
    String? address,
    List<String>? selectedZones,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _userService.completeOnboarding(
        role: role,
        name: name,
        categories: categories,
        radiusKm: radiusKm,
        latitude: latitude,
        longitude: longitude,
        address: address,
        selectedZones: selectedZones,
      );

      state = state.copyWith(
        role: role,
        hasCompletedOnboarding: true,
        isLoading: false,
        error: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

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
      await _userService.updateProfile(
        name: name,
        phone: phone,
        address: address,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        categories: categories,
      );
      if (state.user != null) {
        await _syncUserData(state.user!);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // --- Account Management ---

  bool get hasEmailPasswordLinked {
    return state.user?.providerData.any((p) => p.providerId == 'password') ??
        false;
  }

  List<String> get linkedProviders {
    return state.user?.providerData.map((p) => p.providerId).toList() ?? [];
  }

  Future<void> resetOnboarding() async {
    state = state.copyWith(isLoading: true);
    try {
      await _userService.resetOnboarding();
      state = state.copyWith(
        hasCompletedOnboarding: false,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<bool> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _authService.linkEmailPassword(email: email, password: password);
      final updatedUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (updatedUser != null) {
        state = state.copyWith(user: updatedUser);
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: _formatError(e));
      return false;
    }
  }

  String _formatError(dynamic error) {
    if (error is firebase_auth.FirebaseAuthException) {
      return error.message ?? 'Authentication failed';
    }
    return error.toString();
  }
}

// Proxies for easy access

@riverpod
firebase_auth.User? currentUser(Ref ref) {
  return ref.watch(authProvider).user;
}

@riverpod
bool isLoggedIn(Ref ref) {
  return ref.watch(authProvider).user != null;
}

@riverpod
String? userRole(Ref ref) {
  return ref.watch(authProvider).role;
}

@riverpod
bool hasCompletedOnboarding(Ref ref) {
  return ref.watch(authProvider).hasCompletedOnboarding;
}
