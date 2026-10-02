# Mobile CI

The application is in apps/mobile. CI uses **Flutter 3.38.7**, official flutter/flutter commit **3b62efc2a3da49882f43c372e0bc53daef7295a6**, matching apps/mobile/.metadata and the recorded local SDK version. This satisfies the committed lockfile's Dart >=3.10.3 and Flutter >=3.38.4 constraints without upgrading runtime dependencies.

## Checks

From apps/mobile (the copied local file contains only the existing null-valued placeholders, not credentials):

```sh
cp lib/core/config/api_keys_local_stub.dart lib/core/config/api_keys_local.dart
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

Analyze reports compiler issues, warnings and the existing flutter_lints rules. Test runs the committed widget suite even when analysis reports a failure, provided dependencies installed successfully. Neither failure is suppressed. The single always-present CI job is the stable result. Any failed step fails that check, without a second aggregate runner. Docs-only changes run the same bounded lane so there is no missing required result.

The workflow has one Ubuntu 24.04 mobile lane, immutable action/SDK pins, a 15-minute bound, read-only repository access, no persisted checkout credentials, and stale-run cancellation. No dependency cache is added before measuring its benefit.

## Known verification limits

CI copies the existing no-secret local configuration stub for analysis; the generated file is ignored and is never committed. Missing asset directories and unused-variable analyzer warnings remain visible.

The current widget smoke test creates QuickfitApp without providing service fakes. The app uses Convex/Firebase/Hive providers; existing initialization or dependency failures must be fixed in application/test code rather than disabling analyzer rules, skipping the test, or adding production credentials. CI invokes no production initialization script, backend deploy, scraper, payment operation, or live integration test.

This lane does not build or sign Android/iOS releases, run emulators, test native plugins/maps/background services, validate the legacy root pubspec, or deploy/test backend functions. Those require separate targeted coverage. The existing payments PR also changes app/router/provider/theme/test surfaces. It is not included or modified here, and this CI-only draft deliberately leaves those application decisions to that work.

[Flutter testing overview](https://docs.flutter.dev/testing/overview) · [Official SDK archive](https://docs.flutter.dev/install/archive?tab=linux) · [GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
