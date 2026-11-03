import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Builds the generated `Client`. `config.apiBaseURL` is the origin only; the paths in
/// openapi.yaml already start with `/v1`.
enum APIClientFactory {
    static func make(
        config: AppConfig,
        deviceID: @escaping @Sendable () async throws -> String,
        deviceName: String?,
        idGenerator: IDGenerator = IDGenerator()
    ) -> Client {
        Client(
            serverURL: config.apiBaseURL,
            transport: URLSessionTransport(),
            middlewares: [
                ClientInfoMiddleware(
                    deviceID: deviceID,
                    appVersion: config.appVersion,
                    deviceName: deviceName,
                    makeRequestID: { idGenerator.newID() })
            ])
    }
}
