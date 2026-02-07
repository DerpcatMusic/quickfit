// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jobs_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(JobsNotifier)
final jobsProvider = JobsNotifierProvider._();

final class JobsNotifierProvider
    extends $NotifierProvider<JobsNotifier, JobsState> {
  JobsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'jobsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$jobsNotifierHash();

  @$internal
  @override
  JobsNotifier create() => JobsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JobsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JobsState>(value),
    );
  }
}

String _$jobsNotifierHash() => r'2ac6afe437b3ca51dfcc79b2e755bfb965665ef1';

abstract class _$JobsNotifier extends $Notifier<JobsState> {
  JobsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<JobsState, JobsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<JobsState, JobsState>, JobsState, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(StudioJobsNotifier)
final studioJobsProvider = StudioJobsNotifierProvider._();

final class StudioJobsNotifierProvider
    extends $NotifierProvider<StudioJobsNotifier, JobsState> {
  StudioJobsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'studioJobsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$studioJobsNotifierHash();

  @$internal
  @override
  StudioJobsNotifier create() => StudioJobsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JobsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JobsState>(value),
    );
  }
}

String _$studioJobsNotifierHash() =>
    r'b1271010dfa933e080fc0c2f09365fc16d18bc3e';

abstract class _$StudioJobsNotifier extends $Notifier<JobsState> {
  JobsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<JobsState, JobsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<JobsState, JobsState>, JobsState, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(job)
final jobProvider = JobFamily._();

final class JobProvider
    extends $FunctionalProvider<AsyncValue<Job?>, Job?, FutureOr<Job?>>
    with $FutureModifier<Job?>, $FutureProvider<Job?> {
  JobProvider._({required JobFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'jobProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$jobHash();

  @override
  String toString() {
    return r'jobProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Job?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Job?> create(Ref ref) {
    final argument = this.argument as String;
    return job(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is JobProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$jobHash() => r'6d319d3659cf1199d32c6e83ebfd5bb1bc17b57c';

final class JobFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Job?>, String> {
  JobFamily._()
      : super(
          retry: null,
          name: r'jobProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  JobProvider call(
    String jobId,
  ) =>
      JobProvider._(argument: jobId, from: this);

  @override
  String toString() => r'jobProvider';
}
