// Route path constants shared across router and screens.
// lib/core/router/app_routes.dart

abstract final class AppRoutes {
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
  static const String jobDetail = '/jobs/:id';
}
