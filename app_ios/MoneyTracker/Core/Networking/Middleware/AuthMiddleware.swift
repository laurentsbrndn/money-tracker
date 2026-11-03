import Foundation
import HTTPTypes
import OpenAPIRuntime

extension Data {
    /// Collects a whole body; the sync and auth payloads are small (the server caps push at 1 MB).
    init(collecting body: HTTPBody, upTo limit: Int) async throws {
        self = Data(try await ArraySlice(collecting: body, upTo: limit))
    }
}

/// Adds `Authorization: Bearer` and renews the access token (FRONTEND_IOS §4.2):
/// proactively when it expires within 60 seconds, and once after `401 token_expired`. Every
/// concurrent caller waits for the same refresh (`TokenRefresher` is single-flight).
struct AuthMiddleware: ClientMiddleware {
    let refresher: TokenRefresher

    /// Operations the server serves without a Bearer token (openapi.yaml `security: []`).
    static let publicOperations: Set<String> = [
        "register", "login", "loginWithApple", "loginWithGoogle", "refreshTokens", "logout",
        "forgotPassword", "resetPassword",
    ]

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard !Self.publicOperations.contains(operationID) else {
            return try await next(request, body, baseURL)
        }
        guard let token = try await refresher.validAccessToken() else {
            throw APIError.sessionExpired
        }
        var authorized = request
        authorized.headerFields[.authorization] = "Bearer \(token)"
        do {
            return try await next(authorized, body, baseURL)
        } catch let error as APIError where error.code == "token_expired" {
            guard let renewed = try await refresher.renewAfterRejection(rejectedToken: token) else {
                throw APIError.sessionExpired
            }
            authorized.headerFields[.authorization] = "Bearer \(renewed)"
            return try await next(authorized, body, baseURL)
        }
    }
}
