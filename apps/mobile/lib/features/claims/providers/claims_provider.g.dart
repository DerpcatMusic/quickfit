// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claims_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for studio to manage claims on their jobs

@ProviderFor(StudioClaimsNotifier)
final studioClaimsProvider = StudioClaimsNotifierProvider._();

/// Provider for studio to manage claims on their jobs
final class StudioClaimsNotifierProvider
    extends $NotifierProvider<StudioClaimsNotifier, AsyncValue<List<dynamic>>> {
  /// Provider for studio to manage claims on their jobs
  StudioClaimsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'studioClaimsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$studioClaimsNotifierHash();

  @$internal
  @override
  StudioClaimsNotifier create() => StudioClaimsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<dynamic>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<dynamic>>>(value),
    );
  }
}

String _$studioClaimsNotifierHash() =>
    r'c094e94c4004581ae7aae03ed757e2f343cea20c';

/// Provider for studio to manage claims on their jobs

abstract class _$StudioClaimsNotifier
    extends $Notifier<AsyncValue<List<dynamic>>> {
  AsyncValue<List<dynamic>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<dynamic>>, AsyncValue<List<dynamic>>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<dynamic>>, AsyncValue<List<dynamic>>>,
        AsyncValue<List<dynamic>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

/// Provider for instructors to view their claims

@ProviderFor(InstructorClaimsNotifier)
final instructorClaimsProvider = InstructorClaimsNotifierProvider._();

/// Provider for instructors to view their claims
final class InstructorClaimsNotifierProvider extends $NotifierProvider<
    InstructorClaimsNotifier, AsyncValue<List<dynamic>>> {
  /// Provider for instructors to view their claims
  InstructorClaimsNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'instructorClaimsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$instructorClaimsNotifierHash();

  @$internal
  @override
  InstructorClaimsNotifier create() => InstructorClaimsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<dynamic>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<dynamic>>>(value),
    );
  }
}

String _$instructorClaimsNotifierHash() =>
    r'f39698ca53c9dffc5ee92e1396d20e70379ab6c4';

/// Provider for instructors to view their claims

abstract class _$InstructorClaimsNotifier
    extends $Notifier<AsyncValue<List<dynamic>>> {
  AsyncValue<List<dynamic>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<dynamic>>, AsyncValue<List<dynamic>>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<dynamic>>, AsyncValue<List<dynamic>>>,
        AsyncValue<List<dynamic>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
