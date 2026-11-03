import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database_provider.dart';
import '../sync/pull_applier.dart';
import 'entitlement_info.dart';
import 'plan_limits.dart';

part 'entitlement_provider.g.dart';

/// Whether the free-plan limits are lifted, from the entitlement the server
/// reported (last pull or `GET /v1/me/entitlements`). Offline tolerance is
/// applied (`PlanLimits.offlineTolerance`). The store SDK never feeds this:
/// the server is the only source of premium (FRONTEND_FLUTTER §4.4).
@riverpod
Stream<bool> isPremium(Ref ref) => ref
    .watch(appDatabaseProvider)
    .syncStateDao
    .watch(entitlementKey)
    .map((json) => PlanLimits.isPremium(json, DateTime.now()));

/// The cached entitlement for display (renewal date, plan, tolerance).
@riverpod
Stream<EntitlementInfo> entitlementInfo(Ref ref) => ref
    .watch(appDatabaseProvider)
    .syncStateDao
    .watch(entitlementKey)
    .map((json) => EntitlementInfo.fromCache(json, DateTime.now()));
