# Mobile CI

The application is in apps/mobile. CI uses **Flutter 3.38.7**, official flutter/flutter commit **3b62efc2a3da49882f43c372e0bc53daef7295a6**, matching apps/mobile/.metadata and the recorded local SDK version. This satisfies the committed lockfile's Dart >=3.10.3 and Flutter >=3.38.4 constraints without upgrading runtime dependencies.

## Checks

From apps/mobile:

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

Analyze reports compiler issues, warnings and the existing flutter_lints rules. Test runs the committed widget suite even when analysis reports a failure, provided dependencies installed successfully. Neither failure is suppressed. The final CI result always runs and requires the mobile job to succeed. Docs-only changes run the same bounded lane so there is no missing required result.

The workflow has one Ubuntu 24.04 mobile lane, immutable action/SDK pins, a 15-minute bound, read-only repository access, no persisted checkout credentials, and stale-run cancellation. No dependency cache is added before measuring its benefit.

## Known verification limits

The current widget smoke test creates QuickfitApp without providing service fakes. The app uses Convex/Firebase/Hive providers; existing initialization or dependency failures must be fixed in application/test code rather than disabling analyzer rules, skipping the test, or adding production credentials. CI invokes no production initialization script, backend deploy, scraper, payment operation, or live integration test.

This lane does not build or sign Android/iOS releases, run emulators, test native plugins/maps/background services, validate the legacy root pubspec, or deploy/test backend functions. Those require separate targeted coverage. The existing payments PR is unrelated and is not included or modified.

[Flutter testing overview](https://docs.flutter.dev/testing/overview) · [Official SDK archive](https://docs.flutter.dev/install/archive?tab=linux) · [GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
