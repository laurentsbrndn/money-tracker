import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../categories/application/categories_providers.dart';

/// Categories by id, for labelling transactions.
final categoriesByIdProvider = Provider.autoDispose<Map<String, CategoryRow>>((
  ref,
) {
  final list = ref.watch(allCategoriesProvider).value ?? const [];
  return {for (final category in list) category.id: category};
});

/// Accounts by id, for labelling transactions.
final accountsByIdProvider = Provider.autoDispose<Map<String, AccountRow>>((
  ref,
) {
  final list = ref.watch(allAccountsProvider).value ?? const [];
  return {for (final account in list) account.id: account};
});
