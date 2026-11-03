import Foundation
import GRDB

/// Owns the local `DatabasePool` (WAL). The file lives in Application Support under a directory
/// with Data Protection `completeUntilFirstUserAuthentication`, so background tasks can still
/// read it after the first unlock. No SQLCipher on iOS.
final class AppDatabase: Sendable {
    let pool: DatabasePool

    private let directory: URL

    private static let fileName = "money_tracker.sqlite"

    init(directory: URL) throws {
        try Self.prepareDirectory(directory)
        var configuration = Configuration()
        configuration.label = "MoneyTracker"
        let pool = try DatabasePool(
            path: directory.appending(path: Self.fileName).path, configuration: configuration)
        try DatabaseMigrations.makeMigrator().migrate(pool)
        self.pool = pool
        self.directory = directory
    }

    /// Opens the database in `Application Support/Database`.
    static func openDefault() throws -> AppDatabase {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true)
        return try AppDatabase(
            directory: base.appending(path: "Database", directoryHint: .isDirectory))
    }

    /// Logout: closes the pool and deletes the database files (main, `-wal`, `-shm`).
    func closeAndDelete() throws {
        try pool.close()
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let url = directory.appending(path: Self.fileName + suffix)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    /// Files created inside the directory inherit its protection class, including the WAL files
    /// SQLite creates later.
    private static func prepareDirectory(_ directory: URL) throws {
        let fileManager = FileManager.default
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ]
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.setAttributes(attributes, ofItemAtPath: directory.path)
        } else {
            try fileManager.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: attributes)
        }
    }
}
