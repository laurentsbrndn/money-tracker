import '../../../core/billing/billing_failure.dart';
import '../../../core/billing/paywall_package.dart';

/// Where a purchase or restore is.
enum SubscriptionPhase {
  idle,

  /// The store dialog or the restore is running.
  purchasing,

  /// The store took the payment; waiting for the server to report premium.
  processing,

  /// The server reports premium.
  confirmed,

  /// The server did not report premium within the time limit. The payment may
  /// still arrive; the user can check again.
  timedOut,
}

/// A one-line result shown on the paywall.
enum SubscriptionNotice {
  none,
  cancelled,
  pending,
  restoreNothing,
  sessionExpired,
  failure,
}

/// The state of the paywall.
class SubscriptionState {
  const SubscriptionState({
    this.packages = const [],
    this.packagesLoading = false,
    this.packagesFailure,
    this.phase = SubscriptionPhase.idle,
    this.notice = SubscriptionNotice.none,
    this.failure,
  });

  final List<PaywallPackage> packages;
  final bool packagesLoading;

  /// Why the packages could not be listed (null while they can).
  final BillingFailure? packagesFailure;
  final SubscriptionPhase phase;
  final SubscriptionNotice notice;

  /// Set with [SubscriptionNotice.failure].
  final BillingFailure? failure;

  /// A purchase, a restore, or the wait for the server is in progress.
  bool get busy =>
      phase == SubscriptionPhase.purchasing ||
      phase == SubscriptionPhase.processing;

  SubscriptionState copyWith({
    List<PaywallPackage>? packages,
    bool? packagesLoading,
    BillingFailure? packagesFailure,
    bool clearPackagesFailure = false,
    SubscriptionPhase? phase,
    SubscriptionNotice? notice,
    BillingFailure? failure,
  }) => SubscriptionState(
    packages: packages ?? this.packages,
    packagesLoading: packagesLoading ?? this.packagesLoading,
    packagesFailure: clearPackagesFailure
        ? null
        : (packagesFailure ?? this.packagesFailure),
    phase: phase ?? this.phase,
    notice: notice ?? this.notice,
    failure: failure,
  );
}
