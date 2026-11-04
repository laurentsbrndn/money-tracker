import Foundation

/// Where an export is.
enum ExportPhase: Sendable, Equatable {
    case idle
    case working
    /// The share sheet is open.
    case sharing
    case done
    /// No posted transaction in the period: no file is made.
    case empty
    /// The server does not report premium (the screen also checks).
    case notPremium
    /// The app locked while exporting; nothing is written or shared.
    case locked
    /// Writing the file or opening the share sheet failed.
    case failed
}
