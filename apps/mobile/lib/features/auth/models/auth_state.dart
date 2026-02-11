// Auth State model
// lib/features/auth/models/auth_state.dart

import 'package:firebase_auth/firebase_auth.dart';

/// Represents the current authentication and profile state.
class AuthState {
  /// Firebase user object.
  final User? user;

  /// Convex internal user ID.
  final String? convexUserId;

  /// User role: 'instructor' or 'studio'.
  final String? role;

  /// Whether user has completed the onboarding flow.
  final bool hasCompletedOnboarding;

  /// User phone number (optional).
  final String? phone;

  /// Backend profile name (source of truth for editable profile name).
  final String? name;

  /// User home address (optional).
  final String? homeAddress;

  /// User latitude (optional).
  final double? latitude;

  /// User longitude (optional).
  final double? longitude;

  /// Categories the user is interested in (e.g., ["yoga", "pilates"]).
  final List<String>? categories;

  /// Dispatch mode for instructors: 'radius' or 'zone'.
  final String? dispatchMode;

  /// Zone IDs for zone-based dispatch.
  final List<String>? zoneIds;

  /// Instructor's search radius in kilometers.
  final double? radiusKm;

  /// Whether the user is verified (instructors only).
  final bool isVerified;

  /// Persisted notification preference (if fetched from backend).
  final bool? notificationsEnabled;

  /// Persisted regular-job alert preference (if fetched from backend).
  final bool? regularJobAlerts;

  /// Persisted SOS alert preference (if fetched from backend).
  final bool? sosJobAlerts;

  /// Persisted language preference (if fetched from backend).
  final String? languageCode;

  /// Whether the app is loading auth state.
  final bool isLoading;

  /// Current error message (if any).
  final String? error;

  const AuthState({
    this.user,
    this.convexUserId,
    this.role,
    this.hasCompletedOnboarding = false,
    this.phone,
    this.name,
    this.homeAddress,
    this.latitude,
    this.longitude,
    this.categories,
    this.dispatchMode,
    this.zoneIds,
    this.radiusKm,
    this.isVerified = false,
    this.notificationsEnabled,
    this.regularJobAlerts,
    this.sosJobAlerts,
    this.languageCode,
    this.isLoading = false,
    this.error,
  });

  /// Creates a copy with updated fields.
  AuthState copyWith({
    User? user,
    String? convexUserId,
    String? role,
    bool? hasCompletedOnboarding,
    String? phone,
    String? name,
    String? homeAddress,
    double? latitude,
    double? longitude,
    List<String>? categories,
    String? dispatchMode,
    List<String>? zoneIds,
    double? radiusKm,
    bool? isVerified,
    bool? notificationsEnabled,
    bool? regularJobAlerts,
    bool? sosJobAlerts,
    String? languageCode,
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
      name: name ?? this.name,
      homeAddress: homeAddress ?? this.homeAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      categories: categories ?? this.categories,
      dispatchMode: dispatchMode ?? this.dispatchMode,
      zoneIds: zoneIds ?? this.zoneIds,
      radiusKm: radiusKm ?? this.radiusKm,
      isVerified: isVerified ?? this.isVerified,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      regularJobAlerts: regularJobAlerts ?? this.regularJobAlerts,
      sosJobAlerts: sosJobAlerts ?? this.sosJobAlerts,
      languageCode: languageCode ?? this.languageCode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Whether the user is an instructor.
  bool get isInstructor => role == 'instructor';

  /// Whether the user is a studio.
  bool get isStudio => role == 'studio';

  /// Whether the user is authenticated.
  bool get isAuthenticated => user != null;
}
