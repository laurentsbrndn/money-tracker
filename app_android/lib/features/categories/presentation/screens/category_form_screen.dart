import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/billing/plan_limits.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/validation/validation_exception.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/categories_providers.dart';

/// Create (`categoryId` null, with [type]) or edit a category.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({this.categoryId, this.type, super.key});

  final String? categoryId;

  /// `expense` or `income`, for a new category.
  final String? type;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _name = TextEditingController();
  String _type = 'expense';
  String _icon = 'other';
  String _color = CategoryIcons.palette.first;
  String _allocation = 'wants';
  CategoryRow? _existing;
  bool _loaded = false;
  bool _busy = false;

  bool get _isEdit => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    _type = widget.type == 'income' ? 'income' : 'expense';
    if (_isEdit) {
      _load();
    } else {
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final category = await ref
        .read(categoriesRepositoryProvider)
        .find(widget.categoryId!);
    if (!mounted) {
      return;
    }
    if (category == null) {
      context.pop();
      return;
    }
    setState(() {
      _existing = category;
      _type = category.type;
      _name.text = category.name;
      _icon = category.icon;
      _color = category.color;
      _allocation = category.defaultAllocation ?? 'wants';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    final repository = ref.read(categoriesRepositoryProvider);
    try {
      if (_existing != null) {
        await repository.update(
          _existing!,
          name: _name.text,
          icon: _icon,
          color: _color,
          defaultAllocation: _type == 'expense' ? _allocation : null,
        );
      } else {
        await repository.create(
          name: _name.text,
          type: _type,
          icon: _icon,
          color: _color,
          defaultAllocation: _type == 'expense' ? _allocation : null,
        );
      }
      router.pop();
    } on ValidationException catch (error) {
      _fail(messenger, error.message(l10n));
    } on PlanLimitException {
      _fail(messenger, l10n.planLimitCategories);
    } on Object catch (error) {
      _fail(messenger, describeError(error, l10n));
    }
  }

  void _fail(ScaffoldMessengerState messenger, String message) {
    if (mounted) {
      setState(() => _busy = false);
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final iconLocked = _existing?.isDefault ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.categoryEdit : l10n.categoryNew),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _name,
                  maxLength: 50,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.categoryFieldName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.categoryFieldIcon, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in CategoryIcons.pickable)
                      InkResponse(
                        onTap: iconLocked
                            ? null
                            : () => setState(() => _icon = key),
                        child: CircleAvatar(
                          backgroundColor: key == _icon
                              ? CategoryIcons.colorOf(_color)
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            CategoryIcons.of(key),
                            color: key == _icon
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.categoryFieldColor,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final hex in CategoryIcons.palette)
                      InkResponse(
                        onTap: () => setState(() => _color = hex),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: CategoryIcons.colorOf(hex),
                          child: hex == _color
                              ? const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                if (_type == 'expense') ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.categoryFieldAllocation,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in {
                        'needs': l10n.allocationNeeds,
                        'wants': l10n.allocationWants,
                        'savings': l10n.allocationSavings,
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _allocation == entry.key,
                          onSelected: (_) =>
                              setState(() => _allocation = entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.categoryAllocationHint,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.actionSave),
                ),
              ],
            ),
    );
  }
}
