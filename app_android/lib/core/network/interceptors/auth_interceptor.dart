import 'package:dio/dio.dart';

import '../../auth/token_refresher.dart';
import '../api_exception.dart';

const String _retriedKey = 'auth_retried';
const String _tokenKey = 'auth_token_used';

/// Endpoints that work without a Bearer token (API.md §2).
const List<String> _publicPaths = [
  '/v1/auth/register',
  '/v1/auth/login',
  '/v1/auth/oauth/',
  '/v1/auth/refresh',
  '/v1/auth/logout',
  '/v1/auth/password/forgot',
  '/v1/auth/password/reset',
];

bool _isPublic(String path) => _publicPaths.any(path.startsWith);

/// Adds `Authorization: Bearer`, and on `401 token_expired` renews the token
/// once (single-flight, see [TokenRefresher]) and repeats the request.
/// Must be added after the problem interceptor so errors arrive as
/// [ApiException].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this._refresher, required this._dio});

  final TokenRefresher _refresher;
  final Dio Function() _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublic(options.path)) {
      handler.next(options);
      return;
    }
    try {
      final token = await _refresher.validAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        options.extra[_tokenKey] = token;
      }
      handler.next(options);
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          type: error is DioException
              ? error.type
              : DioExceptionType.connectionError,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final problem = err.error;
    final options = err.requestOptions;
    final usedToken = options.extra[_tokenKey] as String?;
    if (problem is! ApiException ||
        problem.code != 'token_expired' ||
        usedToken == null ||
        options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    try {
      final renewed = await _refresher.renewAfterRejection(usedToken);
      if (renewed == null) {
        handler.next(err);
        return;
      }
      options.headers['Authorization'] = 'Bearer $renewed';
      options.extra[_retriedKey] = true;
      options.extra[_tokenKey] = renewed;
      handler.resolve(await _dio().fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    } on Object {
      handler.next(err);
    }
  }
}
