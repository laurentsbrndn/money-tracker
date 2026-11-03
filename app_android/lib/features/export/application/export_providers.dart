import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/billing/entitlement_provider.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/civil_date_format.dart';
import '../data/export_file_service.dart';
import '../data/export_pdf_builder.dart';
import '../data/export_repository.dart';
import '../domain/csv_writer.dart';
import '../domain/export_delimiter.dart';
import '../domain/export_file_name.dart';
import '../domain/export_format.dart';
import '../domain/export_period.dart';
import '../domain/export_state.dart';
import '../domain/export_texts.dart';

part 'export_providers.g.dart';

@Riverpod(keepAlive: true)
ExportRepository exportRepository(Ref ref) =>
    ExportRepository(db: ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
ExportFileService exportFileService(Ref ref) => ExportFileService();

/// Runs one export at a time: premium check, read the local database, build
/// the file, share it. Real amounts are exported even when "Sembunyikan
/// nominal" is on (a deliberate act), but never while the app is locked.
@Riverpod(keepAlive: true)
class ExportController extends _$ExportController {
  @override
  ExportState build() => const ExportState();

  /// Back to idle, for a new visit to the screen. A running export keeps going.
  void reset() {
    if (!state.busy) {
      state = const ExportState();
    }
  }

  bool get _locked => ref.read(appLockControllerProvider).locked;

  Future<void> run({
    required ExportFormat format,
    required ExportPeriod period,
    required CsvDelimiterChoice delimiterChoice,
    required String deviceDecimalSeparator,
    required ExportTexts texts,
  }) async {
    if (state.busy) {
      return;
    }
    if (!(await ref.read(isPremiumProvider.future))) {
      state = const ExportState(phase: ExportPhase.notPremium);
      return;
    }
    if (_locked) {
      state = const ExportState(phase: ExportPhase.locked);
      return;
    }
    state = const ExportState(phase: ExportPhase.working);
    try {
      final rows = await ref.read(exportRepositoryProvider).loadRows(period);
      if (rows.isEmpty) {
        state = const ExportState(phase: ExportPhase.empty);
        return;
      }
      final from = period.from ?? rows.first.date;
      final to = period.to ?? rows.last.date;
      final files = ref.read(exportFileServiceProvider);
      final File file;
      final String mime;
      if (format == ExportFormat.csv) {
        final delimiter = resolveCsvDelimiter(
          delimiterChoice,
          deviceDecimalSeparator,
        );
        final csv = buildCsv(
          rows: rows,
          headers: texts.headers,
          typeLabel: texts.typeLabel,
          delimiter: delimiter,
        );
        file = await files.write(
          exportFileName(from, to, 'csv'),
          csvBytes(csv),
        );
        mime = 'text/csv';
      } else {
        final bytes = await buildExportPdf(
          rows: rows,
          periodText: period.isAll
              ? '${texts.pdfAllData} (${_range(texts, from, to)})'
              : _range(texts, from, to),
          texts: texts,
          onProgress: (value) =>
              state = ExportState(phase: ExportPhase.working, progress: value),
        );
        file = await files.write(exportFileName(from, to, 'pdf'), bytes);
        mime = 'application/pdf';
      }
      if (_locked) {
        await files.cleanUp();
        state = const ExportState(phase: ExportPhase.locked);
        return;
      }
      await files.share(file, mime, texts.pdfTitle);
      state = const ExportState(phase: ExportPhase.done);
    } on Exception {
      state = const ExportState(phase: ExportPhase.error);
    }
  }

  String _range(ExportTexts texts, CivilDate from, CivilDate to) =>
      texts.pdfRange(formatCivilDateShort(from), formatCivilDateShort(to));
}
