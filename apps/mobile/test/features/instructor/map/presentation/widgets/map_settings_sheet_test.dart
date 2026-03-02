import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickfit/core/models/zone.dart';
import 'package:quickfit/core/providers/zone_provider.dart';
import 'package:quickfit/core/theme/app_colors.dart';
import 'package:quickfit/features/instructor/map/presentation/widgets/map_settings_sheet.dart';
import 'package:quickfit/l10n/app_localizations.dart';

class _FakeZonesNotifier extends ZonesNotifier {
  @override
  Future<List<Zone>> build() async => const <Zone>[];
}

ThemeData _theme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.light.cobaltAccent,
      brightness: Brightness.light,
    ),
    extensions: const [AppColors.light],
  );
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required TextEditingController controller,
  required ValueChanged<double> onRadiusChanged,
  required VoidCallback onRadiusChangeEnd,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [zonesProvider.overrideWith(_FakeZonesNotifier.new)],
      child: MaterialApp(
        theme: _theme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MapSettingsSheet(
            mode: SelectionMode.radius,
            radiusKm: 2.0,
            selectedZoneIds: const <String>{},
            isExpanded: true,
            addressController: controller,
            isResolvingAddress: false,
            isPinDropMode: false,
            onToggleExpanded: () {},
            onTogglePinDropMode: () {},
            onApplyAddress: () {},
            onAddressSelected: ({
              required address,
              required latitude,
              required longitude,
            }) {},
            onModeChanged: (_) {},
            onRadiusChanged: onRadiusChanged,
            onRadiusChangeEnd: onRadiusChangeEnd,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('radius slider emits live onRadiusChanged before commit callback',
      (tester) async {
    final changedValues = <double>[];
    var changeEndCount = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pumpSheet(
      tester,
      controller: controller,
      onRadiusChanged: changedValues.add,
      onRadiusChangeEnd: () => changeEndCount++,
    );

    final sliderFinder = find.byType(Slider);
    expect(sliderFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(sliderFinder));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();

    expect(changedValues, isNotEmpty);
    expect(changeEndCount, 0);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(changeEndCount, 1);
    expect(
      changedValues.every((value) => ((value * 100).round() % 5) == 0),
      isTrue,
    );
  });

  testWidgets('quick radius chip triggers change and commit immediately',
      (tester) async {
    final changedValues = <double>[];
    var changeEndCount = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pumpSheet(
      tester,
      controller: controller,
      onRadiusChanged: changedValues.add,
      onRadiusChangeEnd: () => changeEndCount++,
    );

    await tester.tap(find.byType(ChoiceChip).at(3));
    await tester.pumpAndSettle();

    expect(changedValues.length, 1);
    expect(changedValues.first, closeTo(5.0, 0.001));
    expect(changeEndCount, 1);
  });
}
