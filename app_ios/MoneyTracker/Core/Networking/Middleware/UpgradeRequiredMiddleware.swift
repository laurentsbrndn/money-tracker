import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Reports `426 upgrade_required` (API.md §1.1) so the app can show the update screen, then
/// rethrows. Sits outside `ProblemMiddleware`, which produces the error it looks for.
struct UpgradeRequiredMiddleware: ClientMiddleware {
    let onUpgradeRequired: @Sendable () async -> Void

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        do {
            return try await next(request, body, baseURL)
        } catch let error as APIError where error.code == "upgrade_required" {
            await onUpgradeRequired()
            throw error
        }
    }
}
