import Foundation

/// The signed-in user as the app needs it (API.md §2 `user`).
struct SessionUser: Codable, Sendable, Equatable, Identifiable {
    var id: String
    var name: String
    var email: String?
    var emailVerified: Bool
    var hasPassword: Bool
    var providers: [String]

    init(_ user: Components.Schemas.User) {
        id = user.id
        name = user.name
        email = user.email
        emailVerified = user.email_verified
        hasPassword = user.has_password
        providers = user.providers.map(\.rawValue)
    }
}
