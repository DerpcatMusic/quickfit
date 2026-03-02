import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:quickfit/features/auth/models/auth_state.dart';
import 'package:quickfit/features/auth/services/auth_service.dart';
import 'package:quickfit/features/auth/services/user_service.dart';
import 'package:quickfit/core/services/hive_service.dart';

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
    _authSubscription?.cancel();
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
  bool _syncQueued = false;

  List<String>? _normalizedZoneIds(dynamic rawZoneIds) {
    if (rawZoneIds is! List) return null;
    final normalized = rawZoneIds
        .map((zoneId) => _zoneIdToString(zoneId))
        .whereType<String>()
        .toList();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  String? _zoneIdToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      final candidate = value['_id'] ?? value['id'];
      if (candidate != null) return candidate.toString();
    }
    return value.toString();
  }

  Future<void> _syncUserData(firebase_auth.User user) async {
    if (_isSyncing) {
      _syncQueued = true;
      return;
    }
    _isSyncing = true;
    final syncUid = user.uid;

    try {
      final userData = await _userService.syncUser(user);
      if (_authService.currentUser?.uid != syncUid ||
          state.user?.uid != syncUid) {
        return;
      }

      if (userData != null) {
        final normalizedAddress = userData['homeAddress']?.toString() ??
            userData['address']?.toString();
        state = state.copyWith(
          user: user,
          convexUserId: userData['_id']?.toString(),
          role: userData['role']?.toString(),
          hasCompletedOnboarding: userData['hasCompletedOnboarding'] ?? false,
          name: userData['name']?.toString(),
          avatarUrl: userData['avatarUrl']?.toString(),
          phone: userData['phone']?.toString(),
          homeAddress: normalizedAddress,
          latitude: (userData['latitude'] as num?)?.toDouble(),
          longitude: (userData['longitude'] as num?)?.toDouble(),
          categories: userData['categories'] != null
              ? List<String>.from(userData['categories'] as List)
              : null,
          dispatchMode: userData['dispatchMode']?.toString(),
          zoneIds: _normalizedZoneIds(userData['zoneIds']),
          radiusKm: (userData['radiusKm'] as num?)?.toDouble(),
          isVerified: userData['isVerified'] ?? false,
          notificationsEnabled: userData['notificationsEnabled'] as bool?,
          regularJobAlerts: userData['regularJobAlerts'] as bool?,
          sosJobAlerts: userData['sosJobAlerts'] as bool?,
          languageCode: userData['languageCode']?.toString(),
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(user: user, isLoading: false);
      }
    } catch (e) {
      if (_authService.currentUser?.uid != syncUid ||
          state.user?.uid != syncUid) {
        return;
      }
      developer.log('Background User Sync Error',
          name: 'auth_notifier', error: e);
      state = state.copyWith(user: user, error: e.toString(), isLoading: false);
    } finally {
      _isSyncing = false;
      if (_syncQueued) {
        _syncQueued = false;
        final latest = _authService.currentUser;
        if (latest != null && state.user?.uid == latest.uid) {
          unawaited(_syncUserData(latest));
        }
      }
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
      final uid = state.user?.uid;
      if (uid != null && uid.isNotEmpty) {
        try {
          await HiveService().removeMutationsForUser(uid);
        } catch (_) {
          // Queue cleanup is best-effort and should not block sign-out.
        }
      }
      await _authService.signOut();
      await _userService.clearAuth();
    } catch (e) {
      developer.log('Sign out failure', name: 'auth_notifier', error: e);
      state = state.copyWith(
        isLoading: false,
        error: _formatError(e),
      );
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
    String? dispatchMode,
    List<String>? zoneIds,
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
        dispatchMode: dispatchMode,
        zoneIds: zoneIds,
      );

      state = state.copyWith(
        role: role,
        hasCompletedOnboarding: true,
        isLoading: false,
        error: null,
        name: name,
        homeAddress: address ?? state.homeAddress,
        dispatchMode: dispatchMode,
        zoneIds: zoneIds,
        radiusKm: radiusKm ?? state.radiusKm,
        latitude: latitude ?? state.latitude,
        longitude: longitude ?? state.longitude,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? avatarUrl,
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
        avatarUrl: avatarUrl,
        phone: phone,
        address: address,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        categories: categories,
      );
      if (name != null &&
          name.trim().isNotEmpty &&
          state.user?.displayName != name.trim()) {
        try {
          await state.user?.updateDisplayName(name.trim());
          await state.user?.reload();
        } catch (e) {
          developer.log(
            'Failed to update Firebase displayName',
            name: 'auth_notifier',
            error: e,
          );
        }
      }
      if (state.user != null) {
        await _syncUserData(state.user!);
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Updates dispatch-related settings without toggling global loading state.
  ///
  /// This is used by high-frequency map interactions (radius/pin/zones) to
  /// avoid route or app-wide rebuild churn while still persisting immediately.
  Future<bool> updateDispatchPreferences({
    required String dispatchMode,
    List<String>? zoneIds,
    double? radiusKm,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      await _userService.updateDispatchPreferences(
        dispatchMode: dispatchMode,
        zoneIds: zoneIds,
        radiusKm: radiusKm,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      state = state.copyWith(
        dispatchMode: dispatchMode,
        zoneIds: zoneIds ?? state.zoneIds,
        radiusKm: radiusKm ?? state.radiusKm,
        latitude: latitude ?? state.latitude,
        longitude: longitude ?? state.longitude,
        homeAddress: address ?? state.homeAddress,
        error: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateSettingsPreferences({
    bool? notificationsEnabled,
    bool? regularJobAlerts,
    bool? sosJobAlerts,
    String? languageCode,
  }) async {
    try {
      await _userService.updateSettingsPreferences(
        notificationsEnabled: notificationsEnabled,
        regularJobAlerts: regularJobAlerts,
        sosJobAlerts: sosJobAlerts,
        languageCode: languageCode,
      );
      state = state.copyWith(
        notificationsEnabled:
            notificationsEnabled ?? state.notificationsEnabled,
        regularJobAlerts: regularJobAlerts ?? state.regularJobAlerts,
        sosJobAlerts: sosJobAlerts ?? state.sosJobAlerts,
        languageCode: languageCode ?? state.languageCode,
        error: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
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

  Future<bool> resetOnboarding() async {
    state = state.copyWith(isLoading: true);
    try {
      await _userService.resetOnboarding();
      state = AuthState(
        user: state.user,
        hasCompletedOnboarding: false,
        isLoading: false,
        error: null,
      );
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        unawaited(_syncUserData(currentUser));
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
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

  Future<bool> requestEmailChangeVerification({
    required String newEmail,
    String? currentPassword,
  }) async {
    try {
      await _authService.requestEmailChangeVerification(
        newEmail: newEmail,
        currentPassword: currentPassword,
      );
      final current = _authService.currentUser;
      if (current != null) {
        state = state.copyWith(user: current, error: null);
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: _formatError(e));
      return false;
    }
  }

  Future<bool> handleIncomingAuthActionUri(Uri uri) async {
    try {
      final applied = await _authService.applyAuthActionFromUri(uri);
      if (!applied) return false;

      final current = _authService.currentUser;
      if (current != null) {
        await _syncUserData(current);
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
