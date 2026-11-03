import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import '../database/app_database_provider.dart';
import 'connectivity.dart';
import 'failed_change.dart';
import 'failed_changes_source.dart';
import 'sync_engine.dart';

part 'sync_status_provider.g.dart';

/// What the `SyncBadge` shows (FRONTEND_FLUTTER §4.3).
enum SyncBadgeKind { synced, syncing, pending, offline, needsLogin, attention }

class SyncBadgeState {
  const SyncBadgeState(this.kind, [this.count = 0]);

  final SyncBadgeKind kind;

  /// Pending entries for [SyncBadgeKind.pending], failed records for
  /// [SyncBadgeKind.attention].
  final int count;
}

@riverpod
Stream<int> pendingChangeCount(Ref ref) =>
    ref.watch(appDatabaseProvider).outboxDao.watchPendingCount();

@riverpod
Stream<List<FailedChange>> failedChanges(Ref ref) =>
    FailedChangesSource(ref.watch(appDatabaseProvider)).watch();

@riverpod
Stream<String?> lastSyncAt(Ref ref) =>
    ref.watch(appDatabaseProvider).syncStateDao.watch(lastSyncAtKey);

@riverpod
SyncBadgeState syncStatus(Ref ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session.status == SessionStatus.needsLogin) {
    return const SyncBadgeState(SyncBadgeKind.needsLogin);
  }
  final failed = ref.watch(failedChangesProvider).value?.length ?? 0;
  if (failed > 0) {
    return SyncBadgeState(SyncBadgeKind.attention, failed);
  }
  if (ref.watch(isOnlineProvider).value == false) {
    return const SyncBadgeState(SyncBadgeKind.offline);
  }
  final pending = ref.watch(pendingChangeCountProvider).value ?? 0;
  if (pending > 0) {
    return SyncBadgeState(SyncBadgeKind.pending, pending);
  }
  if (ref.watch(syncEngineProvider).running) {
    return const SyncBadgeState(SyncBadgeKind.syncing);
  }
  return const SyncBadgeState(SyncBadgeKind.synced);
}
