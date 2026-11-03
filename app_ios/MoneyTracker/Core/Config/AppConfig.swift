import Foundation

/// Values injected from xcconfig into Info.plist at build time.
struct AppConfig: Sendable {
    let apiBaseURL: URL
    let revenueCatKey: String
    let googleClientID: String
    let appVersion: String
    let bundleID: String

    static func load(from bundle: Bundle = .main) -> AppConfig {
        func string(_ key: String) -> String {
            (bundle.object(forInfoDictionaryKey: key) as? String)?
                .trimmingCharacters(in: .whitespaces) ?? ""
        }
        let rawURL = string("API_BASE_URL")
        guard let url = URL(string: rawURL), url.scheme != nil, url.host != nil else {
            fatalError(
                "API_BASE_URL is missing or invalid; "
                    + "copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig")
        }
        return AppConfig(
            apiBaseURL: url,
            revenueCatKey: string("REVENUECAT_IOS_KEY"),
            googleClientID: string("GOOGLE_IOS_CLIENT_ID"),
            appVersion: string("CFBundleShortVersionString"),
            bundleID: bundle.bundleIdentifier ?? ""
        )
    }
}
