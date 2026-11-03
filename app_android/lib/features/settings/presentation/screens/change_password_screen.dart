import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/error_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/presentation/widgets/password_field.dart';
import '../../application/settings_actions.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(settingsActionsProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.changePasswordDone)));
      router.pop();
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePasswordTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PasswordField(
              controller: _current,
              label: l10n.fieldCurrentPassword,
              validate: false,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _next,
              label: l10n.fieldNewPassword,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: _busy ? null : _submit,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.changePasswordHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(l10n.changePasswordTitle),
            ),
          ],
        ),
      ),
    );
  }
}
