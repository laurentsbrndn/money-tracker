import 'dart:convert';

import 'package:dio/dio.dart';

import '../api_exception.dart';

/// Turns `application/problem+json` error bodies into [ApiException]
/// (available as `DioException.error`). Other failures pass through untouched.
class ProblemInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final problem = ApiException.tryParse(_decode(err.response?.data));
    if (problem == null) {
      handler.next(err);
      return;
    }
    handler.next(err.copyWith(error: problem));
  }

  Object? _decode(Object? data) {
    if (data is String && data.isNotEmpty) {
      try {
        return jsonDecode(data);
      } on FormatException {
        return null;
      }
    }
    return data;
  }
}
