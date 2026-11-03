/// Banks and e-wallets offered in the account form (APP_FLOWS Flow 1, step 6.2).
struct BankProvider: Identifiable, Hashable, Sendable {
    let key: String
    let name: String

    var id: String { key }
}

enum ProviderLogos {
    static let all = [
        BankProvider(key: "bca", name: "BCA"),
        BankProvider(key: "mandiri", name: "Mandiri"),
        BankProvider(key: "bri", name: "BRI"),
        BankProvider(key: "bni", name: "BNI"),
        BankProvider(key: "jago", name: "Jago"),
        BankProvider(key: "seabank", name: "SeaBank"),
        BankProvider(key: "gopay", name: "GoPay"),
        BankProvider(key: "ovo", name: "OVO"),
        BankProvider(key: "dana", name: "DANA"),
        BankProvider(key: "shopeepay", name: "ShopeePay"),
        BankProvider(key: "other", name: "Lainnya"),
    ]

    static func name(of key: String?) -> String? {
        all.first { $0.key == key }?.name
    }

    /// Name of the image in the asset catalog, `logo_<key>`.
    static func assetName(_ key: String) -> String { "logo_\(key)" }
}
