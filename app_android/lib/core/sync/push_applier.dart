import '../database/app_database.dart';
import 'entity_stores.dart';
import 'logic/outbox_item.dart';
import 'logic/push_batch_selector.dart';
import 'logic/push_result_planner.dart';
import 'logic/repair_planner.dart';
import 'logic/wire_models.dart';

/// Applies the server's answer to a push to the local database
/// (SYNC_PROTOCOL §8.4), in one transaction.
class PushApplier {
  const PushApplier(this._db, this._stores);

  final AppDatabase _db;
  final EntityStores _stores;

  /// Returns the records that need a repair pull (see [staleRepairKeys]);
  /// [cursor] is the local pull cursor.
  Future<Set<String>> apply(
    PushBatch batch,
    List<PushResultInfo> results,
    DateTime now,
    int cursor,
  ) {
    final byRecord = {
      for (final result in results) '${result.entity}:${result.id}': result,
    };
    return _db.transaction(() async {
      final answered = <(OutboxItem, PushAction)>[];
      for (final item in batch.items) {
        final action = planPushResult(
          item,
          byRecord['${item.entity}:${item.recordId}'],
          now,
        );
        await _applyAction(item.seq, item, action);
        answered.add((item, action));
      }
      return staleRepairKeys(answered, cursor);
    });
  }

  /// A whole-request failure that counts against the entries (4xx other than
  /// 401): they leave "in flight" and back off.
  Future<void> applyBatchFailure(
    PushBatch batch,
    String message,
    DateTime now,
  ) => _db.transaction(() async {
    for (final item in batch.items) {
      await _applyAction(item.seq, item, planBatchFailure(item, now, message));
    }
  });

  Future<void> _applyAction(int seq, OutboxItem item, PushAction action) async {
    final store = _stores.maybeOf(item.entity);
    switch (action) {
      case RemoveApplied(:final serverVersion):
        await _db.outboxDao.remove(seq);
        if (store != null &&
            rowUnchangedSinceSend(
              await store.updatedAtOf(item.recordId),
              item.updatedAt,
            )) {
          await store.markSynced(item.recordId, serverVersion);
        }
      case RemoveStale():
        await _db.outboxDao.remove(seq);
      case RetryLater(:final attempts, :final nextAttemptAt, :final message):
        await _db.outboxDao.scheduleRetry(
          seq,
          attempts: attempts,
          nextAttemptAt: nextAttemptAt,
          lastError: message,
        );
      case FailTerminal(:final code, :final message):
        await _db.outboxDao.remove(seq);
        if (store != null &&
            rowUnchangedSinceSend(
              await store.updatedAtOf(item.recordId),
              item.updatedAt,
            )) {
          await store.markFailed(item.recordId, '$code: $message');
        }
    }
  }
}
