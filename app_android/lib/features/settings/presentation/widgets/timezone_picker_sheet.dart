import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../l10n/generated/app_localizations.dart';

const List<String> _indonesia = [
  'Asia/Jakarta',
  'Asia/Pontianak',
  'Asia/Makassar',
  'Asia/Jayapura',
];

/// Shows the IANA timezone list with a search box and returns the chosen name;
/// the Indonesian zones come first.
Future<String?> showTimezonePicker(BuildContext context, String current) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TimezoneSheet(current: current),
    );

class _TimezoneSheet extends StatefulWidget {
  const _TimezoneSheet({required this.current});

  final String current;

  @override
  State<_TimezoneSheet> createState() => _TimezoneSheetState();
}

class _TimezoneSheetState extends State<_TimezoneSheet> {
  late final List<String> _all = [
    for (final name in tz.timeZoneDatabase.locations.keys)
      if (!_indonesia.contains(name)) name,
  ]..sort();
  String _query = '';

  bool _matches(String name) =>
      _query.isEmpty ||
      name.toLowerCase().replaceAll('_', ' ').contains(_query.toLowerCase());

  /// `+07:00` style offset of the zone right now.
  String _offset(String name) {
    final offset = tz.TZDateTime.now(tz.getLocation(name)).timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    final hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final mm = (minutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hh:$mm';
  }

  Widget _tile(String name) => ListTile(
    title: Text(name.replaceAll('_', ' ')),
    subtitle: Text(_offset(name)),
    trailing: name == widget.current ? const Icon(Icons.check) : null,
    onTap: () => Navigator.pop(context, name),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final indonesia = _indonesia.where(_matches).toList();
    final others = _all.where(_matches).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.prefsTimezoneSearch,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (indonesia.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          l10n.prefsTimezoneIndonesia,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      for (final name in indonesia) _tile(name),
                    ],
                    if (others.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          l10n.prefsTimezoneOthers,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      for (final name in others) _tile(name),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
