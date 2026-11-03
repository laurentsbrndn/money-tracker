import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import '../database/app_database_provider.dart';
import '../network/api_client_provider.dart';
import '../sync/failed_changes_source.dart';
import '../sync/sync_providers.dart';
import 'billing_service.dart';
import 'entitlement_provider.dart';
import 'entitlement_repository.dart';

part 'billing_providers.g.dart';

@Riverpod(keepAlive: true)
BillingService billingService(Ref ref) => BillingService();

@Riverpod(keepAlive: true)
EntitlementRepository entitlementRepository(Ref ref) => EntitlementRepository(
  db: ref.watch(appDatabaseProvider),
  api: ref.watch(apiClientProvider),
);

/// Keeps the store customer equal to the signed-in server user: `logIn` after
/// a login or registration, `logOut` after a logout or account switch
/// (FRONTEND_FLUTTER §4.4). Watched once from the app root.
@Riverpod(keepAlive: true)
void billingSessionSync(Ref ref) {
  final service = ref.watch(billingServiceProvider);
  ref.listen(sessionControllerProvider, (previous, next) {
    if (next.status == SessionStatus.loading) {
      return;
    }
    unawaited(service.syncUser(next.user?.id));
  }, fireImmediately: true);
}

/// Error codes of a refused push that only a premium plan can fix.
const List<String> _premiumRejections = ['plan_limit', 'premium_required'];

/// When the server starts reporting premium, the changes it refused for the
/// plan (`plan_limit`, `premium_required`) are sent again automatically,
/// instead of waiting for the user to fix them under "Perlu perhatian". It
/// also covers a purchase made on another device.
@Riverpod(keepAlive: true)
void premiumRetryCoordinator(Ref ref) {
  ref.listen(isPremiumProvider, (previous, next) {
    final was = previous?.value ?? false;
    if ((next.value ?? false) && !was) {
      unawaited(_retryRejected(ref));
    }
  }, fireImmediately: true);
}

Future<void> _retryRejected(Ref ref) async {
  final changes = await FailedChangesSource(ref.read(appDatabaseProvider))
      .load();
  final service = ref.read(failedChangesServiceProvider);
  for (final change in changes) {
    if (_premiumRejections.any(change.error.startsWith)) {
      await service.retry(change);
    }
  }
}
