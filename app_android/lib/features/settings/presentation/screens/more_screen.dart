import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/settings_actions.dart';

final _versionProvider = FutureProvider.autoDispose<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// "Lainnya" menu (APP_FLOWS Flow 12). Preferences, security, notifications,
/// subscription, and export arrive with their phases.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(settingsActionsProvider);
    final failed = ref.read(failedChangesProvider).value?.length ?? 0;
    final pending = await actions.pendingChanges() + failed;
    if (!context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutTitle),
        content: Text(
          pending > 0
              ? '${l10n.logoutPendingBody(pending)}\n\n${l10n.logoutBody}'
              : l10n.logoutBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logoutConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await actions.logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionControllerProvider).user;
    final version = ref.watch(_versionProvider).value;
    final attention = ref.watch(failedChangesProvider).value?.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMore)),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(user.name),
              subtitle: Text(user.email ?? l10n.profileNoEmail),
              onTap: () => context.push(RoutePaths.settingsProfile),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.moreCategories),
            onTap: () => context.push(RoutePaths.categories),
          ),
          ListTile(
            leading: Badge(
              isLabelVisible: attention > 0,
              label: Text('$attention'),
              child: const Icon(Icons.sync),
            ),
            title: Text(l10n.moreSync),
            onTap: () => context.push(RoutePaths.settingsSync),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.moreLogout),
            onTap: () => unawaited(_logout(context, ref)),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.moreDeleteAccount,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => context.push(RoutePaths.settingsDeleteAccount),
          ),
          if (version != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.moreVersion(version),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
