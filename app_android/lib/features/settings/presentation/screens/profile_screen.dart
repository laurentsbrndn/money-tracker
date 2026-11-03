import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/settings_actions.dart';

/// Name, email and verification status, login methods, change password.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(sessionControllerProvider).user?.name ?? '',
  );
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_name.text.trim().isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(settingsActionsProvider).updateName(_name.text);
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionControllerProvider).user;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final methods = [
      if (user.hasPassword) l10n.profileMethodPassword,
      if (user.providers.contains('google')) l10n.profileMethodGoogle,
      if (user.providers.contains('apple')) l10n.profileMethodApple,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.profileName,
              border: const OutlineInputBorder(),
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(l10n.actionSave),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: Text(user.email ?? l10n.profileNoEmail),
            subtitle: user.email == null
                ? null
                : Text(
                    user.emailVerified
                        ? l10n.profileEmailVerified
                        : l10n.profileEmailNotVerified,
                  ),
            trailing: user.email != null && !user.emailVerified
                ? TextButton(
                    onPressed: () => context.push(RoutePaths.verifyEmail),
                    child: Text(l10n.verifyEmailBannerAction),
                  )
                : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.login),
            title: Text(l10n.profileLoginMethods),
            subtitle: Text(methods.join(', ')),
          ),
          if (user.hasPassword)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: Text(l10n.profileChangePassword),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.settingsPassword),
            ),
        ],
      ),
    );
  }
}
