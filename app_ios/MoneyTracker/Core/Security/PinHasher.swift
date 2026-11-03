import CommonCrypto
import Foundation
import Security

/// A salted, stretched PIN hash. The raw PIN is never stored.
struct PinHash: Sendable, Equatable {
    /// Base64 of 16 random bytes.
    var salt: String
    /// Base64 of the PBKDF2-HMAC-SHA256 output.
    var hash: String
    var iterations: Int
}

enum PinHasher {
    /// PBKDF2 rounds used for new hashes; kept with each hash so it can be raised later without
    /// invalidating existing PINs. Never below 100.000.
    static let iterations = 200_000

    /// Number of digits of a PIN (APP_FLOWS Flow 12).
    static let pinLength = 6

    static func isValidFormat(_ pin: String) -> Bool {
        pin.utf8.count == pinLength && pin.utf8.allSatisfy { (48...57).contains($0) }
    }

    /// Hashes `pin` with a fresh random salt, off the main thread.
    static func create(_ pin: String) async throws -> PinHash {
        var salt = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt) == errSecSuccess else {
            throw HashError.randomFailed
        }
        let fixedSalt = salt
        let count = iterations
        return try await Task.detached(priority: .userInitiated) {
            let derived = try derive(pin, salt: fixedSalt, iterations: count)
            return PinHash(
                salt: Data(fixedSalt).base64EncodedString(),
                hash: Data(derived).base64EncodedString(), iterations: count)
        }.value
    }

    /// Whether `pin` matches `stored`, off the main thread.
    static func verify(_ pin: String, against stored: PinHash) async -> Bool {
        guard let salt = Data(base64Encoded: stored.salt),
            let expected = Data(base64Encoded: stored.hash), stored.iterations >= 1
        else { return false }
        return await Task.detached(priority: .userInitiated) {
            guard let derived = try? derive(pin, salt: [UInt8](salt), iterations: stored.iterations)
            else { return false }
            return constantTimeEquals(derived, [UInt8](expected))
        }.value
    }

    enum HashError: Error {
        case randomFailed
        case derivationFailed(Int32)
    }

    private static func derive(_ pin: String, salt: [UInt8], iterations: Int) throws -> [UInt8] {
        let password = Array(pin.utf8)
        var output = [UInt8](repeating: 0, count: 32)
        let status = password.withUnsafeBufferPointer { passwordBuffer in
            passwordBuffer.withMemoryRebound(to: Int8.self) { chars in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2), chars.baseAddress, chars.count, salt, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations), &output,
                    output.count)
            }
        }
        guard status == Int32(kCCSuccess) else { throw HashError.derivationFailed(status) }
        return output
    }

    /// Compares without returning early on the first differing byte.
    static func constantTimeEquals(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }
}
