import Foundation

private let indonesian = Locale(identifier: "id_ID")

extension CivilDate {
    /// Noon on this date in `zone`; a stable instant for `DatePicker` and formatters.
    func date(in zone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
            ?? Date(timeIntervalSince1970: 0)
    }

    /// "3 Nov 2026".
    var shortText: String {
        date().formatted(.dateTime.day().month(.abbreviated).year().locale(indonesian))
    }

    /// "Selasa, 3 November 2026".
    var longText: String {
        date().formatted(
            .dateTime.weekday(.wide).day().month(.wide).year().locale(indonesian))
    }
}

extension YearMonth {
    /// "November 2026".
    var titleText: String {
        first.date().formatted(.dateTime.month(.wide).year().locale(indonesian))
    }
}
