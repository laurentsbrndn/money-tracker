/// The part of an outbox row the pure sync rules need. Database access lives
/// elsewhere so these rules can be checked without Drift or the network.
class OutboxItem {
  const OutboxItem({
    required this.seq,
    required this.entity,
    required this.recordId,
    required this.op,
    required this.updatedAt,
    this.batchId,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  final int seq;
  final String entity;
  final String recordId;

  /// `upsert` or `delete`.
  final String op;
  final DateTime updatedAt;

  /// Non-null while the entry is in flight (SYNC_PROTOCOL §5.2.1).
  final String? batchId;
  final int attempts;
  final DateTime? nextAttemptAt;

  bool get inFlight => batchId != null;
}

String recordKey(String entity, String recordId) => '$entity:$recordId';
