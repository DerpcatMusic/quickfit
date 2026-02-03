/// QuickFit App widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:quickfit/core/router/app_router.dart';
import 'package:quickfit/core/theme/app_theme.dart';
import 'package:quickfit/core/constants/app_constants.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';

/// Root widget for the QuickFit app.
class QuickfitApp extends ConsumerStatefulWidget {
  const QuickfitApp({super.key});

  @override
  ConsumerState<QuickfitApp> createState() => _QuickfitAppState();
}

class _QuickfitAppState extends ConsumerState<QuickfitApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeConvex();
  }

  Future<void> _initializeConvex() async {
    await ConvexClient.initialize(
      const ConvexConfig(
        deploymentUrl: AppConstants.convexUrl,
        clientId: 'quickfit-mobile-1.0',
        // The convex_flutter package has verbose logging by default.
        // Update package or check documentation for debug flag if logs become too noisy.
      ),
    );
    setState(() => _initialized = true);
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

          // Show a simple loading screen if not initialized
          builder: (context, child) {
            if (!_initialized) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return child!;
          },

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
