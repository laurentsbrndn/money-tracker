import Foundation

/// Writes the export to a temporary folder. The files are temporary on purpose: they hold real
/// amounts, so they are deleted as soon as the share sheet reports back, before the next export,
/// and when the app starts (`cleanUp`).
struct ExportFileService: Sendable {
    private var folder: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
    }

    /// Deletes every leftover export file.
    func cleanUp() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(exportFilePrefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// The URL a new file of `name` should be written to (the folder is created and emptied).
    func prepare(_ name: String) throws -> URL {
        cleanUp()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(name)
    }

    func write(_ name: String, data: Data) throws -> URL {
        let url = try prepare(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
