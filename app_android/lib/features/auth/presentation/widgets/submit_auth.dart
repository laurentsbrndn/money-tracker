import 'package:flutter/material.dart';

import '../../../../core/auth/user_mismatch_exception.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/google_sign_in_service.dart';

/// Runs a login/register [action] and returns the message to show, or null on
/// success. If the device holds another user's data (SYNC_PROTOCOL §11) the
/// user is asked first and [action] runs again with `discardLocalData` true.
Future<String?> submitAuth(
  BuildContext context,
  Future<void> Function({required bool discardLocalData}) action,
) async {
  final l10n = AppLocalizations.of(context);
  try {
    await action(discardLocalData: false);
    return null;
  } on UserMismatchException catch (mismatch) {
    if (!context.mounted) {
      return null;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.userMismatchTitle),
        content: Text(l10n.userMismatchBody(mismatch.pendingChanges)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.userMismatchConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return null;
    }
    try {
      await action(discardLocalData: true);
      return null;
    } on Object catch (error) {
      return _message(error, l10n);
    }
  } on Object catch (error) {
    return _message(error, l10n);
  }
}

String _message(Object error, AppLocalizations l10n) {
  if (error is GoogleSignInUnavailable) {
    return l10n.errorGoogleNotConfigured;
  }
  final text = describeError(error, l10n);
  return text == l10n.errorGeneric && error is! Exception
      ? l10n.errorGeneric
      : text;
}
