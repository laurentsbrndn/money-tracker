import 'package:dio/dio.dart';

/// The OpenAPI paths already start with `/v1`, so [apiBaseUrl] is reduced to
/// its origin (a trailing `/v1` is accepted and dropped).
String originOf(String apiBaseUrl) {
  var url = apiBaseUrl.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.endsWith('/v1')) {
    url = url.substring(0, url.length - 3);
  }
  return url;
}

Dio createDio({
  required String apiBaseUrl,
  required List<Interceptor> interceptors,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: originOf(apiBaseUrl),
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.addAll(interceptors);
  return dio;
}
