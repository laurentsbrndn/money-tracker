/// Why a store operation could not be done, in terms the UI can explain.
enum BillingFailure {
  /// No RevenueCat key in this build (`REVENUECAT_ANDROID_KEY` is empty), or
  /// the SDK could not be configured.
  unavailable,

  /// The store or RevenueCat could not be reached.
  network,

  /// No subscription products are offered (not configured in the console, or
  /// not available in this country/account).
  noProducts,

  /// The product cannot be bought (not published, or not allowed here).
  productUnavailable,

  /// The store account cannot buy right now (parental controls, payments
  /// disabled, Play Store problem).
  notAllowed,

  /// A purchase or restore is already running.
  busy,

  /// The server session cannot be linked to the store customer.
  accountLink,

  /// Anything else.
  unknown,
}

/// Raised by `BillingService` for everything except a user cancel or a
/// pending purchase, which are normal outcomes.
class BillingException implements Exception {
  const BillingException(this.failure);

  final BillingFailure failure;

  @override
  String toString() => 'BillingException($failure)';
}
