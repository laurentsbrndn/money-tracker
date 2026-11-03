import 'dart:async';

import 'package:dio/dio.dart';

import '../../l10n/generated/app_localizations.dart';
import 'api_exception.dart';

/// A user-facing (Indonesian) message for any error raised by an API call.
String describeError(Object error, AppLocalizations l10n) {
  final problem = ApiException.from(error);
  if (problem != null) {
    switch (problem.code) {
      case 'invalid_credentials':
        return l10n.errorInvalidCredentials;
      case 'account_locked':
        final seconds = problem.retryAfterSeconds ?? 900;
        return l10n.errorAccountLocked((seconds / 60).ceil());
      case 'email_taken':
        return l10n.errorEmailTaken;
      case 'code_invalid':
        return l10n.errorCodeInvalid;
      case 'code_expired':
        return l10n.errorCodeExpired;
      case 'too_many_attempts':
        return l10n.errorTooManyAttempts;
      case 'rate_limited':
        return l10n.errorRateLimited;
      case 'unauthorized':
      case 'token_expired':
      case 'refresh_invalid':
      case 'refresh_reused':
        return l10n.errorUnauthorized;
      case 'forbidden':
        return l10n.errorForbidden;
      case 'validation':
        if (problem.fields.isNotEmpty) {
          return problem.fields.first.message;
        }
    }
    if (problem.status >= 500) {
      return l10n.errorServer;
    }
    return problem.detail ?? l10n.errorGeneric;
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
        return l10n.errorOffline;
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return l10n.errorTimeout;
      case DioExceptionType.badResponse:
        if ((error.response?.statusCode ?? 0) >= 500) {
          return l10n.errorServer;
        }
      default:
        break;
    }
  }
  if (error is TimeoutException) {
    return l10n.errorTimeout;
  }
  return l10n.errorGeneric;
}
