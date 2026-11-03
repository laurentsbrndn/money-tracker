import Foundation

/// Tokens, the signed-in user, and the `needs_login` flag, all in the Keychain
/// (FRONTEND_IOS §4.2).
struct TokenStore: Sendable {
    private let keychain: KeychainStore

    private static let tokensKey = "auth.tokens"
    private static let userKey = "auth.user"
    private static let needsLoginKey = "auth.needs_login"

    init(keychain: KeychainStore) {
        self.keychain = keychain
    }

    func readTokens() throws -> AuthTokens? { try read(AuthTokens.self, Self.tokensKey) }

    func writeTokens(_ tokens: AuthTokens) throws { try write(tokens, Self.tokensKey) }

    func readUser() throws -> SessionUser? { try read(SessionUser.self, Self.userKey) }

    func writeUser(_ user: SessionUser) throws { try write(user, Self.userKey) }

    func readNeedsLogin() throws -> Bool {
        try keychain.read(Self.needsLoginKey) == Data([1])
    }

    func writeNeedsLogin(_ value: Bool) throws {
        if value {
            try keychain.write(Self.needsLoginKey, Data([1]))
        } else {
            try keychain.delete(Self.needsLoginKey)
        }
    }

    func clear() throws { try keychain.deleteAll() }

    private func read<T: Decodable>(_ type: T.Type, _ key: String) throws -> T? {
        guard let data = try keychain.read(key) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, _ key: String) throws {
        try keychain.write(key, try JSONEncoder().encode(value))
    }
}
