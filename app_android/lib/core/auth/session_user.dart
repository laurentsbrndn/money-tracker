import '../network/generated/models/user.dart';

/// The signed-in user as the app needs it (API.md §2 `user`).
class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.emailVerified,
    required this.hasPassword,
    required this.providers,
    this.email,
  });

  factory SessionUser.fromApi(User user) => SessionUser(
    id: user.id,
    name: user.name,
    email: user.email,
    emailVerified: user.emailVerified,
    hasPassword: user.hasPassword,
    providers: [for (final p in user.providers) p.toJson()],
  );

  factory SessionUser.fromJson(Map<String, Object?> json) => SessionUser(
    id: json['id']! as String,
    name: json['name']! as String,
    email: json['email'] as String?,
    emailVerified: json['email_verified']! as bool,
    hasPassword: json['has_password']! as bool,
    providers: [
      for (final p in json['providers']! as List<Object?>) p! as String,
    ],
  );

  final String id;
  final String name;
  final String? email;
  final bool emailVerified;
  final bool hasPassword;
  final List<String> providers;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'email_verified': emailVerified,
    'has_password': hasPassword,
    'providers': providers,
  };
}
