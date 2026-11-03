import Foundation

/// Account types in form order, with their stored values (DATA_MODEL §1.2).
enum AccountTypeLabels {
    static let values = ["bank", "e_wallet", "cash", "savings"]

    static func label(_ type: String) -> String {
        switch type {
        case "bank": String(localized: "Bank")
        case "e_wallet": String(localized: "E-wallet")
        case "cash": String(localized: "Tunai")
        case "savings": String(localized: "Tabungan")
        default: type
        }
    }
}
