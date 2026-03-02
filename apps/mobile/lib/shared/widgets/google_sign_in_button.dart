import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfit/l10n/app_localizations.dart';
import '../../core/utils/platform.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'google_sign_in_button_stub.dart'
    if (dart.library.js_util) 'google_sign_in_button_web.dart';

class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (kIsWeb) {
      return getGoogleSignInButton();
    }

    if (isCupertinoPlatform(context)) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
          child: Text(l10n.continueWithGoogle),
        ),
      );
    }

    // On mobile, use a standard Material button that triggers AuthProvider
    return FilledButton.icon(
      onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
      icon: const Icon(Icons.login),
      label: Text(l10n.continueWithGoogle),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }
}
