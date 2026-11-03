import Foundation

/// The token pair of API.md §2.
struct AuthTokens: Codable, Sendable, Equatable {
    var accessToken: String
    var accessExpiresAt: Date
    var refreshToken: String
    var refreshExpiresAt: Date

    func accessExpires(within margin: TimeInterval, now: Date) -> Bool {
        accessExpiresAt.timeIntervalSince(now) < margin
    }

    func refreshExpired(now: Date) -> Bool {
        refreshExpiresAt <= now
    }
}
