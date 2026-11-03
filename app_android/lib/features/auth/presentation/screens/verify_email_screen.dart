import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/auth_actions.dart';
import '../../domain/auth_validators.dart';
import '../widgets/auth_scaffold.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
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
      await ref.read(authActionsProvider).verifyEmail(_code.text.trim());
      messenger.showSnackBar(SnackBar(content: Text(l10n.verifyEmailDone)));
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(RoutePaths.home);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(error, l10n);
        });
      }
    }
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authActionsProvider).resendEmailVerification();
      messenger.showSnackBar(SnackBar(content: Text(l10n.verifyEmailResent)));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = ref.watch(sessionControllerProvider).user?.email ?? '';
    return AuthScaffold(
      title: l10n.verifyEmailTitle,
      subtitle: l10n.verifyEmailSubtitle(email),
      showBack: true,
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
            decoration: InputDecoration(
              labelText: l10n.fieldCode,
              border: const OutlineInputBorder(),
            ),
            validator: (value) => AuthValidators.code(l10n, value),
            onFieldSubmitted: (_) => _busy ? null : _verify(),
          ),
        ),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: _busy ? null : _verify,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(l10n.verifyEmailButton),
        ),
        TextButton(
          onPressed: _busy ? null : _resend,
          child: Text(l10n.verifyEmailResend),
        ),
        TextButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(RoutePaths.home),
          child: Text(l10n.verifyEmailLater),
        ),
      ],
    );
  }
}
