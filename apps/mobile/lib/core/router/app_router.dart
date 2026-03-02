// App router with auth guards
// lib/core/router/app_router.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:quickfit/l10n/app_localizations.dart';
import 'package:quickfit/core/router/app_routes.dart';

import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/features/auth/presentation/login_screen.dart';
import 'package:quickfit/features/auth/presentation/onboarding_screen.dart';
import 'package:quickfit/features/jobs/presentation/job_list_screen.dart';
import 'package:quickfit/features/jobs/presentation/post_job_screen.dart';
import 'package:quickfit/features/jobs/presentation/job_detail_screen.dart';
import 'package:quickfit/core/services/notification_service.dart';
import 'package:quickfit/core/utils/logger.dart';
import 'package:quickfit/features/profile/presentation/profile_screen.dart';
import 'package:quickfit/features/verification/presentation/verification_screen.dart';
import 'package:quickfit/features/instructor/map/presentation/instructor_map_screen.dart';
import 'package:quickfit/features/instructor/screens/instructor_schedule_screen.dart';
import 'package:quickfit/features/studio/presentation/screens/studio_jobs_screen.dart';
import 'package:quickfit/features/studio/presentation/screens/studio_public_profile_screen.dart';
import 'package:quickfit/shared/layouts/app_scaffold.dart';

part 'app_router.g.dart';

// Auth state change notifier for GoRouter refresh
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _lastSnapshot = _snapshot(_ref.read(authProvider));
    _ref.listen(authProvider, (previous, next) {
      final nextSnapshot = _snapshot(next);
      if (nextSnapshot == _lastSnapshot) return;
      _lastSnapshot = nextSnapshot;
      notifyListeners();
    });
  }

  final Ref _ref;
  String? _lastSnapshot;

  String _snapshot(AuthState state) {
    return [
      state.user?.uid ?? '',
      state.isLoading ? '1' : '0',
      state.hasCompletedOnboarding ? '1' : '0',
      state.role ?? '',
    ].join('|');
  }
}

@riverpod
GoRouter router(Ref ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  final goRouter = GoRouter(
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
      final isVerificationRoute =
          state.matchedLocation == AppRoutes.verification;
      final isStudioRoute = state.matchedLocation.startsWith('/studio');
      final isInstructorRoute = state.matchedLocation.startsWith('/instructor');

      // Avoid role/onboarding redirect races until auth/profile hydration settles.
      if (auth.isLoading) {
        if (isSplashRoute) return null;
        if (!isLoggedIn && isLoginRoute) return null;
        return AppRoutes.splash;
      }

      // Not logged in -> go to login
      if (!isLoggedIn) {
        return isLoginRoute ? null : AppRoutes.login;
      }

      // Logged in but no onboarding -> go to onboarding
      if (!hasCompletedOnboarding) {
        return isOnboardingRoute ? null : AppRoutes.onboarding;
      }

      if (userRole == null) {
        return isSplashRoute ? null : AppRoutes.splash;
      }

      // Logged in with onboarding complete
      if (isLoginRoute || isOnboardingRoute || isSplashRoute) {
        // Redirect to appropriate home based on role
        return userRole == 'studio'
            ? AppRoutes.studioHome
            : AppRoutes.instructorHome;
      }

      if (isStudioRoute && userRole != 'studio') {
        return userRole == 'instructor'
            ? AppRoutes.instructorHome
            : AppRoutes.splash;
      }

      if (isInstructorRoute && userRole != 'instructor') {
        return userRole == 'studio' ? AppRoutes.studioHome : AppRoutes.splash;
      }

      // Verification is instructor-only.
      if (isVerificationRoute && userRole != 'instructor') {
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
      GoRoute(
        path: AppRoutes.instructorHome,
        redirect: (_, __) => AppRoutes.instructorJobs,
      ),
      GoRoute(
        path: AppRoutes.studioHome,
        redirect: (_, __) => AppRoutes.studioJobs,
      ),

      // Instructor shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppScaffold(
          role: 'instructor',
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.instructorJobs,
                builder: (context, state) => const JobListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.instructorSchedule,
                builder: (context, state) => const InstructorScheduleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.instructorMap,
                builder: (context, state) => const InstructorMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.instructorProfile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Studio shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppScaffold(
          role: 'studio',
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studioJobs,
                builder: (context, state) => const StudioJobsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studioPostJob,
                builder: (context, state) => const PostJobScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studioProfile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Shared routes
      GoRoute(
        path: AppRoutes.verification,
        builder: (context, state) => const VerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.jobDetail,
        builder: (context, state) {
          final jobId = state.pathParameters['id']!;
          return JobDetailScreen(jobId: jobId);
        },
      ),
      GoRoute(
        path: AppRoutes.studioPublicProfile,
        builder: (context, state) {
          final studioId = state.pathParameters['id']!;
          return StudioPublicProfileScreen(studioId: studioId);
        },
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );

  // GLOBAL NOTIFICATION LISTENER
  final notificationSub =
      NotificationService.instance.onNotification.listen((message) {
    final data = message.data;
    final type = data['type'];
    final jobId = data['jobId'];

    log.i('[Router] Notification received: type=$type, jobId=$jobId');

    if (type == 'new_job' && jobId != null) {
      goRouter.push(AppRoutes.jobDetail.replaceFirst(':id', jobId));
    }
  });
  ref.onDispose(notificationSub.cancel);

  return goRouter;
}

// Splash screen shown during auth loading
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.appName,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.pageNotFound,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.splash),
              child: Text(l10n.goHome),
            ),
          ],
        ),
      ),
    );
  }
}
