import 'package:flutter/services.dart';

/// Opens a web address or a store page in the system (the app has no web view
/// package). Backed by a tiny method channel in `MainActivity`.
abstract final class ExternalLinks {
  static const MethodChannel _channel = MethodChannel(
    'com.brandon.moneytracker/links',
  );

  /// Returns false when nothing on the device can open [url].
  static Future<bool> open(String url) async {
    try {
      return await _channel.invokeMethod<bool>('open', url) ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// The Google Play page that manages [productId] of this app.
  static String manageSubscriptionUrl({
    required String packageName,
    String? productId,
  }) =>
      'https://play.google.com/store/account/subscriptions'
      '?package=$packageName${productId == null ? '' : '&sku=$productId'}';
}
