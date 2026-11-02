import 'package:drift/drift.dart';

import '../../time/civil_date.dart';

/// Stores a [CivilDate] as `YYYY-MM-DD` text.
class CivilDateConverter extends TypeConverter<CivilDate, String> {
  const CivilDateConverter();

  @override
  CivilDate fromSql(String fromDb) => CivilDate.parse(fromDb);

  @override
  String toSql(CivilDate value) => value.toString();
}
