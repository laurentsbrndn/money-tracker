import Foundation

/// Form validators for the auth screens (API.md §2: password 8-72 characters). Each returns an
/// error message, or nil when the value is fine.
enum AuthValidators {
    static func required(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespaces).isEmpty ? String(localized: "Wajib diisi") : nil
    }

    static func email(_ value: String) -> String? {
        let text = value.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return String(localized: "Wajib diisi") }
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return text.range(of: pattern, options: .regularExpression) == nil
            ? String(localized: "Format email tidak valid") : nil
    }

    static func password(_ value: String) -> String? {
        if value.isEmpty { return String(localized: "Wajib diisi") }
        if value.count < 8 { return String(localized: "Password minimal 8 karakter") }
        return value.count > 72 ? String(localized: "Password maksimal 72 karakter") : nil
    }

    static func code(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespaces).range(
            of: #"^\d{6}$"#, options: .regularExpression)
            == nil ? String(localized: "Masukkan 6 digit kode") : nil
    }
}
