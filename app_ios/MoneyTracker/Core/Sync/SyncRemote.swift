import Foundation

/// The two sync endpoints, spoken as plain JSON: rows are already whole-row documents (see
/// `EntityCodec`), so no typed request models are needed.
struct SyncRemote: Sendable {
    let api: RawAPI

    /// `POST /v1/sync/push`. `changes` are the wire entries in `seq` order.
    func push(batchId: String, changes: [JSONValue]) async throws -> [PushResultInfo] {
        let body = try JSONValue.object(["changes": .array(changes)]).jsonString()
        let data = try await api.send(
            method: .post, path: "/v1/sync/push", operationID: "syncPush",
            headers: [(.idempotencyKey, batchId)], body: Data(body.utf8))
        let json = try JSONDecoder().decode(JSONValue.self, from: data)
        guard let results = json["results"]?.arrayValue else {
            throw WireFormatError(message: "push response")
        }
        return try results.map(PushResultInfo.init(json:))
    }

    /// `GET /v1/sync/pull`.
    func pull(since: Int64, limit: Int = 500) async throws -> PullPage {
        let data = try await api.send(
            method: .get, path: "/v1/sync/pull", query: "since=\(since)&limit=\(limit)",
            operationID: "syncPull")
        return try PullPage(json: try JSONDecoder().decode(JSONValue.self, from: data))
    }
}
