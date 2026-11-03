import Foundation
import GRDB

/// Stores `Date` as fixed-width RFC 3339 UTC TEXT with milliseconds ("2026-11-02T14:05:00.123Z"),
/// the same format as the sync payload, so text comparison orders chronologically.
extension DatabaseDateEncodingStrategy {
    static let utcMillis = DatabaseDateEncodingStrategy.custom { TimestampFormat.format($0) }
}

extension DatabaseDateDecodingStrategy {
    static let utcMillis = DatabaseDateDecodingStrategy.custom { dbValue in
        String.fromDatabaseValue(dbValue).flatMap { TimestampFormat.parse($0) }
    }
}
