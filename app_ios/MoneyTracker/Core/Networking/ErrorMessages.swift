import Foundation

/// A user-facing (Indonesian) message for any error raised by an API call.
enum ErrorMessages {
    static func describe(_ error: any Error) -> String {
        if let localized = (error as? any LocalizedError)?.errorDescription { return localized }
        switch APIFailure(error) {
        case .api(let problem):
            return describe(problem)
        case .unreachable:
            return String(
                localized: "Tidak ada koneksi internet. Periksa jaringanmu lalu coba lagi.")
        case .other:
            return String(localized: "Terjadi kesalahan. Coba lagi.")
        }
    }

    private static func describe(_ problem: APIError) -> String {
        switch problem.code {
        case "invalid_credentials":
            return String(localized: "Email atau password salah.")
        case "account_locked":
            let minutes = Int((Double(problem.retryAfterSeconds ?? 900) / 60).rounded(.up))
            return String(localized: "Terlalu banyak percobaan. Coba lagi dalam \(minutes) menit.")
        case "email_taken":
            return String(localized: "Email ini sudah terdaftar. Silakan masuk.")
        case "code_invalid":
            return String(localized: "Kode salah.")
        case "code_expired":
            return String(localized: "Kode sudah kedaluwarsa. Minta kode baru.")
        case "too_many_attempts":
            return String(localized: "Terlalu banyak percobaan salah. Minta kode baru.")
        case "rate_limited":
            return String(localized: "Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.")
        case "unauthorized", "token_expired", "refresh_invalid", "refresh_reused",
            "session_expired":
            return String(localized: "Sesi tidak valid. Silakan masuk lagi.")
        case "forbidden":
            return String(localized: "Kamu tidak punya akses untuk ini.")
        case "validation":
            if let first = problem.fields.first, !first.message.isEmpty { return first.message }
        default:
            break
        }
        if problem.status >= 500 {
            return String(localized: "Server sedang bermasalah. Coba lagi nanti.")
        }
        return problem.detail ?? String(localized: "Terjadi kesalahan. Coba lagi.")
    }
}
