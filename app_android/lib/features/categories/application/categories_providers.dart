import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/billing/entitlement_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/sync/sync_providers.dart';
import '../data/categories_repository.dart';

part 'categories_providers.g.dart';

@Riverpod(keepAlive: true)
CategoriesRepository categoriesRepository(Ref ref) => CategoriesRepository(
  db: ref.watch(appDatabaseProvider),
  writer: ref.watch(outboxWriterProvider),
  isPremium: () => ref.read(isPremiumProvider.future),
);

/// Live categories of both types, in list order. Declared by hand because it
/// returns a Drift row type (invisible to riverpod_generator).
final allCategoriesProvider = StreamProvider.autoDispose<List<CategoryRow>>(
  (ref) => ref.watch(categoriesRepositoryProvider).watchAll(),
);
