extension Allocation {
    /// "Needs", "Wants", "Savings".
    var label: String {
        switch self {
        case .needs: String(localized: "Needs")
        case .wants: String(localized: "Wants")
        case .savings: String(localized: "Savings")
        }
    }

    static let all: [Allocation] = [.needs, .wants, .savings]
}

extension Allocation: Identifiable {
    var id: String { rawValue }
}
