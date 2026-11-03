import '../../../l10n/generated/app_localizations.dart';

/// Form validators for the auth screens (API.md §2: password 8-72 characters).
abstract final class AuthValidators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(AppLocalizations l10n, String? value) =>
      (value ?? '').trim().isEmpty ? l10n.validationRequired : null;

  static String? email(AppLocalizations l10n, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return l10n.validationRequired;
    }
    return _email.hasMatch(text) ? null : l10n.validationEmail;
  }

  static String? password(AppLocalizations l10n, String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return l10n.validationRequired;
    }
    if (text.length < 8) {
      return l10n.validationPasswordShort;
    }
    return text.length > 72 ? l10n.validationPasswordLong : null;
  }

  static String? code(AppLocalizations l10n, String? value) =>
      RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())
      ? null
      : l10n.validationCode;
}
