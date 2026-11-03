import Foundation

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
