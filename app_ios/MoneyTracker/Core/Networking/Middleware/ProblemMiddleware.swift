import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Turns every non-2xx response into a thrown `APIError` (API.md §1.2), so callers of the
/// generated client only handle the success case. Sits closest to the transport.
struct ProblemMiddleware: ClientMiddleware {
    private static let maxBodyBytes = 1 << 20

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (response, responseBody) = try await next(request, body, baseURL)
        guard response.status.code >= 400 else { return (response, responseBody) }

        var data = Data()
        if let responseBody {
            data = Data(try await Data(collecting: responseBody, upTo: Self.maxBodyBytes))
        }
        if let problem = APIError(problemJSON: data) {
            throw problem
        }
        throw APIError(status: response.status.code, code: "http_\(response.status.code)")
    }
}
