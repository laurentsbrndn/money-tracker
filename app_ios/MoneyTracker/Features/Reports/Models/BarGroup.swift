import SwiftUI

/// One bar of a group.
struct BarValue: Identifiable {
    let id: String
    /// Legend name of the series (`Pemasukan`, `Bulan ini`, ...).
    let series: String
    let value: Int64
    let color: Color
}

/// A group of bars under one label (a month, or a measure).
struct BarGroup: Identifiable {
    let id: String
    let label: String
    let bars: [BarValue]
}
