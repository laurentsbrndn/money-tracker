import 'outbox_item.dart';

/// Entries chosen for one push request.
class PushBatch {
  const PushBatch({
    required this.batchId,
    required this.items,
    required this.isResend,
  });

  /// Used as the `Idempotency-Key`.
  final String batchId;
  final List<OutboxItem> items;

  /// True when the batch was already sent before and is sent again unchanged.
  final bool isResend;
}

const int maxPushBatchSize = 100;

/// Picks the next batch from [all] (SYNC_PROTOCOL §5.2.1 and §7).
///
/// An in-flight batch is re-sent first, exactly as it was. Otherwise up to
/// [limit] due entries (no backoff pending), oldest `seq` first, get a fresh
/// id from [newBatchId]. Returns null when nothing is ready. The caller must
/// persist the new `batch_id` before sending.
PushBatch? selectPushBatch(
  List<OutboxItem> all,
  DateTime now,
  String Function() newBatchId, {
  int limit = maxPushBatchSize,
}) {
  final bySeq = [...all]..sort((a, b) => a.seq.compareTo(b.seq));

  for (final item in bySeq) {
    final id = item.batchId;
    if (id != null) {
      final items = [
        for (final candidate in bySeq)
          if (candidate.batchId == id) candidate,
      ];
      return PushBatch(batchId: id, items: items, isResend: true);
    }
  }

  final due = <OutboxItem>[];
  for (final item in bySeq) {
    final next = item.nextAttemptAt;
    if (next == null || !next.isAfter(now)) {
      due.add(item);
      if (due.length == limit) {
        break;
      }
    }
  }
  if (due.isEmpty) {
    return null;
  }
  return PushBatch(batchId: newBatchId(), items: due, isResend: false);
}
