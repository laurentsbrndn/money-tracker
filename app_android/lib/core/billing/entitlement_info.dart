import 'dart:convert';

import 'plan_limits.dart';

/// The server's entitlement as cached from the last pull or from
/// `GET /v1/me/entitlements` (`sync_state.entitlement`), read for display and
/// for the offline tolerance. The server is the only source of premium.
class EntitlementInfo {
  const EntitlementInfo({
    required this.serverPremium,
    required this.premium,
    this.expiresAt,
    this.willRenew = false,
    this.productId,
    this.store,
  });

  /// Nothing cached, or not premium.
  static const EntitlementInfo free = EntitlementInfo(
    serverPremium: false,
    premium: false,
  );

  /// Reads the cached JSON at [now]. Anything missing or unreadable is free.
  factory EntitlementInfo.fromCache(String? json, DateTime now) {
    if (json == null || json.isEmpty) {
      return free;
    }
    try {
      final map = jsonDecode(json) as Map<String, Object?>;
      final expires = map['expires_at'];
      return EntitlementInfo(
        serverPremium: map['premium'] == true,
        premium: PlanLimits.isPremium(json, now),
        expiresAt: expires is String ? DateTime.parse(expires) : null,
        willRenew: map['will_renew'] == true,
        productId: map['product_id'] as String?,
        store: map['store'] as String?,
      );
    } on Object {
      return free;
    }
  }

  /// What the server said when it was last reachable.
  final bool serverPremium;

  /// Whether premium features are open now: the server said premium and
  /// `expires_at` plus the 3-day offline tolerance has not passed.
  final bool premium;

  /// Null for a user who is not premium (and for premium without an end).
  final DateTime? expiresAt;
  final bool willRenew;
  final String? productId;
  final String? store;

  /// Premium only through the offline tolerance: `expires_at` has passed but
  /// the app has not heard from the server since.
  bool isInTolerance(DateTime now) =>
      premium && expiresAt != null && now.isAfter(expiresAt!);
}
