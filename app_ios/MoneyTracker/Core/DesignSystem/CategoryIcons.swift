import SwiftUI

/// Icon keys shared with the server and Android (BUSINESS_RULES §2.1) → SF Symbols.
enum CategoryIcons {
    static let bySymbol: [String: String] = [
        "food": "fork.knife",
        "transport": "bus",
        "home": "house",
        "bill": "doc.text",
        "health": "cross.case",
        "education": "graduationcap",
        "fee": "banknote",
        "shopping": "bag",
        "entertainment": "film",
        "subscription": "arrow.triangle.2.circlepath",
        "snack": "takeoutbag.and.cup.and.straw",
        "gift": "gift",
        "investment": "chart.line.uptrend.xyaxis",
        "other": "ellipsis",
        "salary": "briefcase",
        "freelance": "laptopcomputer",
        "bonus": "trophy",
    ]

    /// Keys offered when the user creates or edits a category, in a fixed order.
    static let pickable = [
        "food", "transport", "home", "bill", "health", "education", "fee", "shopping",
        "entertainment", "subscription", "snack", "gift", "investment", "other", "salary",
        "freelance", "bonus",
    ]

    static func symbol(_ key: String) -> String { bySymbol[key] ?? "tag" }

    /// `#RRGGBB` → Color; grey for anything malformed.
    static func color(_ hex: String) -> Color {
        guard hex.count == 7, hex.hasPrefix("#"), let value = UInt32(hex.dropFirst(), radix: 16)
        else { return Color(red: 0.612, green: 0.639, blue: 0.686) }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }

    /// Palette offered for custom categories (same hex values the server seeds).
    static let palette = [
        "#F59E0B", "#3B82F6", "#8B5CF6", "#EF4444", "#10B981", "#06B6D4", "#EC4899", "#F97316",
        "#6366F1", "#14B8A6", "#22C55E", "#9CA3AF",
    ]
}
