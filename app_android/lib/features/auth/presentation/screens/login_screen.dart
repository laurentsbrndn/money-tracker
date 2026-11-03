import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/auth/session_state.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/auth_actions.dart';
import '../../domain/auth_validators.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/password_field.dart';
import '../widgets/submit_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // After "needs login" the previous account is offered again.
    _email = TextEditingController(
      text: ref.read(sessionControllerProvider).user?.email ?? '',
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function({required bool discardLocalData}) action,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final message = await submitAuth(context, action);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = message;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final actions = ref.read(authActionsProvider);
    await _run(
      ({required discardLocalData}) => actions.login(
        email: _email.text.trim(),
        password: _password.text,
        discardLocalData: discardLocalData,
      ),
    );
  }

  Future<void> _google() async {
    final actions = ref.read(authActionsProvider);
    await _run(
      ({required discardLocalData}) =>
          actions.loginWithGoogle(discardLocalData: discardLocalData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final needsLogin =
        ref.watch(sessionControllerProvider).status == SessionStatus.needsLogin;
    return AuthScaffold(
      title: l10n.loginTitle,
      subtitle: needsLogin ? l10n.loginNeedsLoginNotice : l10n.loginSubtitle,
      showBack: needsLogin,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.fieldEmail,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => AuthValidators.email(l10n, value),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: l10n.fieldPassword,
                validate: false,
                onSubmitted: _busy ? null : _login,
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy
                ? null
                : () => context.push(RoutePaths.forgotPassword),
            child: Text(l10n.forgotPasswordLink),
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
          onPressed: _busy ? null : _login,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.loginButton),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l10n.authOr),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        GoogleSignInButton(onPressed: _busy ? null : _google),
        const SizedBox(height: 8),
        if (!needsLogin)
          TextButton(
            onPressed: _busy ? null : () => context.go(RoutePaths.register),
            child: Text(l10n.noAccountRegister),
          ),
      ],
    );
  }
}
