import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// The API entry points: the generated `Client` for typed calls (auth, `/me`), `RawAPI` for sync
/// rows. `config.apiBaseURL` is the origin only; paths in openapi.yaml already start with
/// `/v1`.
struct APIEnvironment: Sendable {
    let client: Client
    let raw: RawAPI

    /// The server sends timestamps with fixed milliseconds ("2026-11-03T06:37:00.123Z"). The
    /// default OpenAPIRuntime transcoder rejects fractional seconds, so both clients use this one.
    private static let clientConfiguration = Configuration(
        dateTranscoder: .iso8601WithFractionalSeconds)

    /// A client without the auth middleware, used only to refresh tokens: a refresh must never
    /// trigger another refresh.
    static func makeRefreshClient(
        config: AppConfig,
        deviceID: @escaping @Sendable () async throws -> String,
        deviceName: String?,
        idGenerator: IDGenerator = IDGenerator()
    ) -> Client {
        let transport = URLSessionTransport()
        let info = clientInfo(config, deviceID, deviceName, idGenerator)
        return Client(
            serverURL: config.apiBaseURL,
            configuration: clientConfiguration,
            transport: transport,
            middlewares: [info, ProblemMiddleware()])
    }

    static func make(
        config: AppConfig,
        refresher: TokenRefresher,
        deviceID: @escaping @Sendable () async throws -> String,
        deviceName: String?,
        onUpgradeRequired: @escaping @Sendable () async -> Void,
        idGenerator: IDGenerator = IDGenerator()
    ) -> APIEnvironment {
        let transport = URLSessionTransport()
        let info = clientInfo(config, deviceID, deviceName, idGenerator)
        let upgrade = UpgradeRequiredMiddleware(onUpgradeRequired: onUpgradeRequired)
        let authenticated: [any ClientMiddleware] = [
            info, upgrade, AuthMiddleware(refresher: refresher), ProblemMiddleware(),
        ]
        return APIEnvironment(
            client: Client(
                serverURL: config.apiBaseURL,
                configuration: clientConfiguration,
                transport: transport,
                middlewares: authenticated),
            raw: RawAPI(
                baseURL: config.apiBaseURL, transport: transport, middlewares: authenticated))
    }

    private static func clientInfo(
        _ config: AppConfig, _ deviceID: @escaping @Sendable () async throws -> String,
        _ deviceName: String?, _ idGenerator: IDGenerator
    ) -> ClientInfoMiddleware {
        ClientInfoMiddleware(
            deviceID: deviceID, appVersion: config.appVersion, deviceName: deviceName,
            makeRequestID: { idGenerator.newID() })
    }
}
