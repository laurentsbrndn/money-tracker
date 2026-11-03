import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/error_messages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/security/app_lock_controller.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/user_settings_actions.dart';
import '../../application/user_settings_providers.dart';

final _biometricAvailableProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(biometricServiceProvider).isAvailable(),
);

/// Pengaturan → Keamanan (APP_FLOWS Flow 12): PIN, biometrics, auto-lock
/// (device only), and hide amounts (synced with `user_settings`).
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  Future<void> _toggleHide(
    BuildContext context,
    WidgetRef ref, {
    required bool hide,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(userSettingsRepositoryProvider)
          .setHideAmounts(hide: hide);
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    }
  }

  Future<void> _pickAutoLock(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final options = {
      0: l10n.securityAutoLockImmediately,
      60: l10n.securityAutoLock1min,
      300: l10n.securityAutoLock5min,
    };
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.securityAutoLock),
        children: [
          RadioGroup<int>(
            groupValue: current,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              children: [
                for (final entry in options.entries)
                  RadioListTile<int>(
                    value: entry.key,
                    title: Text(entry.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(appLockControllerProvider.notifier).setAutoLockSeconds(picked);
    }
  }

  String _autoLockLabel(AppLocalizations l10n, int seconds) => switch (seconds) {
    0 => l10n.securityAutoLockImmediately,
    60 => l10n.securityAutoLock1min,
    300 => l10n.securityAutoLock5min,
    _ => l10n.securityAutoLock1min,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lock = ref.watch(appLockControllerProvider);
    final hide = ref.watch(hideAmountsProvider);
    final settingsReady = ref.watch(userSettingsProvider).value != null;
    final biometricAvailable =
        ref.watch(_biometricAvailableProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.securityTitle)),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: Text(l10n.securityPinToggle),
            subtitle: Text(l10n.securityPinSubtitle),
            value: lock.pinSet,
            onChanged: (enable) => unawaited(
              context.push(
                '${RoutePaths.settingsPin}?mode=${enable ? 'set' : 'remove'}',
              ),
            ),
          ),
          if (lock.pinSet) ...[
            ListTile(
              leading: const Icon(Icons.password),
              title: Text(l10n.securityChangePin),
              onTap: () =>
                  context.push('${RoutePaths.settingsPin}?mode=change'),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(l10n.securityBiometric),
              subtitle: biometricAvailable
                  ? null
                  : Text(l10n.securityBiometricUnavailable),
              value: lock.biometricEnabled,
              onChanged: biometricAvailable || lock.biometricEnabled
                  ? (enable) => unawaited(
                      ref
                          .read(appLockControllerProvider.notifier)
                          .setBiometric(
                            l10n.securityBiometricReason,
                            enabled: enable,
                          ),
                    )
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(l10n.securityAutoLock),
              subtitle: Text(_autoLockLabel(l10n, lock.autoLockSeconds)),
              onTap: () => unawaited(
                _pickAutoLock(context, ref, lock.autoLockSeconds),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              l10n.securityDeviceOnlyNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(l10n.securityHideAmounts),
            subtitle: Text(l10n.securityHideAmountsSubtitle),
            value: hide,
            onChanged: settingsReady
                ? (value) =>
                      unawaited(_toggleHide(context, ref, hide: value))
                : null,
          ),
        ],
      ),
    );
  }
}
