import Foundation

/// |amount| limit of BUSINESS_RULES §6.
let maxAmount: Int64 = 999_999_999_999

/// A client-side check from BUSINESS_RULES §6 failed. The server repeats the same checks on push,
/// so these only spare the user a round trip.
enum ValidationError: Error, LocalizedError {
    case nameRequired, nameTooLong, nameTaken
    case amountRequired, amountZero, amountRange
    case noteTooLong, sourceTooLong
    case dateFuture, dateBeforeOpening, openingDateFuture
    case accountRequired, toAccountRequired, sameAccount
    case categoryRequired, allocationRequired

    var errorDescription: String? {
        switch self {
        case .nameRequired: String(localized: "Nama wajib diisi")
        case .nameTooLong: String(localized: "Nama maksimal 50 karakter")
        case .nameTaken: String(localized: "Nama ini sudah dipakai")
        case .amountRequired: String(localized: "Nominal wajib diisi")
        case .amountZero: String(localized: "Nominal tidak boleh 0")
        case .amountRange: String(localized: "Nominal terlalu besar")
        case .noteTooLong: String(localized: "Catatan maksimal 255 karakter")
        case .sourceTooLong: String(localized: "Sumber maksimal 100 karakter")
        case .dateFuture: String(localized: "Tanggal terlalu jauh di depan")
        case .dateBeforeOpening:
            String(localized: "Tanggal lebih awal dari tanggal saldo awal akun")
        case .openingDateFuture: String(localized: "Tanggal saldo awal tidak boleh di masa depan")
        case .accountRequired: String(localized: "Pilih akun")
        case .toAccountRequired: String(localized: "Pilih akun tujuan")
        case .sameAccount: String(localized: "Akun asal dan tujuan harus berbeda")
        case .categoryRequired: String(localized: "Pilih kategori")
        case .allocationRequired: String(localized: "Pilih alokasi")
        }
    }
}

/// Deleting a record that is still referenced; it can only be archived (BUSINESS_RULES §6).
struct RecordInUseError: Error, LocalizedError {
    let isAccount: Bool

    var errorDescription: String? {
        isAccount
            ? String(localized: "Akun ini masih punya transaksi. Arsipkan saja.")
            : String(localized: "Kategori ini masih dipakai transaksi. Arsipkan saja.")
    }
}
