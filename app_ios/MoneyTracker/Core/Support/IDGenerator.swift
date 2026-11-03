import CryptoKit
import Foundation

/// Entity IDs (SYNC_PROTOCOL §3): UUIDv7 from the client, UUIDv5 for deterministic IDs.
/// All IDs are lowercase with hyphens.
struct IDGenerator: Sendable {
    static let nsBudgetGoal = UUID(uuidString: "2c985cd5-0cd0-404d-bcea-4cca9c3f7437")!
    static let nsRecurringOccurrence = UUID(uuidString: "151a0b48-a293-4aba-95a8-6562233ef7af")!

    /// A new UUIDv7: 48-bit Unix millisecond timestamp followed by random bits.
    func newID(at date: Date = Date()) -> String {
        let millis = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<6 {
            bytes[i] = UInt8((millis >> UInt64(8 * (5 - i))) & 0xFF)
        }
        var random = SystemRandomNumberGenerator()
        for i in 6..<16 {
            bytes[i] = UInt8.random(in: 0...255, using: &random)
        }
        return Self.string(bytes, version: 7)
    }

    /// UUIDv5 of `NS_BUDGET_GOAL` and the string `user_id|YYYY-MM`.
    func budgetGoalID(userID: String, month: String) -> String {
        Self.v5(namespace: Self.nsBudgetGoal, name: "\(userID.lowercased())|\(month)")
    }

    /// UUIDv5 of `NS_RECURRING_OCCURRENCE` and the string `rule_id|YYYY-MM-DD`.
    func recurringOccurrenceID(ruleID: String, date: CivilDate) -> String {
        Self.v5(namespace: Self.nsRecurringOccurrence, name: "\(ruleID.lowercased())|\(date)")
    }

    static func v5(namespace: UUID, name: String) -> String {
        var input = withUnsafeBytes(of: namespace.uuid) { Array($0) }
        input.append(contentsOf: Array(name.utf8))
        let digest = Array(Insecure.SHA1.hash(data: input).prefix(16))
        return string(digest, version: 5)
    }

    private static func string(_ bytes: [UInt8], version: UInt8) -> String {
        var b = bytes
        b[6] = (b[6] & 0x0F) | (version << 4)
        b[8] = (b[8] & 0x3F) | 0x80
        let hex = b.map { String(format: "%02x", $0) }
        return hex[0..<4].joined() + "-" + hex[4..<6].joined() + "-" + hex[6..<8].joined()
            + "-" + hex[8..<10].joined() + "-" + hex[10..<16].joined()
    }
}
