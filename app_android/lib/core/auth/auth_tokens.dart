/// The token pair of a session (API.md §2).
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
  });

  factory AuthTokens.fromJson(Map<String, Object?> json) => AuthTokens(
    accessToken: json['access_token']! as String,
    accessExpiresAt: DateTime.parse(json['access_expires_at']! as String),
    refreshToken: json['refresh_token']! as String,
    refreshExpiresAt: DateTime.parse(json['refresh_expires_at']! as String),
  );

  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'access_expires_at': accessExpiresAt.toUtc().toIso8601String(),
    'refresh_token': refreshToken,
    'refresh_expires_at': refreshExpiresAt.toUtc().toIso8601String(),
  };

  /// True when the access token is expired or expires within [margin]
  /// (SYNC_PROTOCOL §11 refreshes when less than 60 seconds remain).
  bool accessExpiresWithin(Duration margin, DateTime now) =>
      !accessExpiresAt.isAfter(now.add(margin));

  bool refreshExpired(DateTime now) => !refreshExpiresAt.isAfter(now);
}
