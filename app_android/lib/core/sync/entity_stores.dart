import '../database/app_database.dart';
import 'entity_codec.dart';
import 'entity_store.dart';
import 'sync_entities.dart';

/// The [EntityStore] of every synced entity, by wire name.
class EntityStores {
  EntityStores(AppDatabase db, [EntityCodec codec = const EntityCodec()])
    : _stores = {
        SyncEntities.userSettings: TableEntityStore(
          db: db,
          table: db.userSettings,
          toJson: codec.userSettingsToJson,
          fromJson: codec.userSettingsFromJson,
        ),
        SyncEntities.categories: TableEntityStore(
          db: db,
          table: db.categories,
          toJson: codec.categoryToJson,
          fromJson: codec.categoryFromJson,
        ),
        SyncEntities.accounts: TableEntityStore(
          db: db,
          table: db.accounts,
          toJson: codec.accountToJson,
          fromJson: codec.accountFromJson,
        ),
        SyncEntities.balanceSnapshots: TableEntityStore(
          db: db,
          table: db.balanceSnapshots,
          toJson: codec.balanceSnapshotToJson,
          fromJson: codec.balanceSnapshotFromJson,
        ),
        SyncEntities.transactions: TableEntityStore(
          db: db,
          table: db.transactions,
          toJson: codec.transactionToJson,
          fromJson: codec.transactionFromJson,
        ),
        SyncEntities.recurringRules: TableEntityStore(
          db: db,
          table: db.recurringRules,
          toJson: codec.recurringRuleToJson,
          fromJson: codec.recurringRuleFromJson,
        ),
        SyncEntities.budgetGoals: TableEntityStore(
          db: db,
          table: db.budgetGoals,
          toJson: codec.budgetGoalToJson,
          fromJson: codec.budgetGoalFromJson,
        ),
      };

  final Map<String, EntityStore> _stores;

  /// Null for an entity name this client does not know.
  EntityStore? maybeOf(String entity) => _stores[entity];

  EntityStore of(String entity) =>
      _stores[entity] ?? (throw ArgumentError('Unknown entity $entity'));
}
