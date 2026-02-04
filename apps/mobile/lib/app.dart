/// QuickFit App widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:quickfit/core/router/app_router.dart';
import 'package:quickfit/core/theme/app_theme.dart';
import 'package:quickfit/core/constants/app_constants.dart';
import 'package:quickfit/core/providers/zone_provider.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';

/// Root widget for the QuickFit app.
/// Convex is already initialized in main.dart before this widget mounts.
class QuickfitApp extends ConsumerStatefulWidget {
  const QuickfitApp({super.key});

  @override
  ConsumerState<QuickfitApp> createState() => _QuickfitAppState();
}

class _QuickfitAppState extends ConsumerState<QuickfitApp> {
  @override
  void initState() {
    super.initState();
    // Preload zones in background so they're ready when needed
    // Convex is already initialized in main.dart
    ref.read(zonesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp.router(
          title: AppConstants.appName,
          theme: AppTheme.getThemeData(
            lightDynamic,
            Brightness.light,
            role: ref.watch(authProvider).role,
          ),
          darkTheme: AppTheme.getThemeData(
            darkDynamic,
            Brightness.dark,
            role: ref.watch(authProvider).role,
          ),
          themeMode: ThemeMode.system,
          routerConfig: router,
          debugShowCheckedModeBanner: false,

          // Localization
          locale: const Locale('he', 'IL'),
          supportedLocales: const [
            Locale('he', 'IL'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
