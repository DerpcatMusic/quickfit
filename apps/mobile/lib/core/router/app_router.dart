// App router with auth guards
// lib/core/router/app_router.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/features/auth/presentation/login_screen.dart';
import 'package:quickfit/features/auth/presentation/onboarding_screen.dart';
import 'package:quickfit/features/jobs/presentation/job_list_screen.dart';
import 'package:quickfit/features/jobs/presentation/post_job_screen.dart';
import 'package:quickfit/features/profile/presentation/profile_screen.dart';
import 'package:quickfit/features/verification/presentation/verification_screen.dart';
import 'package:quickfit/features/instructor/screens/instructor_map_screen.dart';
import 'package:quickfit/shared/layouts/app_scaffold.dart';

part 'app_router.g.dart';

// Route paths
abstract class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';

  // Instructor routes
  static const String instructorHome = '/instructor';
  static const String instructorJobs = '/instructor/jobs';
  static const String instructorSchedule = '/instructor/schedule';
  static const String instructorProfile = '/instructor/profile';
  static const String instructorMap = '/instructor/map';

  // Studio routes
  static const String studioHome = '/studio';
  static const String studioJobs = '/studio/jobs';
  static const String studioPostJob = '/studio/post';
  static const String studioProfile = '/studio/profile';

  // Shared routes
  static const String verification = '/verification';
  static const String settings = '/settings';
}

// Auth state change notifier for GoRouter refresh
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

@riverpod
GoRouter router(Ref ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isLoggedIn = auth.user != null;
      final hasCompletedOnboarding = auth.hasCompletedOnboarding;
      final userRole = auth.role;

      final isLoginRoute = state.matchedLocation == AppRoutes.login;
      final isOnboardingRoute = state.matchedLocation == AppRoutes.onboarding;
      final isSplashRoute = state.matchedLocation == AppRoutes.splash;

      // Still loading
      if (auth.isLoading) {
        return isSplashRoute ? null : AppRoutes.splash;
      }

      // Not logged in -> go to login
      if (!isLoggedIn) {
        return isLoginRoute ? null : AppRoutes.login;
      }

      // Logged in but no onboarding -> go to onboarding
      if (!hasCompletedOnboarding) {
        return isOnboardingRoute ? null : AppRoutes.onboarding;
      }

      // Logged in with onboarding complete
      if (isLoginRoute || isOnboardingRoute || isSplashRoute) {
        // Redirect to appropriate home based on role
        return userRole == 'studio'
            ? AppRoutes.studioHome
            : AppRoutes.instructorHome;
      }

      return null;
    },
    routes: [
      // Splash / Loading
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Instructor shell
      ShellRoute(
        builder: (context, state, child) => AppScaffold(
          role: 'instructor',
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.instructorHome,
            redirect: (_, __) => AppRoutes.instructorJobs,
          ),
          GoRoute(
            path: AppRoutes.instructorJobs,
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: const JobListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.instructorSchedule,
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: const _PlaceholderScreen(title: 'Schedule'),
            ),
          ),
          GoRoute(
            path: AppRoutes.instructorProfile,
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.instructorMap,
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: const InstructorMapScreen(),
            ),
          ),
        ],
      ),

      // Studio shell
      ShellRoute(
        builder: (context, state, child) => AppScaffold(
          role: 'studio',
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.studioHome,
            redirect: (_, __) => AppRoutes.studioJobs,
          ),
          GoRoute(
            path: AppRoutes.studioJobs,
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: const _StudioJobsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.studioPostJob,
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: const PostJobScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.studioProfile,
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              child: const ProfileScreen(),
            ),
          ),
        ],
      ),

      // Shared routes
      GoRoute(
        path: AppRoutes.verification,
        builder: (context, state) => const VerificationScreen(),
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );
}

// Splash screen shown during auth loading
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Quickfit',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// Placeholder for screens not yet implemented
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(title),
      ),
    );
  }
}

// Studio jobs list (different from instructor view)
class _StudioJobsScreen extends StatelessWidget {
  const _StudioJobsScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('My Posted Jobs'),
      ),
    );
  }
}

// Error screen
class _ErrorScreen extends StatelessWidget {
  final Exception? error;

  const _ErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Page not found',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.splash),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
