import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  Future<int> enqueue(OutboxCompanion entry) => into(outbox).insert(entry);

  /// Every entry of one record (at most one unsent plus the in-flight ones).
  Future<List<OutboxEntry>> findByRecord(String entity, String recordId) =>
      (select(outbox)..where(
            (t) => t.entity.equals(entity) & t.recordId.equals(recordId),
          ))
          .get();

  Future<List<OutboxEntry>> all() =>
      (select(outbox)..orderBy([(t) => OrderingTerm.asc(t.seq)])).get();

  Future<OutboxEntry?> findBySeq(int seq) =>
      (select(outbox)..where((t) => t.seq.equals(seq))).getSingleOrNull();

  /// `entity:record_id` of every entry, for the pull rule "an outbox entry
  /// means do not overwrite" (SYNC_PROTOCOL §9.4).
  Future<Set<String>> recordKeys() async {
    final rows = await all();
    return {for (final row in rows) '${row.entity}:${row.recordId}'};
  }

  Future<void> markInFlight(List<int> seqs, String batchId) =>
      (update(outbox)..where((t) => t.seq.isIn(seqs))).write(
        OutboxCompanion(batchId: Value(batchId)),
      );

  /// Back to "not sent", counting a failed attempt.
  Future<void> scheduleRetry(
    int seq, {
    required int attempts,
    required DateTime nextAttemptAt,
    required String lastError,
  }) => (update(outbox)..where((t) => t.seq.equals(seq))).write(
    OutboxCompanion(
      batchId: const Value(null),
      attempts: Value(attempts),
      nextAttemptAt: Value(nextAttemptAt),
      lastError: Value(lastError),
    ),
  );

  Future<void> overwrite(
    int seq, {
    required String op,
    required String payload,
    required DateTime updatedAt,
  }) => (update(outbox)..where((t) => t.seq.equals(seq))).write(
    OutboxCompanion(
      op: Value(op),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
      attempts: const Value(0),
      nextAttemptAt: const Value(null),
      lastError: const Value(null),
    ),
  );

  Future<int> countAll() async {
    final count = outbox.seq.count();
    final row = await (selectOnly(outbox)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Soonest `next_attempt_at` among unsent entries, if any.
  Future<DateTime?> earliestRetryAt() async {
    final minimum = outbox.nextAttemptAt.min();
    final row =
        await (selectOnly(outbox)
              ..addColumns([minimum])
              ..where(outbox.batchId.isNull()))
            .getSingle();
    return row.read(minimum);
  }

  Stream<int> watchPendingCount() {
    final count = outbox.seq.count();
    return (selectOnly(
      outbox,
    )..addColumns([count])).map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<void> remove(int seq) =>
      (delete(outbox)..where((t) => t.seq.equals(seq))).go();
}
