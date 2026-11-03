import Foundation
import GRDB

/// Stores `Date` as fixed-width RFC 3339 UTC TEXT with milliseconds ("2026-11-02T14:05:00.123Z"),
/// the same format as the sync payload, so text comparison orders chronologically.
extension DatabaseDateEncodingStrategy {
    static let utcMillis = DatabaseDateEncodingStrategy.custom { date in
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}

extension DatabaseDateDecodingStrategy {
    static let utcMillis = DatabaseDateDecodingStrategy.custom { dbValue in
        guard let text = String.fromDatabaseValue(dbValue) else { return nil }
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)
    }
}
