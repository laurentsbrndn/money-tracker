import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../../transactions/application/transaction_lookups.dart';
import '../../../transactions/application/transactions_providers.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../../application/recurring_providers.dart';

/// "Menunggu konfirmasi" (APP_FLOWS Flow 4 step 4): the transactions of
/// `confirm` rules. "Catat" records one as it is (tapping it first lets the
/// amount and date change); "Lewati" deletes it.
class PendingConfirmationSection extends ConsumerWidget {
  const PendingConfirmationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingTransactionsProvider).value ?? const [];
    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesByIdProvider);
    final accounts = ref.watch(accountsByIdProvider);
    final hide = ref.watch(hideAmountsProvider);
    final repository = ref.read(transactionsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              '${l10n.pendingTitle} (${pending.length})',
              style: theme.textTheme.titleMedium,
            ),
          ),
          for (final transaction in pending) ...[
            TransactionTile(
              transaction: transaction,
              categories: categories,
              accounts: accounts,
              hideAmounts: hide,
              onTap: () => context.push(RoutePaths.transaction(transaction.id)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      await repository.delete(transaction.id);
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.pendingSkipped)),
                      );
                    },
                    child: Text(l10n.pendingSkip),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await repository.confirm(transaction.id);
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.pendingRecorded)),
                      );
                    },
                    child: Text(l10n.pendingRecord),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
