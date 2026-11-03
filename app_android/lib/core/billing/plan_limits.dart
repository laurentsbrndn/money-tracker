import 'dart:convert';

/// Free-plan limits (BUSINESS_RULES §7). The server enforces them on push;
/// the client checks first so the user is told before saving.
abstract final class PlanLimits {
  static const int maxFreeAccounts = 4;
  static const int maxFreeCustomCategories = 5;

  /// Premium is trusted until `expires_at` plus this offline grace period.
  static const Duration offlineTolerance = Duration(days: 3);

  /// Reads the cached `meta.entitlement` JSON of `sync_state.entitlement`.
  /// Anything missing or unreadable counts as free.
  static bool isPremium(String? entitlementJson, DateTime now) {
    if (entitlementJson == null || entitlementJson.isEmpty) {
      return false;
    }
    try {
      final map = jsonDecode(entitlementJson) as Map<String, Object?>;
      if (map['premium'] != true) {
        return false;
      }
      final expires = map['expires_at'];
      if (expires is! String) {
        return true;
      }
      return !now.isAfter(DateTime.parse(expires).add(offlineTolerance));
    } on Object {
      return false;
    }
  }
}

/// A free-plan limit was reached (`SYNC_PROTOCOL` §8.3 `plan_limit`, checked
/// locally first).
class PlanLimitException implements Exception {
  const PlanLimitException(this.kind);

  final PlanLimitKind kind;
}

enum PlanLimitKind { accounts, categories }
