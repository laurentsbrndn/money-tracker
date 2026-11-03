import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money_formatter.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/sync/failed_change.dart';
import '../../../../core/sync/sync_entities.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/sync_run_state.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/sync/sync_status_provider.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../core/time/timestamp_format.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Sync status, "Sync sekarang", and the "Perlu perhatian" list
/// (APP_FLOWS Flow 11).
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncing = true);
    final outcome = await ref.read(syncSchedulerProvider).syncNow();
    if (!mounted) {
      return;
    }
    setState(() => _syncing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (outcome) {
          SyncOutcome.synced => l10n.syncNowDone,
          SyncOutcome.offline => l10n.syncNowOffline,
          SyncOutcome.needsLogin => l10n.syncNowNeedsLogin,
          _ => l10n.syncNowFailed,
        }),
      ),
    );
  }

  String _lastSync(AppLocalizations l10n, String? stored) {
    if (stored == null) {
      return l10n.syncNever;
    }
    final local = parseTimestamp(stored).toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '${formatCivilDateShort(CivilDate.fromDateTime(local))} $time';
  }

  Future<void> _showActions(FailedChange change) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(failedChangesServiceProvider);
    final editRoute = switch (change.entity) {
      SyncEntities.accounts => RoutePaths.accountEdit(change.recordId),
      SyncEntities.transactions => RoutePaths.transaction(change.recordId),
      SyncEntities.categories => RoutePaths.categoryEdit(change.recordId),
      _ => null,
    };
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.syncAttentionBody),
            ),
            if (editRoute != null && !change.isDelete)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.syncFix),
                onTap: () => Navigator.pop(context, 'fix'),
              ),
            ListTile(
              leading: const Icon(Icons.send_outlined),
              title: Text(l10n.syncRetry),
              onTap: () => Navigator.pop(context, 'retry'),
            ),
            ListTile(
              leading: const Icon(Icons.undo),
              title: Text(l10n.syncDiscard),
              onTap: () => Navigator.pop(context, 'discard'),
            ),
          ],
        ),
      ),
    );
    try {
      switch (action) {
        case 'fix':
          unawaited(router.push(editRoute!));
        case 'retry':
          await service.retry(change);
          messenger.showSnackBar(SnackBar(content: Text(l10n.syncRequeued)));
        case 'discard':
          await service.discard(change);
          messenger.showSnackBar(SnackBar(content: Text(l10n.syncDiscarded)));
      }
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    }
  }

  String _entityLabel(AppLocalizations l10n, String entity) => switch (entity) {
    SyncEntities.accounts => l10n.syncEntityAccounts,
    SyncEntities.categories => l10n.syncEntityCategories,
    SyncEntities.transactions => l10n.syncEntityTransactions,
    SyncEntities.balanceSnapshots => l10n.syncEntitySnapshots,
    SyncEntities.userSettings => l10n.syncEntitySettings,
    SyncEntities.budgetGoals => l10n.syncEntityBudget,
    _ => l10n.syncEntityRecurring,
  };

  String _reason(AppLocalizations l10n, String error) {
    if (error.startsWith('plan_limit')) {
      return l10n.syncReasonPlanLimit;
    }
    if (error.startsWith('validation')) {
      return l10n.syncReasonValidation;
    }
    if (error.startsWith('reference_missing')) {
      return l10n.syncReasonReference;
    }
    if (error.startsWith('forbidden')) {
      return l10n.syncReasonForbidden;
    }
    return l10n.syncReasonOther;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pending = ref.watch(pendingChangeCountProvider).value ?? 0;
    final failed = ref.watch(failedChangesProvider).value ?? const [];
    final last = ref.watch(lastSyncAtProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncSettingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.syncLastSync),
            subtitle: Text(_lastSync(l10n, last)),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: Text(l10n.syncPendingCount(pending)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _syncing ? null : _syncNow,
              icon: _syncing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(l10n.syncNow),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.syncAttentionTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (failed.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.syncAttentionEmpty),
            )
          else
            for (final change in failed)
              ListTile(
                leading: Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  [
                    _entityLabel(l10n, change.entity),
                    if (change.title.isNotEmpty) change.title,
                    if (change.amount != null) formatRupiah(change.amount!),
                    if (change.isDelete) l10n.syncDeleteSuffix,
                  ].join(' · '),
                ),
                subtitle: Text(_reason(l10n, change.error)),
                onTap: () => unawaited(_showActions(change)),
              ),
        ],
      ),
    );
  }
}
