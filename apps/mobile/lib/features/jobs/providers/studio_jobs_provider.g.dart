// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'studio_jobs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StudioJobsNotifier)
final studioJobsProvider = StudioJobsNotifierProvider._();

final class StudioJobsNotifierProvider
    extends $NotifierProvider<StudioJobsNotifier, StudioJobsState> {
  StudioJobsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'studioJobsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$studioJobsNotifierHash();

  @$internal
  @override
  StudioJobsNotifier create() => StudioJobsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StudioJobsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StudioJobsState>(value),
    );
  }
}

String _$studioJobsNotifierHash() =>
    r'aa18bb0543f1a14a73c2c876ebc0cc8c6279de1c';

abstract class _$StudioJobsNotifier extends $Notifier<StudioJobsState> {
  StudioJobsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<StudioJobsState, StudioJobsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<StudioJobsState, StudioJobsState>,
        StudioJobsState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
