import '../database/app_database.dart';
import 'entity_stores.dart';
import 'failed_change.dart';
import 'outbox_writer.dart';
import 'sync_remote.dart';

/// The two ways out of "Perlu perhatian" (SYNC_PROTOCOL §8.4): send the stored
/// change again (after the user fixed the cause), or throw it away and take
/// the server's version.
class FailedChangesService {
  const FailedChangesService({
    required this._db,
    required this._stores,
    required this._writer,
    required this._remote,
  });

  final AppDatabase _db;
  final EntityStores _stores;
  final OutboxWriter _writer;
  final SyncRemote _remote;

  /// Queues the record again with a fresh `updated_at`.
  Future<void> retry(FailedChange change) =>
      _writer.write((tx) => tx.requeue(change.entity, change.recordId));

  /// Replaces the local row with the server's, found by a full pull from the
  /// start; if the server has no such row the local one is removed. Does
  /// nothing if the record has been changed again since (it has an outbox
  /// entry then).
  Future<void> discard(FailedChange change) async {
    final queued = await _db.outboxDao.findByRecord(
      change.entity,
      change.recordId,
    );
    if (queued.isNotEmpty) {
      return;
    }
    final store = _stores.of(change.entity);
    var cursor = 0;
    while (true) {
      final page = await _remote.pull(cursor, limit: 1000);
      for (final item in page.changes) {
        if (item.entity == change.entity && item.id == change.recordId) {
          await store.saveFromServer(item.data, item.serverVersion);
          return;
        }
      }
      if (!page.hasMore || page.nextCursor <= cursor) {
        break;
      }
      cursor = page.nextCursor;
    }
    await store.deleteHard(change.recordId);
  }
}
