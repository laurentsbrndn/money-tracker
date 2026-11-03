import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../router/route_paths.dart';
import '../sync/sync_status_provider.dart';

/// Header chip with the sync state (FRONTEND_FLUTTER §4.3). Tapping it opens
/// the screen that fits: login when the session ended, sync settings
/// otherwise.
class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(syncStatusProvider);
    final (String label, IconData icon, Color color) = switch (state.kind) {
      SyncBadgeKind.synced => (
        l10n.syncBadgeSynced,
        Icons.cloud_done_outlined,
        scheme.primary,
      ),
      SyncBadgeKind.syncing => (
        l10n.syncBadgeSyncing,
        Icons.sync,
        scheme.primary,
      ),
      SyncBadgeKind.pending => (
        l10n.syncBadgePending(state.count),
        Icons.cloud_upload_outlined,
        scheme.tertiary,
      ),
      SyncBadgeKind.offline => (
        l10n.syncBadgeOffline,
        Icons.cloud_off_outlined,
        scheme.outline,
      ),
      SyncBadgeKind.needsLogin => (
        l10n.syncBadgeNeedsLogin,
        Icons.lock_outline,
        scheme.error,
      ),
      SyncBadgeKind.attention => (
        l10n.syncBadgeAttention(state.count),
        Icons.error_outline,
        scheme.error,
      ),
    };
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      onPressed: () => context.push(
        state.kind == SyncBadgeKind.needsLogin
            ? RoutePaths.login
            : RoutePaths.settingsSync,
      ),
    );
  }
}
