import Foundation
import Observation

/// Lainnya → Export data: premium check, read the local database, build the file, share it.
/// Real amounts are exported even when "Sembunyikan nominal" is on (a deliberate act), but never
/// while the app is locked. Rules are the same as Flutter (FRONTEND_FLUTTER.md §4.7).
@Observable
@MainActor
final class ExportViewModel {
    var format = ExportFormat.csv
    var delimiter = CsvDelimiterChoice.auto
    /// nil while the dates were edited by hand.
    var preset: ExportPreset? = .thisMonth
    var from = UserClock.today()
    var to = UserClock.today()
    private(set) var phase = ExportPhase.idle
    private(set) var progress: Double?
    /// The file the share sheet is open for.
    private(set) var shareURL: URL?

    private let repository: ExportRepository
    private let files = ExportFileService()
    private let premium: PremiumStatus
    private let lock: AppLockController

    init(container: AppContainer) {
        repository = ExportRepository(database: container.database)
        premium = container.premium
        lock = container.lock
        files.cleanUp()
        pick(.thisMonth)
    }

    var busy: Bool { phase == .working || phase == .sharing }

    var period: ExportPeriod {
        if let preset { return exportPeriod(for: preset, today: UserClock.today()) }
        return ExportPeriod(from: from, to: to)
    }

    var rangeOK: Bool { period.isValid }

    func pick(_ preset: ExportPreset) {
        self.preset = preset
        let period = exportPeriod(for: preset, today: UserClock.today())
        from = period.from ?? UserClock.today()
        to = period.to ?? UserClock.today()
    }

    /// Editing a date by hand leaves the shortcuts.
    func edited() { preset = nil }

    /// A new visit to the screen. A running export keeps going.
    func reset() {
        if !busy { phase = .idle }
    }

    func run(texts: ExportTexts) async {
        guard !busy else { return }
        guard premium.isPremium else {
            phase = .notPremium
            return
        }
        guard !lock.locked else {
            phase = .locked
            return
        }
        phase = .working
        progress = nil
        do {
            let period = self.period
            let rows = try await repository.loadRows(period)
            if rows.isEmpty {
                phase = .empty
                return
            }
            let first = period.from ?? rows.first?.date ?? UserClock.today()
            let last = period.to ?? rows.last?.date ?? UserClock.today()
            let url: URL
            switch format {
            case .csv:
                let delimiter = resolveCsvDelimiter(
                    delimiter, deviceDecimalSeparator: Locale.current.decimalSeparator ?? ".")
                let csv = buildCsv(
                    rows: rows, headers: texts.headers, typeLabel: texts.typeLabel,
                    delimiter: delimiter)
                url = try files.write(
                    exportFileName(from: first, to: last, fileExtension: "csv"),
                    data: csvBytes(csv))
            case .pdf:
                let target = try files.prepare(
                    exportFileName(from: first, to: last, fileExtension: "pdf"))
                let text =
                    period.isAll
                    ? "\(texts.pdfAllData) (\(Self.range(texts, first, last)))"
                    : Self.range(texts, first, last)
                let model = self
                try await Task.detached(priority: .userInitiated) {
                    try ExportPdfBuilder.write(
                        rows: rows, periodText: text, texts: texts, to: target,
                        onProgress: { value in Task { @MainActor in model.progress = value } })
                }.value
                url = target
            }
            if lock.locked {
                files.remove(url)
                phase = .locked
                return
            }
            shareURL = url
            phase = .sharing
        } catch {
            phase = .failed
        }
    }

    /// The share sheet closed: the result is known, so the file goes.
    func shareFinished() {
        if let shareURL { files.remove(shareURL) }
        shareURL = nil
        phase = .done
    }

    private static func range(_ texts: ExportTexts, _ from: CivilDate, _ to: CivilDate) -> String {
        texts.pdfRange(from.shortText, to.shortText)
    }
}
