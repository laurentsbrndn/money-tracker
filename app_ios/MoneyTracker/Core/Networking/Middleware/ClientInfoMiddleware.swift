import Foundation
import HTTPTypes
import OpenAPIRuntime

extension HTTPField.Name {
    fileprivate static let deviceID = Self("X-Device-ID")!
    fileprivate static let platform = Self("X-Platform")!
    fileprivate static let appVersion = Self("X-App-Version")!
    fileprivate static let deviceName = Self("X-Device-Name")!
    fileprivate static let requestID = Self("X-Request-ID")!
}

/// Adds the client identity headers required on every app request (API.md §1):
/// `X-Device-ID`, `X-Platform`, `X-App-Version`, `X-Request-ID`, and optional `X-Device-Name`.
/// The operations in openapi.yaml do not declare these headers.
struct ClientInfoMiddleware: ClientMiddleware {
    let deviceID: @Sendable () async throws -> String
    let appVersion: String
    let deviceName: String?
    let makeRequestID: @Sendable () -> String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.deviceID] = try await deviceID()
        request.headerFields[.platform] = "ios"
        request.headerFields[.appVersion] = appVersion
        if request.headerFields[.requestID] == nil {
            request.headerFields[.requestID] = makeRequestID()
        }
        if let name = Self.sanitized(deviceName) {
            request.headerFields[.deviceName] = name
        }
        return try await next(request, body, baseURL)
    }

    /// Header values must be printable ASCII; the server accepts at most 100 characters.
    private static func sanitized(_ name: String?) -> String? {
        guard let name else { return nil }
        let ascii = String(name.unicodeScalars.filter { $0.value >= 0x20 && $0.value < 0x7F })
            .trimmingCharacters(in: .whitespaces)
        return ascii.isEmpty ? nil : String(ascii.prefix(100))
    }
}
