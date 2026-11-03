import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/security/app_lock_controller.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Setup wizard step: optional PIN lock (APP_FLOWS Flow 1 step 6.6). The PIN
/// itself is set on the shared PIN screen.
class SetupLockStep extends ConsumerWidget {
  const SetupLockStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pinSet = ref.watch(appLockControllerProvider.select((s) => s.pinSet));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.setupLockTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.setupLockBody),
        const SizedBox(height: 24),
        if (pinSet)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(l10n.setupLockActive),
          )
        else
          OutlinedButton.icon(
            onPressed: () =>
                context.push('${RoutePaths.settingsPin}?mode=set'),
            icon: const Icon(Icons.lock_outline),
            label: Text(l10n.setupLockAction),
          ),
      ],
    );
  }
}
