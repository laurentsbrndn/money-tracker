/// Where an export is.
enum ExportPhase {
  idle,
  working,

  /// The share sheet was opened.
  done,

  /// No posted transaction in the period: no file is made.
  empty,

  /// The server does not report premium (the screen also checks).
  notPremium,

  /// The app locked while exporting; nothing is written or shared.
  locked,

  /// Writing the file or opening the share sheet failed.
  error,
}

class ExportState {
  const ExportState({this.phase = ExportPhase.idle, this.progress});

  final ExportPhase phase;

  /// 0..1 while building a PDF; null when the length is unknown.
  final double? progress;

  bool get busy => phase == ExportPhase.working;
}
