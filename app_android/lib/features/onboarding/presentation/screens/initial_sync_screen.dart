import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/sync/sync_run_state.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// "Menyiapkan data…" until the first pull has finished (SYNC_PROTOCOL §12).
/// The cursor is saved per page, so an interrupted pull resumes where it
/// stopped. When it completes the app gate moves on by itself.
class InitialSyncScreen extends ConsumerStatefulWidget {
  const InitialSyncScreen({super.key});

  @override
  ConsumerState<InitialSyncScreen> createState() => _InitialSyncScreenState();
}

class _InitialSyncScreenState extends ConsumerState<InitialSyncScreen> {
  SyncOutcome? _failure;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _failure = null;
    });
    final outcome = await ref
        .read(syncEngineProvider.notifier)
        .runInitialSync();
    if (mounted) {
      setState(() {
        _running = false;
        _failure = outcome == SyncOutcome.synced ? null : outcome;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = ref.watch(syncEngineProvider).pulledRows;
    final failure = _failure;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_running || failure == null) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(l10n.initialSyncTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(l10n.initialSyncProgress(rows)),
              ] else ...[
                Icon(
                  failure == SyncOutcome.offline
                      ? Icons.cloud_off_outlined
                      : Icons.error_outline,
                  size: 56,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(switch (failure) {
                  SyncOutcome.offline => l10n.initialSyncOffline,
                  SyncOutcome.needsLogin => l10n.initialSyncNeedsLogin,
                  _ => l10n.initialSyncFailed,
                }, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (failure == SyncOutcome.needsLogin)
                  FilledButton(
                    onPressed: () => context.push(RoutePaths.login),
                    child: Text(l10n.initialSyncLogin),
                  )
                else
                  FilledButton(onPressed: _run, child: Text(l10n.actionRetry)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
