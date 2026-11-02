import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.attachedDatabase);

  Future<int> enqueue(OutboxCompanion entry) => into(outbox).insert(entry);

  Future<OutboxEntry?> findByRecord(String entity, String recordId) =>
      (select(outbox)..where(
            (t) => t.entity.equals(entity) & t.recordId.equals(recordId),
          ))
          .getSingleOrNull();

  /// Entries ready to send (`next_attempt_at` unset or due), oldest first.
  Future<List<OutboxEntry>> nextBatch(DateTime now, {int limit = 100}) =>
      (select(outbox)
            ..where(
              (t) =>
                  t.nextAttemptAt.isNull() |
                  t.nextAttemptAt.isSmallerOrEqualValue(now),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.seq)])
            ..limit(limit))
          .get();

  Stream<int> watchPendingCount() {
    final count = outbox.seq.count();
    return (selectOnly(
      outbox,
    )..addColumns([count])).map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<void> remove(int seq) =>
      (delete(outbox)..where((t) => t.seq.equals(seq))).go();
}
