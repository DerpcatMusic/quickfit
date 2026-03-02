/// QuickFit App widget.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quickfit/l10n/app_localizations.dart';

import 'package:quickfit/core/router/app_router.dart';
import 'package:quickfit/core/theme/app_theme.dart';
import 'package:quickfit/features/auth/providers/auth_provider.dart';
import 'package:quickfit/features/auth/services/auth_service.dart';
import 'package:quickfit/core/utils/platform.dart';
import 'package:quickfit/core/providers/settings_provider.dart';

/// Root widget for the QuickFit app.
/// Convex is already initialized in main.dart before this widget mounts.
class QuickfitApp extends ConsumerStatefulWidget {
  const QuickfitApp({super.key});

  @override
  ConsumerState<QuickfitApp> createState() => _QuickfitAppState();
}

class _QuickfitAppState extends ConsumerState<QuickfitApp> {
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _authActionLinkSub;
  final Set<String> _processedAuthActionCodes = <String>{};

  @override
  void initState() {
    super.initState();
    ref.read(authServiceProvider).initialize().ignore();
    _bootstrapAuthActionHandlers();
    // Zones are loaded lazily when the zone selection UI is used.
  }

  void _bootstrapAuthActionHandlers() {
    _processAuthActionUri(Uri.base);
    if (_supportsNativeAppLinks) {
      _attachNativeAuthLinkListeners();
    }
  }

  bool get _supportsNativeAppLinks =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _attachNativeAuthLinkListeners() async {
    try {
      _appLinks = AppLinks();
      final initial = await _appLinks!.getInitialLink();
      if (initial != null) {
        _processAuthActionUri(initial);
      }
      _authActionLinkSub = _appLinks!.uriLinkStream.listen(
        (uri) {
          _processAuthActionUri(uri);
        },
        onError: (error) {
          if (error is MissingPluginException) return;
          debugPrint('app_links stream error: $error');
        },
      );
    } on MissingPluginException {
      // Plugin channel unavailable on this platform/runtime. Uri.base still
      // handles web/email action links and native listeners remain optional.
    }
  }

  void _processAuthActionUri(Uri uri) {
    final oobCode = uri.queryParameters['oobCode']?.trim();
    if (oobCode == null || oobCode.isEmpty) return;
    if (!_processedAuthActionCodes.add(oobCode)) return;

    ref.read(authProvider.notifier).handleIncomingAuthActionUri(uri);
  }

  @override
  void dispose() {
    _authActionLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final languageCode = settingsAsync.value?.languageCode;
    final locale = languageCode == null
        ? null
        : (languageCode == 'he'
            ? const Locale('he', 'IL')
            : const Locale('en', 'US'));

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context)?.appName ?? 'Quickfit',
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
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            if (isCupertinoPlatform(context)) {
              final brightness = MediaQuery.platformBrightnessOf(context);
              return CupertinoTheme(
                data: AppTheme.getCupertinoTheme(
                  brightness,
                  role: ref.watch(authProvider).role,
                ),
                child: child,
              );
            }
            return child;
          },

          // Localization
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
