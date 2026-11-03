// Plain value types for the sync wire format, parsed from decoded JSON so
// they can be used without the generated client.

class PushResultInfo {
  const PushResultInfo({
    required this.entity,
    required this.id,
    required this.status,
    this.serverVersion,
    this.errorCode,
    this.errorMessage,
    this.retryable = false,
  });

  factory PushResultInfo.fromJson(Map<String, Object?> json) {
    final error = json['error'];
    final errorMap = error is Map<String, Object?> ? error : null;
    return PushResultInfo(
      entity: json['entity']! as String,
      id: json['id']! as String,
      status: json['status']! as String,
      serverVersion: json['server_version'] as int?,
      errorCode: errorMap?['code'] as String?,
      errorMessage: errorMap?['message'] as String?,
      retryable: errorMap?['retryable'] as bool? ?? false,
    );
  }

  final String entity;
  final String id;

  /// `applied`, `stale`, or `rejected`.
  final String status;
  final int? serverVersion;
  final String? errorCode;
  final String? errorMessage;
  final bool retryable;
}

class PullChangeItem {
  const PullChangeItem({
    required this.entity,
    required this.id,
    required this.serverVersion,
    required this.data,
  });

  factory PullChangeItem.fromJson(Map<String, Object?> json) => PullChangeItem(
    entity: json['entity']! as String,
    id: json['id']! as String,
    serverVersion: json['server_version']! as int,
    data: Map<String, Object?>.from(json['data']! as Map<Object?, Object?>),
  );

  final String entity;
  final String id;
  final int serverVersion;

  /// The whole row, tombstones included.
  final Map<String, Object?> data;
}

class PullPage {
  const PullPage({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
    this.entitlementJson,
  });

  factory PullPage.fromJson(Map<String, Object?> json) {
    final meta = json['meta'];
    final entitlement = meta is Map<String, Object?>
        ? meta['entitlement']
        : null;
    return PullPage(
      changes: [
        for (final raw in json['changes']! as List<Object?>)
          PullChangeItem.fromJson(
            Map<String, Object?>.from(raw! as Map<Object?, Object?>),
          ),
      ],
      nextCursor: json['next_cursor']! as int,
      hasMore: json['has_more']! as bool,
      entitlementJson: entitlement is Map<String, Object?> ? entitlement : null,
    );
  }

  final List<PullChangeItem> changes;
  final int nextCursor;
  final bool hasMore;
  final Map<String, Object?>? entitlementJson;
}
