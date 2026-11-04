import SwiftUI

/// One slice of a pie report. `filter` is the transaction list the slice opens (nil when it has
/// nothing to open, e.g. "Tanpa kategori").
struct PieEntry: Identifiable {
    let id: Int
    let label: String
    let amount: Int64
    let color: Color
    var filter: TransactionFilter?
}
