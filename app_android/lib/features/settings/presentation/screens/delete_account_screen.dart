import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/widgets/password_field.dart';
import '../../application/settings_actions.dart';

/// Delete account (APP_FLOWS Flow 12): explanation, reminder to cancel the
/// store subscription, confirmation by password or by typing `HAPUS`. On
/// success the local data is wiped and the router returns to onboarding.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const String _word = 'HAPUS';

  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _delete(bool usesPassword) async {
    final l10n = AppLocalizations.of(context);
    final text = _confirmation.text;
    if (!usesPassword && text.trim() != _word) {
      setState(() => _error = l10n.deleteAccountWrongWord);
      return;
    }
    if (text.isEmpty) {
      setState(() => _error = l10n.validationRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(settingsActionsProvider)
          .deleteAccount(usesPassword ? text : _word);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(error, l10n);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final usesPassword =
        ref.watch(sessionControllerProvider).user?.hasPassword ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.deleteAccountBody),
          const SizedBox(height: 12),
          Text(l10n.deleteAccountSubscription),
          const SizedBox(height: 24),
          if (usesPassword)
            PasswordField(
              controller: _confirmation,
              label: l10n.deleteAccountPasswordLabel,
              validate: false,
            )
          else
            TextField(
              controller: _confirmation,
              decoration: InputDecoration(
                labelText: l10n.deleteAccountTypeLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _busy ? null : () => _delete(usesPassword),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );
  }
}
