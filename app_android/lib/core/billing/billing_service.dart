import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';
import 'billing_failure.dart';
import 'paywall_package.dart';

/// How a purchase ended when it did not fail.
enum PurchaseOutcome {
  /// The store took the payment. Premium is NOT granted yet: the server
  /// learns about it from the RevenueCat webhook (FRONTEND_FLUTTER §4.4).
  purchased,

  /// The user closed the store dialog.
  cancelled,

  /// The payment is pending (for example a cash or approval based method); it
  /// completes later, outside the app.
  pending,
}

/// The only place that talks to the RevenueCat SDK (FRONTEND_FLUTTER §4.4):
/// it signs the server user in and out, lists the packages, buys, and
/// restores. It never answers "is the user premium": that comes from the
/// server's entitlement.
class BillingService {
  BillingService({String? apiKey})
    : _apiKey = apiKey ?? AppConfig.revenueCatAndroidKey;

  final String _apiKey;
  bool _configured = false;
  bool _busy = false;
  final Map<String, Package> _packages = {};

  /// Whether this build has a RevenueCat key and the SDK is running.
  bool get isAvailable => _configured;

  /// Starts the SDK, for [userId] when someone is signed in (so purchases
  /// never start under an anonymous id). Without a key nothing happens and
  /// [isAvailable] stays false.
  Future<void> configure({String? userId}) async {
    if (_apiKey.isEmpty || _configured) {
      return;
    }
    try {
      final configuration = PurchasesConfiguration(_apiKey)..appUserID = userId;
      await Purchases.configure(configuration);
      _configured = true;
    } on Object {
      _configured = false;
    }
  }

  /// Makes the store customer match the server user: `logIn(<user id>)` for a
  /// signed-in user, `logOut()` when nobody is. A user who was anonymous in
  /// the SDK is merged into the server user by RevenueCat; `logOut` on an
  /// anonymous customer is an error the SDK raises, so it is skipped.
  Future<void> syncUser(String? userId) async {
    if (!_configured) {
      return;
    }
    try {
      if (userId == null) {
        if (!await Purchases.isAnonymous) {
          await Purchases.logOut();
        }
      } else if (await Purchases.appUserID != userId) {
        await Purchases.logIn(userId);
      }
    } on Object {
      // Retried by the next call (the next session change, or before a purchase).
    }
  }

  /// The monthly and yearly packages of the current offering, yearly last.
  Future<List<PaywallPackage>> loadPackages() async {
    _requireAvailable();
    final Offerings offerings;
    try {
      offerings = await Purchases.getOfferings();
    } on PlatformException catch (error) {
      throw BillingException(_failureOf(error));
    }
    final current = offerings.current;
    if (current == null || current.availablePackages.isEmpty) {
      throw const BillingException(BillingFailure.noProducts);
    }
    _packages
      ..clear()
      ..addEntries(
        current.availablePackages.map(
          (package) => MapEntry(package.identifier, package),
        ),
      );
    final result = [
      for (final package in current.availablePackages) _toPaywall(package),
    ]..sort((a, b) => a.period.index.compareTo(b.period.index));
    return result;
  }

  /// Buys the package. [userId] is the signed-in server user: the purchase
  /// only happens when the store customer is that user, so the webhook can
  /// credit the right account.
  Future<PurchaseOutcome> purchase(
    String packageId, {
    required String userId,
  }) async {
    _requireAvailable();
    final package = _packages[packageId];
    if (package == null) {
      throw const BillingException(BillingFailure.productUnavailable);
    }
    return _guarded(() async {
      await _ensureUser(userId);
      try {
        await Purchases.purchase(PurchaseParams.package(package));
        return PurchaseOutcome.purchased;
      } on PlatformException catch (error) {
        switch (PurchasesErrorHelper.getErrorCode(error)) {
          case PurchasesErrorCode.purchaseCancelledError:
            return PurchaseOutcome.cancelled;
          case PurchasesErrorCode.paymentPendingError:
            return PurchaseOutcome.pending;
          case PurchasesErrorCode.productAlreadyPurchasedError:
            // Already owned: the entitlement may simply not have reached the
            // server yet, which the caller finds out by asking the server.
            return PurchaseOutcome.purchased;
          default:
            throw BillingException(_failureOf(error));
        }
      }
    });
  }

  /// Asks the store for the user's past purchases and hands them to
  /// RevenueCat. Premium still comes from the server afterwards.
  Future<void> restore({required String userId}) async {
    _requireAvailable();
    await _guarded(() async {
      await _ensureUser(userId);
      try {
        await Purchases.restorePurchases();
      } on PlatformException catch (error) {
        throw BillingException(_failureOf(error));
      }
    });
  }

  Future<T> _guarded<T>(Future<T> Function() action) async {
    if (_busy) {
      throw const BillingException(BillingFailure.busy);
    }
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  Future<void> _ensureUser(String userId) async {
    try {
      if (await Purchases.appUserID != userId) {
        await Purchases.logIn(userId);
      }
    } on PlatformException catch (error) {
      final failure = _failureOf(error);
      throw BillingException(
        failure == BillingFailure.network
            ? failure
            : BillingFailure.accountLink,
      );
    }
  }

  void _requireAvailable() {
    if (!_configured) {
      throw const BillingException(BillingFailure.unavailable);
    }
  }

  PaywallPackage _toPaywall(Package package) {
    final product = package.storeProduct;
    final option = product.defaultOption;
    final trial =
        option?.freePhase != null || product.introductoryPrice != null;
    final period = switch (package.packageType) {
      PackageType.monthly => PaywallPeriod.monthly,
      PackageType.annual => PaywallPeriod.yearly,
      _ => PaywallPeriod.other,
    };
    return PaywallPackage(
      id: package.identifier,
      period: period,
      priceText: product.priceString,
      hasTrial: trial,
      title: product.title,
    );
  }

  BillingFailure _failureOf(PlatformException error) {
    switch (PurchasesErrorHelper.getErrorCode(error)) {
      case PurchasesErrorCode.networkError:
      case PurchasesErrorCode.unknownBackendError:
      case PurchasesErrorCode.unexpectedBackendResponseError:
        return BillingFailure.network;
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
      case PurchasesErrorCode.purchaseInvalidError:
      case PurchasesErrorCode.ineligibleError:
        return BillingFailure.productUnavailable;
      case PurchasesErrorCode.purchaseNotAllowedError:
      case PurchasesErrorCode.storeProblemError:
      case PurchasesErrorCode.insufficientPermissionsError:
        return BillingFailure.notAllowed;
      case PurchasesErrorCode.operationAlreadyInProgressError:
        return BillingFailure.busy;
      case PurchasesErrorCode.configurationError:
      case PurchasesErrorCode.invalidCredentialsError:
        return BillingFailure.unavailable;
      default:
        return BillingFailure.unknown;
    }
  }
}
