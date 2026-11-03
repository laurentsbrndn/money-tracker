import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database_provider.dart';
import '../../accounts/application/accounts_providers.dart';
import '../data/setup_repository.dart';

part 'setup_actions.g.dart';

@Riverpod(keepAlive: true)
SetupRepository setupRepository(Ref ref) =>
    SetupRepository(ref.watch(appDatabaseProvider));

@riverpod
SetupActions setupActions(Ref ref) => SetupActions(ref);

/// What the wizard does on top of the shared repositories.
class SetupActions {
  SetupActions(this._ref);

  final Ref _ref;

  /// Step 1: sets the Cash account's balance (its opening balance and first
  /// snapshot). Does nothing when the Cash account is missing or unchanged.
  Future<void> saveCashBalance(int balance) async {
    final cash = await _ref.read(setupRepositoryProvider).findCash();
    if (cash == null || cash.openingBalance == balance) {
      return;
    }
    await _ref
        .read(accountsRepositoryProvider)
        .update(
          cash,
          name: cash.name,
          type: cash.type,
          providerKey: cash.providerKey,
          openingBalance: balance,
          openingDate: cash.openingDate,
          includeInTotal: cash.includeInTotal,
        );
  }

  Future<void> finish() => _ref.read(setupRepositoryProvider).markDone();
}
