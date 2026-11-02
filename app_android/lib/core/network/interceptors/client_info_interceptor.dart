import 'package:dio/dio.dart';

/// Values behind the client identity headers required on every request (API.md §1).
class ClientInfo {
  const ClientInfo({required this.deviceId, required this.appVersion});

  final String deviceId;
  final String appVersion;
}

/// Adds `X-Device-ID`, `X-Platform`, `X-App-Version`, and `X-Request-ID`.
class ClientInfoInterceptor extends Interceptor {
  ClientInfoInterceptor({
    required this._loadClientInfo,
    required this._newRequestId,
  });

  final Future<ClientInfo> Function() _loadClientInfo;
  final String Function() _newRequestId;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final info = await _loadClientInfo();
      options.headers['X-Device-ID'] = info.deviceId;
      options.headers['X-Platform'] = 'android';
      options.headers['X-App-Version'] = info.appVersion;
      options.headers.putIfAbsent('X-Request-ID', _newRequestId);
      handler.next(options);
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
