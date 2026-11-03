import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/billing/billing_failure.dart';
import '../../../core/billing/billing_providers.dart';
import '../../../core/billing/billing_service.dart';
import '../../../core/billing/logic/entitlement_polling.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/sync/sync_scheduler.dart';
import '../domain/subscription_state.dart';

part 'subscription_controller.g.dart';

const Duration _restoreTimeout = Duration(seconds: 15);

/// The paywall's actions: list packages, buy, restore, and wait for the
/// server to confirm. Premium is never taken from the store: after a purchase
/// or a restore the server is asked (`GET /v1/me/entitlements`) until it
/// reports premium, because the RevenueCat webhook can be late
/// (FRONTEND_FLUTTER §4.4).
///
/// Kept alive so that leaving the screen does not drop the wait for the server.
@Riverpod(keepAlive: true)
class SubscriptionController extends _$SubscriptionController {
  BillingService get _billing => ref.read(billingServiceProvider);

  @override
  SubscriptionState build() => const SubscriptionState();

  /// Whether this build can sell anything (a RevenueCat key is present).
  bool get isAvailable => _billing.isAvailable;

  /// Starts a fresh visit to the paywall. A wait that is still running keeps
  /// its state.
  void open() {
    if (!state.busy) {
      state = state.copyWith(
        phase: SubscriptionPhase.idle,
        notice: SubscriptionNotice.none,
      );
    }
    unawaited(loadPackages());
  }

  Future<void> loadPackages() async {
    if (!_billing.isAvailable) {
      state = state.copyWith(
        packagesFailure: BillingFailure.unavailable,
        packagesLoading: false,
      );
      return;
    }
    state = state.copyWith(packagesLoading: true, clearPackagesFailure: true);
    try {
      final packages = await _billing.loadPackages();
      state = state.copyWith(packages: packages, packagesLoading: false);
    } on BillingException catch (error) {
      state = state.copyWith(
        packagesLoading: false,
        packagesFailure: error.failure,
      );
    }
  }

  Future<void> buy(String packageId) async {
    final userId = ref.read(sessionControllerProvider).user?.id;
    if (state.busy || userId == null) {
      return;
    }
    state = state.copyWith(
      phase: SubscriptionPhase.purchasing,
      notice: SubscriptionNotice.none,
    );
    try {
      final outcome = await _billing.purchase(packageId, userId: userId);
      switch (outcome) {
        case PurchaseOutcome.purchased:
          await _confirm();
        case PurchaseOutcome.cancelled:
          state = state.copyWith(
            phase: SubscriptionPhase.idle,
            notice: SubscriptionNotice.cancelled,
          );
        case PurchaseOutcome.pending:
          state = state.copyWith(
            phase: SubscriptionPhase.idle,
            notice: SubscriptionNotice.pending,
          );
      }
    } on BillingException catch (error) {
      _fail(error.failure);
    }
  }

  Future<void> restore() async {
    final userId = ref.read(sessionControllerProvider).user?.id;
    if (state.busy || userId == null) {
      return;
    }
    state = state.copyWith(
      phase: SubscriptionPhase.purchasing,
      notice: SubscriptionNotice.none,
    );
    try {
      await _billing.restore(userId: userId);
      await _confirm(afterRestore: true);
    } on BillingException catch (error) {
      _fail(error.failure);
    }
  }

  /// "Periksa lagi" after a timeout: asks the server again for a while.
  Future<void> checkAgain() async {
    if (!state.busy) {
      await _confirm();
    }
  }

  /// Best effort refresh of the cached entitlement (opening the subscription
  /// screen); failures are ignored, the cache stays as it is.
  Future<void> refreshStatus() async {
    try {
      await ref.read(entitlementRepositoryProvider).refresh();
    } on Object {
      // Offline: the cached entitlement keeps applying.
    }
  }

  Future<void> _confirm({bool afterRestore = false}) async {
    state = state.copyWith(phase: SubscriptionPhase.processing);
    final repository = ref.read(entitlementRepositoryProvider);
    final result = await pollUntilPremium(
      // A restore of nothing should not keep the user waiting for half a minute.
      timeout: afterRestore ? _restoreTimeout : entitlementPollTimeout,
      isPremium: () async {
        try {
          return await repository.refresh();
        } on DioException catch (error) {
          final status = ApiException.from(error)?.status;
          if (status == 401 || status == 403) {
            throw const PollAbort(SubscriptionNotice.sessionExpired);
          }
          rethrow;
        }
      },
    );
    switch (result.outcome) {
      case PollOutcome.confirmed:
        state = state.copyWith(phase: SubscriptionPhase.confirmed);
        // Changes the plan refused are re-sent by the premium coordinator;
        // this also pulls whatever the server did meanwhile.
        ref.read(syncSchedulerProvider).requestSync();
      case PollOutcome.timedOut:
        state = state.copyWith(
          phase: afterRestore
              ? SubscriptionPhase.idle
              : SubscriptionPhase.timedOut,
          notice: afterRestore
              ? SubscriptionNotice.restoreNothing
              : SubscriptionNotice.none,
        );
      case PollOutcome.aborted:
        state = state.copyWith(
          phase: SubscriptionPhase.idle,
          notice: SubscriptionNotice.sessionExpired,
        );
    }
  }

  void _fail(BillingFailure failure) {
    state = state.copyWith(
      phase: SubscriptionPhase.idle,
      notice: SubscriptionNotice.failure,
      failure: failure,
    );
  }
}
