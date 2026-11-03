import GRDB

/// Stores a `CivilDate` as `YYYY-MM-DD` TEXT.
extension CivilDate: DatabaseValueConvertible {
    var databaseValue: DatabaseValue { description.databaseValue }

    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CivilDate? {
        String.fromDatabaseValue(dbValue).flatMap { try? CivilDate(parsing: $0) }
    }
}
