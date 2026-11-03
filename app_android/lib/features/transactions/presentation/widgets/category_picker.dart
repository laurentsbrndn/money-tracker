import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/category_icons.dart';

/// Wrap of category chips; selecting one reports it to the form.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<CategoryRow> categories;
  final String? selectedId;
  final ValueChanged<CategoryRow> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final category in categories)
          ChoiceChip(
            avatar: Icon(
              CategoryIcons.of(category.icon),
              size: 18,
              color: CategoryIcons.colorOf(category.color),
            ),
            label: Text(category.name),
            selected: category.id == selectedId,
            onSelected: (_) => onSelected(category),
          ),
      ],
    );
  }
}
