import 'package:drift/drift.dart';

import '../converters/civil_date_converter.dart';
import 'sync_columns.dart';

@DataClassName('TransactionRow')
@TableIndex(name: 'transactions_date', columns: {#transactionDate})
@TableIndex(
  name: 'transactions_account_date',
  columns: {#accountId, #transactionDate},
)
@TableIndex(name: 'transactions_to_account', columns: {#toAccountId})
@TableIndex(name: 'transactions_recurring_rule', columns: {#recurringRuleId})
class Transactions extends Table with SyncColumns {
  /// `income`, `expense`, `transfer`, or `adjustment`.
  TextColumn get type => text()();

  /// `posted` or `pending_confirmation`.
  TextColumn get status => text().withDefault(const Constant('posted'))();

  TextColumn get transactionDate => text().map(const CivilDateConverter())();

  /// Positive, except for `adjustment` which is signed and non-zero.
  Int64Column get amount => int64()();

  TextColumn get currency => text().withDefault(const Constant('IDR'))();

  TextColumn get accountId => text()();

  TextColumn get toAccountId => text().nullable()();

  TextColumn get categoryId => text().nullable()();

  /// `needs`, `wants`, or `savings`; only for expense.
  TextColumn get allocation => text().nullable()();

  TextColumn get source => text().nullable()();

  TextColumn get note => text().nullable()();

  TextColumn get linkedTransactionId => text().nullable()();

  TextColumn get recurringRuleId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
