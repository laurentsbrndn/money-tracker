import 'dart:convert';

import 'package:dio/dio.dart';

import 'logic/wire_models.dart';

/// The two sync endpoints, spoken as plain JSON: rows are already whole-row
/// maps (see `EntityCodec`), so no typed request models are needed.
class SyncRemote {
  const SyncRemote(this._dio);

  final Dio _dio;

  /// `POST /v1/sync/push`. [changes] are the wire entries in `seq` order.
  Future<List<PushResultInfo>> push(
    String batchId,
    List<Map<String, Object?>> changes,
  ) async {
    final response = await _dio.post<Object?>(
      '/v1/sync/push',
      data: {'changes': changes},
      options: Options(headers: {'Idempotency-Key': batchId}),
    );
    final body = _asMap(response.data);
    return [
      for (final raw in body['results']! as List<Object?>)
        PushResultInfo.fromJson(_asMap(raw)),
    ];
  }

  /// `GET /v1/sync/pull`.
  Future<PullPage> pull(int since, {int limit = 500}) async {
    final response = await _dio.get<Object?>(
      '/v1/sync/pull',
      queryParameters: {'since': since, 'limit': limit},
    );
    return PullPage.fromJson(_asMap(response.data));
  }

  Map<String, Object?> _asMap(Object? data) {
    final decoded = data is String ? jsonDecode(data) : data;
    return Map<String, Object?>.from(decoded! as Map<Object?, Object?>);
  }
}
