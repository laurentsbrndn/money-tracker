import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Sends whole-row JSON through the same middleware chain as the generated client (client
/// headers, auth refresh, problem decoding). Sync rows are `JSONValue` documents built by
/// `EntityCodec`, not generated types (FRONTEND_IOS §4.3), so push and pull go through here.
struct RawAPI: Sendable {
    let baseURL: URL
    let transport: any ClientTransport
    let middlewares: [any ClientMiddleware]

    /// `query` is the already-encoded query string without `?`.
    func send(
        method: HTTPRequest.Method,
        path: String,
        query: String? = nil,
        operationID: String,
        headers: [(HTTPField.Name, String)] = [],
        body: Data? = nil
    ) async throws -> Data {
        var request = HTTPRequest(
            method: method, scheme: nil, authority: nil,
            path: query.map { "\(path)?\($0)" } ?? path)
        request.headerFields[.accept] = "application/json"
        if body != nil { request.headerFields[.contentType] = "application/json" }
        for (name, value) in headers { request.headerFields[name] = value }

        let transport = self.transport
        var chain:
            @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) =
                { request, body, url in
                    try await transport.send(
                        request, body: body, baseURL: url, operationID: operationID)
                }
        for middleware in middlewares.reversed() {
            let inner = chain
            chain = { request, body, url in
                try await middleware.intercept(
                    request, body: body, baseURL: url, operationID: operationID, next: inner)
            }
        }
        let (_, responseBody) = try await chain(request, body.map { HTTPBody($0) }, baseURL)
        guard let responseBody else { return Data() }
        return try await Data(collecting: responseBody, upTo: 16 << 20)
    }
}

extension HTTPField.Name {
    static let idempotencyKey = Self("Idempotency-Key")!
}
