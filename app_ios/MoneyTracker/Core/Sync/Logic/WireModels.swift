import Foundation

// Plain value types for the sync wire format, parsed from decoded JSON so they can be used
// without the generated client.

struct WireFormatError: Error, Sendable, Equatable {
    let message: String
}

struct PushResultInfo: Sendable, Equatable {
    var entity: String
    var id: String
    /// `applied`, `stale`, or `rejected`.
    var status: String
    var serverVersion: Int64?
    var errorCode: String?
    var errorMessage: String?
    var retryable = false

    init(
        entity: String, id: String, status: String, serverVersion: Int64? = nil,
        errorCode: String? = nil, errorMessage: String? = nil, retryable: Bool = false
    ) {
        self.entity = entity
        self.id = id
        self.status = status
        self.serverVersion = serverVersion
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.retryable = retryable
    }

    init(json: JSONValue) throws {
        guard let entity = json["entity"]?.stringValue, let id = json["id"]?.stringValue,
            let status = json["status"]?.stringValue
        else { throw WireFormatError(message: "push result") }
        let error = json["error"]
        self.init(
            entity: entity, id: id, status: status, serverVersion: json["server_version"]?.intValue,
            errorCode: error?["code"]?.stringValue, errorMessage: error?["message"]?.stringValue,
            retryable: error?["retryable"]?.boolValue ?? false)
    }
}

struct PullChangeItem: Sendable, Equatable {
    var entity: String
    var id: String
    var serverVersion: Int64
    /// The whole row, tombstones included.
    var data: JSONValue

    init(entity: String, id: String, serverVersion: Int64, data: JSONValue) {
        self.entity = entity
        self.id = id
        self.serverVersion = serverVersion
        self.data = data
    }

    init(json: JSONValue) throws {
        guard let entity = json["entity"]?.stringValue, let id = json["id"]?.stringValue,
            let version = json["server_version"]?.intValue, let data = json["data"]
        else { throw WireFormatError(message: "pull change") }
        self.init(entity: entity, id: id, serverVersion: version, data: data)
    }
}

struct PullPage: Sendable, Equatable {
    var changes: [PullChangeItem]
    var nextCursor: Int64
    var hasMore: Bool
    var entitlement: JSONValue?

    init(changes: [PullChangeItem], nextCursor: Int64, hasMore: Bool, entitlement: JSONValue? = nil)
    {
        self.changes = changes
        self.nextCursor = nextCursor
        self.hasMore = hasMore
        self.entitlement = entitlement
    }

    init(json: JSONValue) throws {
        guard let raw = json["changes"]?.arrayValue, let next = json["next_cursor"]?.intValue,
            let more = json["has_more"]?.boolValue
        else { throw WireFormatError(message: "pull page") }
        let entitlement = json["meta"]?["entitlement"]
        self.init(
            changes: try raw.map(PullChangeItem.init(json:)), nextCursor: next, hasMore: more,
            entitlement: entitlement?.objectValue == nil ? nil : entitlement)
    }
}
