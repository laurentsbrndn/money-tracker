/// What the paywall shows of a subscription package. The store SDK's own
/// types stay inside `BillingService`.
class PaywallPackage {
  const PaywallPackage({
    required this.id,
    required this.period,
    required this.priceText,
    required this.hasTrial,
    required this.title,
  });

  /// RevenueCat package identifier, passed back to `BillingService.purchase`.
  final String id;
  final PaywallPeriod period;

  /// The price as the store formats it (`Rp 49.000`).
  final String priceText;

  /// A free trial applies to this package (for a user who is eligible).
  final bool hasTrial;

  /// The store's product title, used when [period] is [PaywallPeriod.other].
  final String title;
}

enum PaywallPeriod { monthly, yearly, other }
