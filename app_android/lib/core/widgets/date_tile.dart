import 'package:flutter/material.dart';

import '../time/civil_date.dart';
import '../time/civil_date_format.dart';

/// A list tile showing a calendar date; tapping opens the date picker.
class DateTile extends StatelessWidget {
  const DateTile({
    required this.label,
    required this.date,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    super.key,
  });

  final String label;
  final CivilDate date;
  final ValueChanged<CivilDate> onChanged;
  final CivilDate? firstDate;
  final CivilDate? lastDate;

  static DateTime _toDateTime(CivilDate value) =>
      DateTime(value.year, value.month, value.day);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(label),
      subtitle: Text(formatCivilDateLong(date)),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _toDateTime(date),
          firstDate: firstDate == null
              ? DateTime(2000)
              : _toDateTime(firstDate!),
          lastDate: lastDate == null
              ? DateTime.now().add(const Duration(days: 366))
              : _toDateTime(lastDate!),
        );
        if (picked != null) {
          onChanged(CivilDate.fromDateTime(picked));
        }
      },
    );
  }
}
