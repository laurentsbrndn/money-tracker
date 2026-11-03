import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/billing/entitlement_provider.dart';
import '../../../../core/domain_rules/types.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/time/civil_date.dart';
import '../../../../core/time/user_clock.dart';
import '../../../../core/widgets/date_tile.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/export_providers.dart';
import '../../domain/export_delimiter.dart';
import '../../domain/export_format.dart';
import '../../domain/export_period.dart';
import '../../domain/export_state.dart';
import '../../domain/export_texts.dart';

/// Lainnya → Data → Export (APP_FLOWS Flow 12): CSV or PDF of the posted
/// transactions in a period, read from the local database. Premium only
/// (BUSINESS_RULES §7).
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportFormat _format = ExportFormat.csv;
  CsvDelimiterChoice _delimiter = CsvDelimiterChoice.auto;
  ExportPreset? _preset = ExportPreset.thisMonth;
  CivilDate? _from;
  CivilDate? _to;

  @override
  void initState() {
    super.initState();
    Future(() => ref.read(exportControllerProvider.notifier).reset());
  }

  CivilDate get _today => ref.read(userClockProvider).today();

  ExportPeriod get _period => _preset != null
      ? periodForPreset(_preset!, _today)
      : ExportPeriod(from: _from, to: _to);

  void _pick(ExportPreset preset) => setState(() {
    _preset = preset;
    final period = periodForPreset(preset, _today);
    _from = period.from ?? _today;
    _to = period.to ?? _today;
  });

  ExportTexts _texts(AppLocalizations l10n) => ExportTexts(
    headers: [
      l10n.exportCsvHeaderDate,
      l10n.exportCsvHeaderType,
      l10n.exportCsvHeaderAmount,
      l10n.exportCsvHeaderAccount,
      l10n.exportCsvHeaderToAccount,
      l10n.exportCsvHeaderCategory,
      l10n.exportCsvHeaderNote,
    ],
    typeLabel: (type) => switch (type) {
      TransactionType.income => l10n.exportTypeIncome,
      TransactionType.expense => l10n.exportTypeExpense,
      TransactionType.transfer => l10n.exportTypeTransfer,
      TransactionType.adjustment => l10n.exportTypeAdjustment,
    },
    pdfTitle: l10n.exportPdfTitle,
    pdfPeriod: l10n.exportPdfPeriod,
    pdfIncome: l10n.exportPdfIncome,
    pdfExpense: l10n.exportPdfExpense,
    pdfDifference: l10n.exportPdfDifference,
    pdfCount: l10n.exportPdfCount,
    pdfPage: l10n.exportPdfPage,
    pdfAllData: l10n.exportPdfAllData,
    pdfRange: l10n.exportPdfRange,
  );

  /// The decimal separator of the device language, which decides the CSV
  /// separator in automatic mode.
  String get _deviceDecimalSeparator => NumberFormat.decimalPattern(
    PlatformDispatcher.instance.locale.toLanguageTag(),
  ).symbols.DECIMAL_SEP;

  void _export(AppLocalizations l10n) => ref
      .read(exportControllerProvider.notifier)
      .run(
        format: _format,
        period: _period,
        delimiterChoice: _delimiter,
        deviceDecimalSeparator: _deviceDecimalSeparator,
        texts: _texts(l10n),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final premium = ref.watch(isPremiumProvider).value ?? false;
    final state = ref.watch(exportControllerProvider);
    if (!premium) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.exportTitle)),
        body: EmptyState(
          icon: Icons.lock_outline,
          title: l10n.exportLockedTitle,
          message: l10n.exportLockedBody,
          action: FilledButton(
            onPressed: () => context.push(RoutePaths.paywall),
            child: Text(l10n.planLimitSeePremium),
          ),
        ),
      );
    }
    final period = _period;
    final custom = _preset == null;
    final from = _from ?? _today;
    final to = _to ?? _today;
    final rangeOk = custom ? !from.isAfter(to) : period.isValid;
    final message = switch (state.phase) {
      ExportPhase.empty => l10n.exportEmpty,
      ExportPhase.error => l10n.exportError,
      ExportPhase.locked => l10n.exportLocked,
      ExportPhase.done => l10n.exportDone,
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.exportFormat,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<ExportFormat>(
            segments: const [
              ButtonSegment(value: ExportFormat.csv, label: Text('CSV')),
              ButtonSegment(value: ExportFormat.pdf, label: Text('PDF')),
            ],
            selected: {_format},
            onSelectionChanged: state.busy
                ? null
                : (value) => setState(() => _format = value.first),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.exportPeriod,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final (preset, label) in [
                (ExportPreset.thisMonth, l10n.exportPresetThisMonth),
                (ExportPreset.lastMonth, l10n.exportPresetLastMonth),
                (ExportPreset.last3Months, l10n.exportPresetLast3Months),
                (ExportPreset.thisYear, l10n.exportPresetThisYear),
                (ExportPreset.allData, l10n.exportPresetAll),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _preset == preset,
                  onSelected: state.busy ? null : (_) => _pick(preset),
                ),
            ],
          ),
          if (_preset != ExportPreset.allData) ...[
            const SizedBox(height: 8),
            DateTile(
              label: l10n.exportFrom,
              date: from,
              onChanged: (value) => setState(() {
                _from = value;
                _to = to;
                _preset = null;
              }),
            ),
            DateTile(
              label: l10n.exportTo,
              date: to,
              onChanged: (value) => setState(() {
                _from = from;
                _to = value;
                _preset = null;
              }),
            ),
          ],
          if (!rangeOk)
            Text(
              l10n.exportInvalidRange,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_format == ExportFormat.csv) ...[
            const SizedBox(height: 20),
            Text(
              l10n.exportDelimiter,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<CsvDelimiterChoice>(
              segments: [
                ButtonSegment(
                  value: CsvDelimiterChoice.auto,
                  label: Text(l10n.exportDelimiterAuto),
                ),
                ButtonSegment(
                  value: CsvDelimiterChoice.comma,
                  label: Text(l10n.exportDelimiterComma),
                ),
                ButtonSegment(
                  value: CsvDelimiterChoice.semicolon,
                  label: Text(l10n.exportDelimiterSemicolon),
                ),
              ],
              selected: {_delimiter},
              onSelectionChanged: state.busy
                  ? null
                  : (value) => setState(() => _delimiter = value.first),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.exportDelimiterHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          Text(
            l10n.exportPrivacyNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (state.busy) ...[
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 8),
            Text(l10n.exportWorking),
          ] else
            FilledButton.icon(
              onPressed: rangeOk ? () => _export(l10n) : null,
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.exportAction),
            ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message, key: const Key('export_message')),
          ],
        ],
      ),
    );
  }
}
