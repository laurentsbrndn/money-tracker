import 'package:dio/dio.dart';

class ApiFieldError {
  const ApiFieldError({required this.field, required this.message});

  final String field;
  final String message;
}

/// An `application/problem+json` error (API.md §1.2). [code] stays a plain
/// string so codes added by the server later do not break parsing.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.title,
    this.detail,
    this.fields = const [],
    this.retryAfterSeconds,
    this.requestId,
  });

  /// Returns null when [data] is not a problem document.
  static ApiException? tryParse(Object? data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final code = data['code'];
    final status = data['status'];
    if (code is! String || status is! int) {
      return null;
    }
    final rawFields = data['fields'];
    return ApiException(
      status: status,
      code: code,
      title: data['title'] as String? ?? '',
      detail: data['detail'] as String?,
      fields: rawFields is List
          ? [
              for (final item in rawFields)
                if (item is Map<String, dynamic>)
                  ApiFieldError(
                    field: item['field'] as String? ?? '',
                    message: item['message'] as String? ?? '',
                  ),
            ]
          : const [],
      retryAfterSeconds: data['retry_after_seconds'] as int?,
      requestId: data['request_id'] as String?,
    );
  }

  /// The problem carried by [error], if it is a [DioException] with one.
  static ApiException? from(Object error) {
    if (error is DioException && error.error is ApiException) {
      return error.error as ApiException;
    }
    return null;
  }

  final int status;
  final String code;
  final String title;
  final String? detail;
  final List<ApiFieldError> fields;
  final int? retryAfterSeconds;
  final String? requestId;

  @override
  String toString() => 'ApiException($status $code: ${detail ?? title})';
}
