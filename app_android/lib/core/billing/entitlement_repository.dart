import 'dart:convert';

import '../database/app_database.dart';
import '../network/generated/models/entitlement.dart';
import '../network/generated/money_tracker_api.dart';
import '../sync/pull_applier.dart';
import '../time/timestamp_format.dart';

/// Reads the entitlement from the server and caches it where a pull would
/// (`sync_state.entitlement`). It is the only online call about premium.
class EntitlementRepository {
  const EntitlementRepository({required this._db, required this._api});

  final AppDatabase _db;
  final MoneyTrackerApi _api;

  /// `GET /v1/me/entitlements`, stored for [EntitlementInfo]. Returns whether
  /// the server says premium. Throws the API error (offline, 401, ...).
  Future<bool> refresh() async {
    final entitlement = await _api.billing.getEntitlements();
    await _db.syncStateDao.write(
      entitlementKey,
      jsonEncode(_toCache(entitlement)),
    );
    return entitlement.premium;
  }

  /// The same shape as `meta.entitlement` of a pull.
  Map<String, Object?> _toCache(Entitlement e) => {
    'premium': e.premium,
    'expires_at': e.expiresAt == null ? null : formatTimestamp(e.expiresAt!),
    'will_renew': e.willRenew,
    if (e.productId != null) 'product_id': e.productId,
    if (e.store?.json != null) 'store': e.store!.json,
  };
}
