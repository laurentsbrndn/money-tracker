import 'package:drift/drift.dart' show Value;

import '../../../core/billing/plan_limits.dart';
import '../../../core/database/app_database.dart';
import '../../../core/ids/id_generator.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/sync_entities.dart';
import '../../../core/validation/validation_exception.dart';

/// Categories (BUSINESS_RULES §2.1 seed + custom ones). Writes go through the
/// [OutboxWriter].
class CategoriesRepository {
  CategoriesRepository({
    required this._db,
    required this._writer,
    required this._isPremium,
  });

  final AppDatabase _db;
  final OutboxWriter _writer;
  final Future<bool> Function() _isPremium;

  static const IdGenerator _ids = IdGenerator();

  Stream<List<CategoryRow>> watchAll() => _db.categoriesDao.watchActive();

  Future<CategoryRow?> find(String id) => _db.categoriesDao.findById(id);

  Future<CategoryRow?> findFeeCategory() => _db.categoriesDao.findFeeCategory();

  Future<void> _validateName(
    String name,
    String type, {
    String? exceptId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException(ValidationError.nameRequired);
    }
    if (trimmed.length > 50) {
      throw const ValidationException(ValidationError.nameTooLong);
    }
    final lowered = trimmed.toLowerCase();
    for (final other in await _db.categoriesDao.allActive()) {
      if (other.id != exceptId &&
          other.type == type &&
          other.name.trim().toLowerCase() == lowered) {
        throw const ValidationException(ValidationError.nameTaken);
      }
    }
  }

  /// Creates a custom category (free plan: at most 5, archived ones count).
  Future<String> create({
    required String name,
    required String type,
    required String icon,
    required String color,
    String? defaultAllocation,
  }) async {
    await _validateName(name, type);
    if (type == 'expense' && defaultAllocation == null) {
      throw const ValidationException(ValidationError.allocationRequired);
    }
    if (!await _isPremium() &&
        await _db.categoriesDao.countCustom() >=
            PlanLimits.maxFreeCustomCategories) {
      throw const PlanLimitException(PlanLimitKind.categories);
    }
    final id = _ids.newId();
    final sortOrder = await _db.categoriesDao.maxSortOrder(type) + 1;
    await _writer.write(
      (tx) => tx.upsert(
        SyncEntities.categories,
        id,
        CategoryRow(
          id: id,
          createdAt: tx.now,
          updatedAt: tx.now,
          syncStatus: 'pending',
          type: type,
          name: name.trim(),
          icon: icon,
          color: color,
          defaultAllocation: type == 'expense' ? defaultAllocation : null,
          sortOrder: sortOrder,
          isDefault: false,
          isHidden: false,
        ),
      ),
    );
    return id;
  }

  /// Edits a category. The default allocation only affects new transactions;
  /// the icon of a seeded category stays (the fee category is found by it).
  Future<void> update(
    CategoryRow existing, {
    required String name,
    required String icon,
    required String color,
    String? defaultAllocation,
  }) async {
    await _validateName(name, existing.type, exceptId: existing.id);
    await _writer.write(
      (tx) => tx.upsert(
        SyncEntities.categories,
        existing.id,
        existing.copyWith(
          name: name.trim(),
          icon: existing.isDefault ? existing.icon : icon,
          color: color,
          defaultAllocation: Value(
            existing.type == 'expense' ? defaultAllocation : null,
          ),
        ),
      ),
    );
  }

  Future<void> setHidden(CategoryRow category, {required bool hidden}) =>
      _writer.write(
        (tx) => tx.upsert(
          SyncEntities.categories,
          category.id,
          category.copyWith(isHidden: hidden),
        ),
      );

  Future<void> setArchived(CategoryRow category, {required bool archived}) =>
      _writer.write(
        (tx) => tx.upsert(
          SyncEntities.categories,
          category.id,
          category.copyWith(archivedAt: Value(archived ? tx.now : null)),
        ),
      );

  /// Stores the new order of one type's categories (drag to reorder).
  Future<void> reorder(List<CategoryRow> ordered) => _writer.write((tx) async {
    for (var index = 0; index < ordered.length; index++) {
      final category = ordered[index];
      if (category.sortOrder != index + 1) {
        await tx.upsert(
          SyncEntities.categories,
          category.id,
          category.copyWith(sortOrder: index + 1),
        );
      }
    }
  });

  Future<bool> isUsed(String id) async =>
      await _db.transactionsDao.countForCategory(id) > 0;

  /// Permanently deletes a category that no live transaction uses.
  Future<void> delete(String id) async {
    if (await isUsed(id)) {
      throw const RecordInUseException(isAccount: false);
    }
    await _writer.write((tx) => tx.delete(SyncEntities.categories, id));
  }
}
