import Foundation
import OpenAPIRuntime

/// An `application/problem+json` error (API.md §1.2). `code` stays a plain string so codes
/// the server adds later do not break parsing.
struct APIError: Error, Sendable, Equatable, CustomStringConvertible {
    struct FieldError: Sendable, Equatable {
        let field: String
        let message: String
    }

    let status: Int
    let code: String
    let title: String
    let detail: String?
    let fields: [FieldError]
    let retryAfterSeconds: Int?
    let requestId: String?

    init(
        status: Int, code: String, title: String = "", detail: String? = nil,
        fields: [FieldError] = [], retryAfterSeconds: Int? = nil, requestId: String? = nil
    ) {
        self.status = status
        self.code = code
        self.title = title
        self.detail = detail
        self.fields = fields
        self.retryAfterSeconds = retryAfterSeconds
        self.requestId = requestId
    }

    /// The access token cannot be renewed (no tokens, or the refresh token was refused).
    static let sessionExpired = APIError(status: 401, code: "session_expired")

    /// Returns nil when `data` is not a problem document.
    init?(problemJSON data: Data) {
        guard let problem = try? JSONDecoder().decode(Problem.self, from: data) else {
            return nil
        }
        self.status = problem.status
        self.code = problem.code
        self.title = problem.title ?? ""
        self.detail = problem.detail
        self.fields = (problem.fields ?? []).map {
            FieldError(field: $0.field ?? "", message: $0.message ?? "")
        }
        self.retryAfterSeconds = problem.retryAfterSeconds
        self.requestId = problem.requestId
    }

    var description: String {
        "APIError(\(status) \(code): \(detail ?? title))"
    }

    private struct Problem: Decodable {
        struct Field: Decodable {
            let field: String?
            let message: String?
        }

        let title: String?
        let status: Int
        let detail: String?
        let code: String
        let fields: [Field]?
        let retryAfterSeconds: Int?
        let requestId: String?

        enum CodingKeys: String, CodingKey {
            case title, status, detail, code, fields
            case retryAfterSeconds = "retry_after_seconds"
            case requestId = "request_id"
        }
    }
}

/// How a failed call should be treated, whatever raised it: the generated client wraps errors in
/// `ClientError`, and `URLSession` failures arrive as `URLError`.
enum APIFailure: Sendable {
    /// The server answered with a problem document.
    case api(APIError)
    /// The request never got through (no connection, timeout, DNS).
    case unreachable
    case other

    init(_ error: any Error) {
        if let api = Self.findAPIError(error) {
            self = .api(api)
        } else if Self.isUnreachable(error) {
            self = .unreachable
        } else {
            self = .other
        }
    }

    static func findAPIError(_ error: any Error) -> APIError? {
        if let api = error as? APIError { return api }
        if let client = error as? ClientError { return findAPIError(client.underlyingError) }
        return nil
    }

    private static func isUnreachable(_ error: any Error) -> Bool {
        if let client = error as? ClientError { return isUnreachable(client.underlyingError) }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
            .cannotFindHost, .dnsLookupFailed, .timedOut, .internationalRoamingOff,
            .dataNotAllowed, .secureConnectionFailed:
            return true
        default:
            return false
        }
    }
}
