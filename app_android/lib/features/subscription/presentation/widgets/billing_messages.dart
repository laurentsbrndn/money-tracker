import '../../../../core/billing/billing_failure.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/subscription_state.dart';

/// The Indonesian explanation of a store failure.
String billingFailureMessage(AppLocalizations l10n, BillingFailure failure) =>
    switch (failure) {
      BillingFailure.unavailable => l10n.paywallUnavailableBody,
      BillingFailure.network => l10n.billingErrorNetwork,
      BillingFailure.noProducts => l10n.billingErrorNoProducts,
      BillingFailure.productUnavailable => l10n.billingErrorProduct,
      BillingFailure.notAllowed => l10n.billingErrorNotAllowed,
      BillingFailure.busy => l10n.billingErrorBusy,
      BillingFailure.accountLink => l10n.billingErrorAccountLink,
      BillingFailure.unknown => l10n.billingErrorUnknown,
    };

/// The one-line result of the last purchase or restore, or null.
String? subscriptionNoticeMessage(
  AppLocalizations l10n,
  SubscriptionState state,
) => switch (state.notice) {
  SubscriptionNotice.none => null,
  SubscriptionNotice.cancelled => l10n.paywallCancelled,
  SubscriptionNotice.pending => l10n.paywallPending,
  SubscriptionNotice.restoreNothing => l10n.paywallRestoreNothing,
  SubscriptionNotice.sessionExpired => l10n.paywallSessionExpired,
  SubscriptionNotice.failure => billingFailureMessage(
    l10n,
    state.failure ?? BillingFailure.unknown,
  ),
};
