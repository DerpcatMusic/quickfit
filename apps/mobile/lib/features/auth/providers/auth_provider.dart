// Auth Provider - Firebase Auth + Convex sync
// lib/features/auth/providers/auth_provider.dart

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:quickfit/core/services/notification_service.dart';
import 'package:quickfit/core/services/location_service.dart';
import 'package:quickfit/core/utils/logger.dart';

part 'auth_provider.g.dart';

// Auth state model
class AuthState {
  final User? user;
  final String? convexUserId;
  final String? role;
  final bool hasCompletedOnboarding;
  final String? phone;
  final String? homeAddress;
  final List<String>? categories;
  final double? radiusKm;
  final bool isVerified;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.convexUserId,
    this.role,
    this.hasCompletedOnboarding = false,
    this.phone,
    this.homeAddress,
    this.categories,
    this.radiusKm,
    this.isVerified = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    String? convexUserId,
    String? role,
    bool? hasCompletedOnboarding,
    String? phone,
    String? homeAddress,
    List<String>? categories,
    double? radiusKm,
    bool? isVerified,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      convexUserId: convexUserId ?? this.convexUserId,
      role: role ?? this.role,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      phone: phone ?? this.phone,
      homeAddress: homeAddress ?? this.homeAddress,
      categories: categories ?? this.categories,
      radiusKm: radiusKm ?? this.radiusKm,
      isVerified: isVerified ?? this.isVerified,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isInstructor => role == 'instructor';
  bool get isStudio => role == 'studio';
}

@riverpod
class Auth extends _$Auth {
  final _auth = FirebaseAuth.instance;
  // GoogleSignIn is now a singleton in v7
  // We should initialize it before use.
  // Assuming GoogleSignIn.instance exists and initialize takes scopes?
  // If not, I'll get an analysis error and fix it.
  // The user prompt said: "Clients must call and await the new initialize method"
  // Using late or just accessing it in methods.
  // But strictly, `_googleSignIn` field usage:
  // `final _googleSignIn = GoogleSignIn(scopes: ...)` -> `final _googleSignIn = GoogleSignIn.instance;`

  // Actually, I can't declare it as final field via `GoogleSignIn.instance` if it's not a const (it's likely a getter).
  // So I'll use a getter or late final.
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  // ...

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _gsiSubscription;

  @override
  AuthState build() {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);

    // Initialize Google Sign-In for v7
    // On Web, this is required for renderButton and events to work.
    _googleSignIn.initialize().ignore();

    // Listen for Google Sign-In events (required for GIS / renderButton on Web)
    _gsiSubscription = _googleSignIn.authenticationEvents.listen(
      _handleGsiEvent,
      onError: (e) {
        log.e('Google Sign-In Stream Error: $e');
        state = state.copyWith(error: e.toString());
      },
    );

    ref.onDispose(() {
      _authSubscription?.cancel();
      _gsiSubscription?.cancel();
    });

    // Check initial state
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _syncWithConvex(currentUser);
      return AuthState(user: currentUser, isLoading: true);
    }

    return const AuthState();
  }

  Future<void> _handleGsiEvent(GoogleSignInAuthenticationEvent event) async {
    log.i('Google Sign-In Event: $event');

    if (event is GoogleSignInAuthenticationEventSignIn) {
      await _processGoogleUser(event.user);
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      state = const AuthState();
    }
  }

  Future<void> _processGoogleUser(GoogleSignInAccount googleUser) async {
    try {
      state = state.copyWith(isLoading: true);

      final authDetails = googleUser.authentication;
      final idToken = authDetails.idToken;

      // Access token via authorizationClient (Standard for v7)
      final authz = await googleUser.authorizationClient
          .authorizeScopes(['email', 'profile']);
      final accessToken = authz.accessToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token from Google');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      await _auth.signInWithCredential(credential);
    } catch (e) {
      log.e('Failed to process Google user: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void _onAuthStateChanged(User? user) {
    if (user != null) {
      _syncWithConvex(user);
    } else {
      state = const AuthState();
    }
  }

  Future<void> _syncWithConvex(User user) async {
    try {
      await _retryWithBackoff(() async {
        // Set up Convex auth with Firebase token refresh
        await ConvexClient.instance.setAuthWithRefresh(
          fetchToken: () async {
            final u = FirebaseAuth.instance.currentUser;
            return await u?.getIdToken(true);
          },
          onAuthChange: (isAuthenticated) {
            // Use logger or handled silence
          },
        );

        // Sync user to Convex
        await ConvexClient.instance.mutation(
          name: 'users:syncUser',
          args: {
            'firebaseUid': user.uid,
            'email': user.email ?? '',
            'name': user.displayName ?? '',
            'photoUrl': user.photoURL ?? '',
          },
        );

        // Get user data from Convex - positional arguments, all strings
        final resultJson = await ConvexClient.instance.query(
          'users:getCurrentUser',
          {},
        );

        // Handle null/empty response from Convex
        if (resultJson.isEmpty || resultJson == 'null') {
          state = AuthState(user: user, isLoading: false);
          return;
        }

        final decoded = json.decode(resultJson);
        final userData = decoded as Map<String, dynamic>?;

        if (userData != null) {
          state = state.copyWith(
            user: user,
            convexUserId: userData['_id']?.toString(),
            role: userData['role']?.toString(),
            hasCompletedOnboarding: userData['hasCompletedOnboarding'] ?? false,
            phone: userData['phone']?.toString(),
            homeAddress: userData['homeAddress']?.toString(),
            categories: userData['categories'] != null
                ? List<String>.from(userData['categories'] as List)
                : null,
            radiusKm: (userData['radiusKm'] as num?)?.toDouble(),
            isVerified: userData['isVerified'] ?? false,
            isLoading: false,
          );
        } else {
          state = AuthState(user: user, isLoading: false);
        }
      });
    } catch (e) {
      state = AuthState(user: user, error: e.toString(), isLoading: false);
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true);

    try {
      // Initialize is required in v7
      await _googleSignIn.initialize();

      if (kIsWeb) {
        // Web: renderButton handles the UI flow.
        // We just need to make sure we're initialized.
        // programmatic sign-in is managed by GIS via the button.
        log.i('Web sign-in triggered (should be via renderButton)');
      } else {
        // Mobile: use authenticate() (v7 recommended for programmatic trigger)
        final googleUser = await _googleSignIn.authenticate(
          scopeHint: ['email', 'profile'],
        );

        await _processGoogleUser(googleUser);
      }
    } catch (e) {
      // Check for cancellation
      if (e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled) {
        state = state.copyWith(isLoading: false);
        return;
      }

      log.e('Google Sign-In Action Error: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // Sign in with Apple
  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true);

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      await _auth.signInWithCredential(oauthCredential);
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  /// Sign up with email and password.
  ///
  /// Creates a new Firebase user and syncs with Convex.
  /// If email already exists with Google, the error will guide them to sign in with Google.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
      }

      // Auth state change listener will handle Convex sync
    } on FirebaseAuthException catch (e) {
      log.e('Email sign-up error: $e');

      // Handle account-exists-with-different-credential
      if (e.code == 'email-already-in-use') {
        state = state.copyWith(
          error:
              'This email is already in use. If you signed up with Google, use Google Sign-In, then add a password in Profile Settings.',
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          error: _getFirebaseAuthErrorMessage(e),
          isLoading: false,
        );
      }
    } catch (e) {
      log.e('Email sign-up error: $e');
      state = state.copyWith(
        error: _getFirebaseAuthErrorMessage(e),
        isLoading: false,
      );
    }
  }

  /// Link email/password to current user (for users who signed up with Google).
  /// Call this from profile settings to allow Google users to add a password.
  Future<bool> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(error: 'Not signed in');
      return false;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.linkWithCredential(credential);
      log.i('Successfully linked email/password to account');
      return true;
    } on FirebaseAuthException catch (e) {
      log.e('Link email error: $e');
      if (e.code == 'provider-already-linked') {
        state = state.copyWith(
            error: 'Email/password already set up for this account');
      } else if (e.code == 'credential-already-in-use') {
        state = state.copyWith(
            error: 'This email is already used by another account');
      } else {
        state = state.copyWith(error: _getFirebaseAuthErrorMessage(e));
      }
      return false;
    } catch (e) {
      log.e('Link email error: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Check if current user has email/password linked.
  bool get hasEmailPasswordLinked {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  /// Get linked provider names for current user.
  List<String> get linkedProviders {
    final user = _auth.currentUser;
    if (user == null) return [];
    return user.providerData.map((p) {
      switch (p.providerId) {
        case 'google.com':
          return 'Google';
        case 'apple.com':
          return 'Apple';
        case 'password':
          return 'Email';
        default:
          return p.providerId;
      }
    }).toList();
  }

  /// Sign in with email and password.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Auth state change listener will handle Convex sync
    } catch (e) {
      log.e('Email sign-in error: $e');
      state = state.copyWith(
        error: _getFirebaseAuthErrorMessage(e),
        isLoading: false,
      );
    }
  }

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      log.e('Password reset error: $e');
      state = state.copyWith(error: _getFirebaseAuthErrorMessage(e));
    }
  }

  /// Convert Firebase auth errors to user-friendly messages.
  String _getFirebaseAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'invalid-email':
          return 'Invalid email address';
        case 'weak-password':
          return 'Password is too weak (min 6 characters)';
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password';
        case 'invalid-credential':
          return 'Invalid email or password. If you signed up with Google, use Google Sign-In instead.';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later';
        default:
          return error.message ?? 'Authentication failed';
      }
    }
    return error.toString();
  }

  // Complete onboarding
  Future<void> completeOnboarding({
    required String role,
    required String name,
    required List<String> categories,
    double? radiusKm,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final mutationArgs = {
        'role': role,
        'name': name,
        'categories': categories.join(','),
        if (radiusKm != null) 'radiusKm': radiusKm as num,
        if (latitude != null) 'latitude': latitude as num,
        if (longitude != null) 'longitude': longitude as num,
        if (address != null) 'address': address,
      };

      log.i('Completing onboarding with args: $mutationArgs');
      for (final key in mutationArgs.keys) {
        log.i(
            'Arg $key: ${mutationArgs[key]} (type: ${mutationArgs[key].runtimeType})');
      }

      await _retryWithBackoff(() async {
        await ConvexClient.instance.mutation(
          name: 'users:completeOnboarding',
          args: mutationArgs,
        );

        state = state.copyWith(
          role: role,
          hasCompletedOnboarding: true,
        );
      });
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Update FCM token
  Future<void> updateFcmToken() async {
    final token = NotificationService.instance.fcmToken;
    if (token == null) return;

    try {
      await ConvexClient.instance.mutation(
        name: 'users:updateFcmToken',
        args: {'token': token},
      );
    } catch (e) {
      log.e('Failed to update FCM token: $e');
    }
  }

  // Update location
  Future<void> updateLocation() async {
    final lat = LocationService.instance.latitude;
    final lng = LocationService.instance.longitude;
    if (lat == null || lng == null) return;

    try {
      await ConvexClient.instance.mutation(
        name: 'users:updateLocation',
        args: {
          'latitude': lat,
          'longitude': lng,
        },
      );
    } catch (e) {
      log.e('Failed to update location: $e');
    }
  }

  // Update profile
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
      await ConvexClient.instance.mutation(
        name: 'users:updateProfile',
        args: {
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
          if (address != null) 'homeAddress': address,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (radiusKm != null) 'radiusKm': radiusKm,
          if (categories != null) 'categories': categories,
        },
      );

      // Refresh user state
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _syncWithConvex(currentUser);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await ConvexClient.instance.clearAuth();
    state = const AuthState();
  }

  // Reset onboarding
  Future<void> resetOnboarding() async {
    try {
      await ConvexClient.instance.mutation(
        name: 'users:resetOnboarding',
        args: {},
      );
      state = state.copyWith(hasCompletedOnboarding: false);
    } catch (e) {
      log.e('Failed to reset onboarding: $e');
    }
  }

  /// Helper to retry operations that might fail due to connection issues
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxAttempts = 5,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts >= maxAttempts) rethrow;

        // Check for specific connection/socket errors
        final errorStr = e.toString().toLowerCase();
        final isConnectionError = errorStr.contains('websocket') ||
            errorStr.contains('connection') ||
            errorStr.contains('socket');

        if (isConnectionError) {
          log.w(
              'Operation failed (attempt $attempts/$maxAttempts): $e. Retrying in ${delay.inMilliseconds}ms...');
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff
        } else {
          rethrow; // Don't retry for non-connection errors
        }
      }
    }
  }
}

// Convenience providers
@riverpod
User? currentUser(Ref ref) {
  return ref.watch(authProvider).user;
}

@riverpod
bool isLoggedIn(Ref ref) {
  return ref.watch(currentUserProvider) != null;
}

@riverpod
String? userRole(Ref ref) {
  return ref.watch(authProvider).role;
}

@riverpod
bool hasCompletedOnboarding(Ref ref) {
  return ref.watch(authProvider).hasCompletedOnboarding;
}
