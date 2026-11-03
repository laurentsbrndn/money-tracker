import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database_provider.dart';
import '../sync/pull_applier.dart';
import 'plan_limits.dart';

part 'entitlement_provider.g.dart';

/// Whether the free-plan limits are lifted, from the entitlement cached by the
/// last pull. Offline tolerance is applied (`PlanLimits.offlineTolerance`).
/// Fase 3 extends this with purchases; here it only reads the cache.
@riverpod
Stream<bool> isPremium(Ref ref) => ref
    .watch(appDatabaseProvider)
    .syncStateDao
    .watch(entitlementKey)
    .map((json) => PlanLimits.isPremium(json, DateTime.now()));
