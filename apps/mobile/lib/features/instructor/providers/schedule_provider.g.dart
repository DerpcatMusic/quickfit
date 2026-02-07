// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ScheduleNotifier)
final scheduleProvider = ScheduleNotifierProvider._();

final class ScheduleNotifierProvider
    extends $NotifierProvider<ScheduleNotifier, ScheduleState> {
  ScheduleNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'scheduleProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$scheduleNotifierHash();

  @$internal
  @override
  ScheduleNotifier create() => ScheduleNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduleState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduleState>(value),
    );
  }
}

String _$scheduleNotifierHash() => r'4f2b53fd9764e0aa7fdcb76c189501ced4ad896d';

abstract class _$ScheduleNotifier extends $Notifier<ScheduleState> {
  ScheduleState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ScheduleState, ScheduleState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ScheduleState, ScheduleState>,
        ScheduleState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
