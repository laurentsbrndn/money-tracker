import Foundation

/// A timezone shown in the picker: the IANA identifier and a readable offset.
struct TimezoneOption: Identifiable, Hashable {
    let identifier: String

    var id: String { identifier }

    /// "Asia/Jakarta" → "Jakarta".
    var city: String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier)
            .replacingOccurrences(of: "_", with: " ")
    }

    /// "GMT+7" or "GMT+5:30" (right now).
    var offsetText: String {
        guard let zone = TimeZone(identifier: identifier) else { return "" }
        let seconds = zone.secondsFromGMT()
        let sign = seconds < 0 ? "-" : "+"
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        return "GMT\(sign)\(hours)" + (minutes == 0 ? "" : ":" + String(format: "%02d", minutes))
    }

    /// Indonesia's zones come first (the app's main market).
    static let indonesia: [TimezoneOption] = [
        "Asia/Jakarta", "Asia/Pontianak", "Asia/Makassar", "Asia/Jayapura",
    ].map(TimezoneOption.init)

    static var others: [TimezoneOption] {
        let first = Set(indonesia.map(\.identifier))
        return TimeZone.knownTimeZoneIdentifiers.filter { !first.contains($0) }.sorted()
            .map(TimezoneOption.init)
    }

    /// Case-insensitive match on the identifier or the city.
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return true }
        return identifier.lowercased().replacingOccurrences(of: "_", with: " ").contains(q)
            || identifier.lowercased().contains(q)
    }
}
