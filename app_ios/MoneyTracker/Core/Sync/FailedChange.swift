/// A local change the server refused for good (`sync_status = failed`), listed under
/// Pengaturan → Sinkronisasi → "Perlu perhatian".
struct FailedChange: Sendable, Equatable, Identifiable {
    var entity: String
    var recordId: String
    /// Human label of the record (account name, transaction note, ...).
    var title: String
    /// Nominal for money entities (transactions, snapshots).
    var amount: Int64?
    /// `code: message` kept from the rejection.
    var error: String
    /// The refused change was a deletion (the row is a tombstone).
    var isDelete: Bool

    var id: String { recordKey(entity, recordId) }
}
