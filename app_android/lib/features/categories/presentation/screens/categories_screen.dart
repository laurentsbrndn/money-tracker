import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/validation/validation_exception.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/categories_providers.dart';
import '../widgets/category_list_tile.dart';

/// Manage categories (APP_FLOWS Flow 7): expense and income tabs, drag to
/// reorder, hide/archive, delete when unused.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _type => _tabs.index == 0 ? 'expense' : 'income';

  Future<void> _guard(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on RecordInUseException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.categoryInUse)));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    }
  }

  Future<void> _delete(CategoryRow category) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.categoryDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _guard(
        () => ref.read(categoriesRepositoryProvider).delete(category.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(allCategoriesProvider).value ?? const [];
    final repository = ref.watch(categoriesRepositoryProvider);
    final items = [
      for (final category in all)
        if (category.type == _type) category,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categoriesTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.categoryTypeExpense),
            Tab(text: l10n.categoryTypeIncome),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.categoryNew,
        onPressed: () => context.push(
          Uri(
            path: RoutePaths.categoryNew,
            queryParameters: {'type': _type},
          ).toString(),
        ),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.category_outlined,
              title: l10n.categoriesEmpty,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    l10n.categoryReorderHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: items.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final reordered = [...items];
                      final moved = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, moved);
                      unawaited(_guard(() => repository.reorder(reordered)));
                    },
                    itemBuilder: (context, index) {
                      final category = items[index];
                      return CategoryListTile(
                        key: ValueKey(category.id),
                        category: category,
                        onTap: () =>
                            context.push(RoutePaths.categoryEdit(category.id)),
                        onToggleHidden: () => _guard(
                          () => repository.setHidden(
                            category,
                            hidden: !category.isHidden,
                          ),
                        ),
                        onToggleArchived: () => _guard(
                          () => repository.setArchived(
                            category,
                            archived: category.archivedAt == null,
                          ),
                        ),
                        onDelete: () => _delete(category),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
