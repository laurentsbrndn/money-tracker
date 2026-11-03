import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../l10n/generated/app_localizations.dart';

class CategoryListTile extends StatelessWidget {
  const CategoryListTile({
    required this.category,
    required this.onTap,
    required this.onToggleHidden,
    required this.onToggleArchived,
    required this.onDelete,
    super.key,
  });

  final CategoryRow category;
  final VoidCallback onTap;
  final VoidCallback onToggleHidden;
  final VoidCallback onToggleArchived;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final badges = [
      if (category.isDefault) l10n.categoryDefaultBadge,
      if (category.isHidden) l10n.categoryHiddenBadge,
      if (category.archivedAt != null) l10n.categoryArchivedBadge,
      if (category.defaultAllocation != null)
        switch (category.defaultAllocation) {
          'needs' => l10n.allocationNeeds,
          'wants' => l10n.allocationWants,
          _ => l10n.allocationSavings,
        },
    ];
    final dimmed = category.isHidden || category.archivedAt != null;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: CategoryIcons.colorOf(category.color)
            .withValues(alpha: dimmed ? 0.08 : 0.18),
        child: Icon(
          CategoryIcons.of(category.icon),
          color: CategoryIcons.colorOf(category.color),
        ),
      ),
      title: Text(
        category.name,
        style: dimmed
            ? TextStyle(color: Theme.of(context).colorScheme.outline)
            : null,
      ),
      subtitle: badges.isEmpty ? null : Text(badges.join(' · ')),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'hide':
              onToggleHidden();
            case 'archive':
              onToggleArchived();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'hide',
            child: Text(
              category.isHidden ? l10n.categoryShow : l10n.categoryHide,
            ),
          ),
          PopupMenuItem(
            value: 'archive',
            child: Text(
              category.archivedAt == null
                  ? l10n.categoryArchive
                  : l10n.categoryUnarchive,
            ),
          ),
          if (!category.isDefault)
            PopupMenuItem(value: 'delete', child: Text(l10n.categoryDelete)),
        ],
      ),
    );
  }
}
