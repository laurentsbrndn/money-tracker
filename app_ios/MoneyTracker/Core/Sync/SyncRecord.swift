import Foundation
import GRDB

/// A locally stored row of a synced table (SYNC_PROTOCOL §5.1): the columns every synced table
/// shares, plus the conversion to and from the whole-row JSON of the wire format
/// (implemented in `EntityCodec.swift`).
protocol SyncRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Identifiable
where ID == String {
    /// The entity name on the wire.
    static var entity: String { get }

    var id: String { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
    var serverVersion: Int64? { get set }
    /// `synced`, `pending`, or `failed`.
    var syncStatus: String { get set }
    var syncError: String? { get set }

    /// The whole row as sent in a push. Server-only and local-only columns are left out.
    var wireJSON: JSONValue { get }

    /// A row as the server delivers it in a pull; `synced` and clean of any local error.
    init(wire: JSONValue, serverVersion: Int64) throws
}
