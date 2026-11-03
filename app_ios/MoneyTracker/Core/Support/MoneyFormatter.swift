/// Rupiah as whole numbers with Indonesian grouping: 25000 → `Rp 25.000`, -1500 → `-Rp 1.500`
/// (FRONTEND_IOS §4.6). Integer-only: no `Double` or `NumberFormatter` touches an amount.
enum MoneyFormatter {
    static func rupiah(_ amount: Int64, hidden: Bool = false) -> String {
        if hidden { return "Rp •••••" }
        return (amount < 0 ? "-" : "") + "Rp " + grouped(amount.magnitude)
    }

    /// With an explicit sign: 50000 → `+Rp 50.000`, -50000 → `-Rp 50.000`, 0 → `Rp 0`.
    static func signedRupiah(_ amount: Int64, hidden: Bool = false) -> String {
        if hidden { return "Rp •••••" }
        return (amount > 0 ? "+" : "") + rupiah(amount)
    }

    /// Basis points with one decimal and a decimal comma: 1941 → `19,4%`, -250 → `-2,5%`
    /// (BUSINESS_RULES §4.5: one decimal only in the UI).
    static func percent(basisPoints bp: Int64) -> String {
        let sign = bp < 0 ? "-" : ""
        let tenths = (bp.magnitude + 5) / 10
        return "\(sign)\(tenths / 10),\(tenths % 10)%"
    }

    /// `1234567` → `1.234.567` (no currency symbol).
    static func grouped(_ value: UInt64) -> String {
        let digits = Array(String(value))
        var result = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { result.append(".") }
            result.append(digit)
        }
        return result
    }

    /// Digits in `text` as an amount; nil when it holds no digits or is too long to be valid.
    static func parseDigits(_ text: String) -> Int64? {
        let digits = text.filter(\.isASCIINumber)
        guard !digits.isEmpty, digits.count <= 15 else { return nil }
        return Int64(digits)
    }

    /// Reformats text typed into an amount field: digits only, grouped, at most 12 digits; a
    /// leading `-` is kept when `allowNegative`.
    static func formatInput(_ text: String, allowNegative: Bool = false) -> String {
        let negative = allowNegative && text.trimmingCharacters(in: .whitespaces).hasPrefix("-")
        var digits = String(text.filter(\.isASCIINumber).prefix(12))
        while digits.hasPrefix("0") && digits.count > 1 { digits.removeFirst() }
        if digits.isEmpty { return negative ? "-" : "" }
        return (negative ? "-" : "") + grouped(UInt64(digits) ?? 0)
    }

    /// The signed value of text produced by `formatInput`.
    static func value(of text: String, allowNegative: Bool = false) -> Int64? {
        guard let magnitude = parseDigits(text) else { return nil }
        return allowNegative && text.trimmingCharacters(in: .whitespaces).hasPrefix("-")
            ? -magnitude : magnitude
    }
}

extension Character {
    fileprivate var isASCIINumber: Bool { isASCII && isNumber }
}
