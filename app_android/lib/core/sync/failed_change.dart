/// A local change the server refused for good (`sync_status = failed`),
/// listed under Pengaturan → Sinkronisasi → "Perlu perhatian".
class FailedChange {
  const FailedChange({
    required this.entity,
    required this.recordId,
    required this.title,
    required this.error,
    required this.isDelete,
    this.amount,
  });

  final String entity;
  final String recordId;

  /// Human label of the record (account name, transaction note, ...).
  final String title;

  /// Nominal for money entities (transactions, snapshots).
  final int? amount;

  /// `code: message` kept from the rejection.
  final String error;

  /// The refused change was a deletion (the row is a tombstone).
  final bool isDelete;
}
